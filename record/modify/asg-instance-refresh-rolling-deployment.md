# ASG Instance Refresh를 이용한 무중단 롤링 배포

## 1. 원인

기존에는 Terraform으로 새 AMI를 반영하면 기존 API EC2 인스턴스 2대가 먼저 종료됐습니다. 새 AMI로 생성한 EC2 인스턴스가 요청을 받기 전까지 API 요청을 처리할 EC2 인스턴스가 없어 서비스가 중단됐습니다.

원인은 [ASG의 Instance Refresh 설정](../../modules/compute/main.tf)이었습니다. 최소 정상 비율은 0%, 최대 용량 비율은 100%로 설정돼 있었습니다.

최소 정상 비율이 0%이므로 기존 EC2 인스턴스를 모두 종료한 뒤에도 Instance Refresh를 계속 진행할 수 있었습니다. 최대 용량 비율이 100%이므로 기존 EC2 인스턴스가 실행 중인 동안에는 새 EC2 인스턴스를 추가로 생성할 수 없었습니다.

## 2. 변경 계획

ASG(Auto Scaling Group)는 여러 EC2 인스턴스를 하나의 그룹으로 관리합니다. 부하가 높아지면 EC2 인스턴스를 추가하고, 부하가 낮아지면 EC2 인스턴스를 줄입니다.

