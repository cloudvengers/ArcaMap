# EC2·Auto Scaling

## 주요 개념

| 용어 | 개념 | 적용 |
|---|---|---|
| 시작 템플릿 | EC2 생성에 사용할 이미지·디스크·권한 설정 | `arcamap-api` |
| ASG | 인스턴스 수와 상태를 유지하는 그룹 | 최소 2대·최대 4대 |
| 목표 추적 | 지표가 목표값을 유지하도록 용량 조정 | ASG 평균 CPU 50% |
| Instance Refresh | 변경된 템플릿으로 기존 인스턴스 교체 | Rolling 방식 |
| Warmup | 새 인스턴스의 초기 준비 대기 시간 | 300초 |
| 상태 검사 유예 | 초기 준비 중 상태 검사에 따른 교체를 유예 | 300초 |

## 현재 구성

| 항목 | 값 |
|---|---|
| 모듈 / 호출 루트 | `terraform/modules/compute` / `terraform/env/was` |
| 시작 템플릿 / ASG | `arcamap-api` / `arcamap-api` |
| AMI | Image Builder 출력 |
| 인스턴스 / 디스크 | `t3.small` / 암호화 gp3 20 GiB, 종료 시 삭제 |
| CPU 크레딧 / 상세 모니터링 | `unlimited` / 비활성화 |
| 메타데이터 | IMDSv2 필수, hop limit 1 |
| 배치 | API 사설 서브넷 2a·2c, `balanced-best-effort` |
| 보안 그룹 / 프로파일 | `arcamap-api` / `arcamap-api-instance-profile` |
| ASG 최소·최대 | 2대·4대 |
| Desired capacity | 코드에 고정값 없음, ASG가 조정 |
| 상태 검사 | 실제 입력 `ELB`, 변수 기본값 `EC2` |
| 그룹 지표 | `GroupInServiceInstances`, `GroupDesiredCapacity`, 1분 |
| CPU 확장 정책 | `ASGAverageCPUUtilization`, 목표 50%, 축소 허용 |

## 입력

| 변수 | 공급 값·조건 |
|---|---|
| `api_subnet_ids` | 서로 다른 AZ의 API 서브넷 ID 2개 |
| `api_security_group_id` | app이 생성한 API 보안 그룹 |
| `image` | AMI `id`, `root_device_name`, `root_volume_size` |
| `target_group_arn` | HTTPS 리스너 연결이 완료된 ALB 대상 그룹 |
| `ec2_instance_profile_name` | WAS에서 생성한 운영 프로파일 |
| `ec2_instance_type` | `t3.small` |
| `ec2_root_volume_size` | 20 GiB 이상이며 빌드 볼륨 이상 |
| `asg_max_size` / `asg_cpu_target` | 4 / 50 |
| `asg_health_check_type` | `ELB` |
| `cloudwatch_agent_start` | WAS에서 조합한 Agent 시작 명령 |

DB 접속 객체 입력은 없습니다. DB 환경은 API 서비스 시작 시 Secrets Manager에서 조회합니다.

## 부팅·교체 흐름

```text
Image Builder AMI → 시작 템플릿 최신 버전 → ASG → EC2 부팅
  ├─ user_data → CloudWatch Agent 시작
  └─ systemd → DB Secret 조회 → API 시작 → ALB /health
```

| 교체 설정 | 값·영향 |
|---|---|
| 방식 | Rolling |
| 최소·최대 정상 비율 | 0%·100% |
| 교체 Warmup | 300초 |
| 일치 인스턴스 | `skip_matching=true`로 교체 생략 |
| 가용성 | 최소 정상 비율 0%로 교체 중 API 중단 가능 |

`ELB`는 EC2 상태와 로드 밸런서 대상 상태를 고장 판단에 사용합니다. `/health`는 API 응답을 확인하며 DB 상태는 포함하지 않습니다.

## 적용·점검

실행 위치: `/root/protomaps`. WAS 배포 아카이브·DB 비밀번호 입력 준비.

```bash
terraform -chdir=terraform/env/was plan -out=was.tfplan
terraform -chdir=terraform/env/was apply was.tfplan
terraform -chdir=terraform/env/was output launch_template

aws autoscaling describe-instance-refreshes \
  --region ap-northeast-2 --auto-scaling-group-name arcamap-api
aws autoscaling describe-auto-scaling-groups \
  --region ap-northeast-2 --auto-scaling-group-names arcamap-api \
  --query 'AutoScalingGroups[].{Min:MinSize,Max:MaxSize,Desired:DesiredCapacity,HealthCheck:HealthCheckType,Instances:Instances}'
```

## 출력·정상 기준

| 출력·점검 | 내용·기준 |
|---|---|
| `autoscaling_group` | `name`, `arn` |
| `launch_template` | `id`, `version`, `ami_id` |
| 이미지 연결 | 시작 템플릿의 AMI와 Image Builder 출력 일치 |
| ASG | 목표 수의 인스턴스 `InService`, 상태 `Healthy` |
| Instance Refresh | 교체 완료 시 `Successful` |
| API | ALB 대상 `healthy`, `/health` HTTP 200 |