목표 용량(`desired capacity`)은 ASG에서 실행할 EC2 인스턴스 수를 지정하는 값입니다. 기존 구성에서는 최소 용량이 2대, 최대 용량이 4대로 설정돼 있으며, 부하에 따라 EC2 인스턴스 수가 2대에서 4대 사이에서 조정됩니다. ([참고](https://docs.aws.amazon.com/autoscaling/ec2/userguide/auto-scaling-groups.html))

Instance Refresh는 ASG에서 실행 중인 EC2 인스턴스를 새 Launch Template 설정이 적용된 EC2 인스턴스로 교체하는 기능입니다. Launch Template에 새 AMI를 반영한 뒤 Instance Refresh를 실행하면 기존 AMI를 사용하는 EC2 인스턴스가 새 AMI를 사용하는 EC2 인스턴스로 순차적으로 교체됩니다. ([참고](https://docs.aws.amazon.com/autoscaling/ec2/userguide/instance-refresh-overview.html))

> ReplaceRootVolume은 AWS에서는 지원하지만, Terraform AWS Provider(6.66.0)에서는 직접 설정할 수 없습니다.

이번 변경에서는 기존 EC2 인스턴스를 먼저 종료하지 않습니다. 기존 EC2 인스턴스가 API 요청을 처리하는 동안 새 AMI를 적용한 EC2 인스턴스를 생성하고, 새 EC2 인스턴스가 ALB 상태 검사와 워밍업을 마친 뒤 기존 EC2 인스턴스를 종료합니다.

이를 위해 Instance Refresh의 최소 정상 비율을 100%, 최대 용량 비율을 200%로 변경합니다. ([참고](https://docs.aws.amazon.com/autoscaling/ec2/userguide/instance-refresh-overview.html))

최소 정상 비율과 최대 용량 비율은 ASG의 목표 용량(`desired capacity`)을 기준으로 계산됩니다.

예를 들어 목표 용량이 2대일 때 최소 정상 비율을 100%로 설정하면 정상 상태의 EC2 인스턴스를 최소 2대 유지해야 합니다. 최대 용량 비율을 200%로 설정하면 Instance Refresh 중 EC2 인스턴스를 최대 4대까지 실행할 수 있습니다.

따라서 목표 용량이 2대라면 기존 EC2 인스턴스 2대가 API 요청을 처리하는 동안 새 AMI를 적용한 EC2 인스턴스 2대를 추가로 생성할 수 있습니다. ([참고](https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/AutoScaling/Types/RefreshPreferences.html))

## 3. 변경 후

[ASG 리소스](../../modules/compute/main.tf)의 Instance Refresh 설정을 다음과 같이 수정했습니다.

| 설정 | 변경 전 | 변경 후 |
|---|---|---|
| 최소 정상 비율 (`min_healthy_percentage`) | 0%: 기존 EC2 인스턴스를 모두 종료해도 Instance Refresh를 계속 진행할 수 있음 | 100%: 목표 용량만큼 정상 상태의 EC2 인스턴스를 유지 |
| 최대 용량 비율 (`max_healthy_percentage`) | 100%: 기존 EC2 인스턴스가 실행 중인 동안 새 EC2 인스턴스를 추가로 생성할 수 없음 | 200%: 목표 용량이 2대일 때 EC2 인스턴스를 최대 4대까지 실행할 수 있음 |

목표 용량이 2대인 경우 Instance Refresh는 다음과 같이 진행됩니다.

1. 기존 AMI를 사용하는 EC2 인스턴스 2대가 API 요청을 계속 처리합니다.
2. 새 AMI를 적용한 EC2 인스턴스를 최대 2대 추가로 생성합니다.
3. 새 EC2 인스턴스가 ALB 상태 검사(`/health`, HTTP 200)를 통과하고 워밍업 300초를 마칠 때까지 기존 EC2 인스턴스 2대를 그대로 실행합니다.
4. 새 EC2 인스턴스가 상태 검사와 워밍업을 마치면 기존 EC2 인스턴스를 종료합니다.
5. 교체가 끝나면 새 AMI를 적용한 EC2 인스턴스 2대만 실행됩니다.

## 4. 메모리 기반 목표 추적 정책 추가

CPU 부하만으로는 메모리 부족을 판단할 수 없으므로, 기존 CPU 정책과 함께 메모리 목표 추적 정책을 사용합니다. 메모리 수집·운영 경보는 [CloudWatch 구성 기록](cloudwatch-monitoring.md)에 구분해 기록합니다.

| 항목 | CPU 정책 | 메모리 정책 |
|---|---|---|
| 정책 이름 | `arcamap-api-cpu` | `arcamap-api-memory` |
| 종류 | `TargetTrackingScaling` | `TargetTrackingScaling` |
| 지표 | `ASGAverageCPUUtilization` | `CWAgent / mem_used_percent` |
| 통계·차원 | ASG 평균 CPU 사용률 | `Average`·`AutoScalingGroupName=arcamap-api` |
| 목표값 | 50% | 50% |
| 축소 허용 | `disable_scale_in=false` | `disable_scale_in=false` |

한 정책이라도 확장을 요구하면 증설하고, 축소를 허용한 두 정책이 모두 축소에 동의할 때 감축합니다. 운영 최소 2대·최대 4대는 유지합니다. 50%를 넘었다고 항상 4대로 늘어나는 것은 아니며, ASG가 목표 사용률에 필요한 용량을 계산합니다. Instance Refresh의 최대 정상 비율 200%에 따른 교체 중 임시 용량은 운영 최대 대수와 구분합니다.

메모리 목표 추적은 인스턴스가 늘면 평균 메모리 사용률이 낮아지는 부하에 적합합니다. 고정 메모리 점유나 메모리 누수는 증설만으로 해결되지 않으므로 배포 후 부하 시험에서 지표 변화를 확인해야 합니다. [AWS 메모리 기반 정책](https://aws.amazon.com/blogs/mt/create-amazon-ec2-auto-scaling-policy-memory-utilization-metric-linux/), [여러 목표 추적 정책의 동작](https://docs.aws.amazon.com/autoscaling/ec2/userguide/as-scaling-target-tracking.html)

## 5. Instance Refresh 자동 롤백 추가

[compute 모듈](../../modules/compute/main.tf)의 `instance_refresh.preferences.auto_rollback`을 `true`로 설정하고 기존 CloudWatch 경보 3개를 연결했습니다.

| 경보 이름 | 지표와 의미 | 경보 조건 |
|---|---|---|
| `arcamap-alb-healthy-hosts` | `HealthyHostCount` — ALB 대상 그룹의 정상 대상 수 | 1분 최솟값이 2대 미만인 구간이 최근 3개 중 2개 |
| `arcamap-alb-5xx` | `HTTPCode_ELB_5XX_Count` — ALB 자체에서 발생한 HTTP 5xx 응답 수 | 5분 합계 5건 이상, 1회 |
| `arcamap-api-5xx` | `HTTPCode_Target_5XX_Count` — API 대상에서 발생한 HTTP 5xx 응답 수 | 5분 합계 5건 이상, 1회 |

ASG 이름은 WAS의 `local.api_asg_name`을 ASG와 경보가 함께 사용합니다. 경보 모듈이 생성한 이름을 `instance_refresh_alarm_names`로 전달하므로, 경보 생성 후 ASG에서 참조하면서도 경보가 ASG 리소스를 역으로 참조하는 순환 관계를 피합니다. 경보의 알림 동작은 기존처럼 비활성 상태이며, Instance Refresh가 경보 상태를 확인합니다.

Instance Refresh 중 연결한 경보 하나라도 `ALARM`이 되거나 교체 작업 자체가 실패하면 이전 Launch Template 설정으로 롤백합니다. 이미 교체된 인스턴스는 이전 AMI 설정으로 다시 교체되고, 아직 교체하지 않은 기존 정상 인스턴스는 유지할 수 있습니다. API 코드나 ALB 리소스 자체를 되돌리는 동작은 아닙니다.

다음 조건과 한계가 있습니다.

- 숫자 Launch Template 버전(`latest_version`의 실제 숫자)을 사용합니다. `$Latest`·`$Default` 문자열은 사용하지 않습니다.
- 새 AMI로 인스턴스를 생성하는 데 실패하는 경우 등에는 최대 약 1시간 동안 교체를 재시도한 뒤 실패·롤백할 수 있습니다. 첫 생성 실패와 즉시 롤백은 같은 의미가 아닙니다.
- 경보는 Refresh 시작 시 `OK`여야 합니다. `ALARM` 또는 `INSUFFICIENT_DATA` 상태이면 시작이 거부될 수 있습니다. 최초 배포에는 되돌릴 이전 정상 배포가 없습니다.
- `Successful`로 끝난 뒤 발생한 장애는 이 자동 롤백의 대상이 아닙니다.
- Terraform의 적용 완료는 Instance Refresh 완료를 뜻하지 않습니다. 별도로 Refresh 결과를 확인해야 합니다.
- 롤백은 Terraform 코드나 Image Builder 산출물을 되돌리지 않습니다. 실패 AMI를 원인 수정 없이 다시 적용하지 않도록 실제 ASG 버전과 코드의 차이를 확인해야 합니다.

[AWS 자동 롤백 조건](https://docs.aws.amazon.com/autoscaling/ec2/userguide/instance-refresh-rollback.html), [Terraform AWS 6.63.0 ASG](https://registry.terraform.io/providers/hashicorp/aws/6.63.0/docs/resources/autoscaling_group)

## 6. 검증 범위

현재 계정에는 배포된 리소스가 없으며 이번 변경은 배포 전 코드 구성입니다. 로컬 검증과 모의 Provider 검사는 실제 롤백·스케일링 성공 증거와 구분합니다.

실제 배포 후에는 정상 AMI 교체의 `Successful`, 경보 발생 시 `RollbackSuccessful`, 롤백 후 Launch Template 버전·AMI와 ALB 정상 대상 수를 확인합니다. 이전 정상 인스턴스가 남아 있으면 새 인스턴스 생성 실패만으로 `HealthyHostCount`가 2대 미만이 되지 않을 수 있으므로, 교체 자체의 실패와 경보에 의한 실패를 각각 확인합니다.

로컬 검증에서는 WAS의 `terraform validate`와 모의 Provider의 `memory_scaling_and_rollback` plan 검사가 통과했습니다. 관련 명령과 전체 결과는 [CloudWatch 검증 기록](cloudwatch-monitoring.md#로컬-검사-결과)에 기록합니다. 아직 실제 AMI 교체나 롤백 시험은 실행하지 않았습니다.
