# CloudWatch 메모리 수집·운영 경보·통합 대시보드

## 1. 원인

기존에는 EC2의 CPU 사용률을 확인할 수 있었지만 메모리 사용량은 수집하지 않았습니다. CPU 사용률이 낮아도 메모리가 부족할 수 있으므로, CPU 지표만으로는 EC2의 자원 상태를 판단하기 어려웠습니다.

또한 ASG·ALB·WAF의 지표와 로그를 각각 확인해야 했습니다. AMI 교체 중 오류가 발생했을 때 인스턴스 수, 정상 대상 수, HTTP 오류와 로그를 같은 시간대로 비교할 통합 대시보드가 필요했습니다. 이 내용은 [기존 운영 분석](../insight.md)의 메모리 지표 수집과 CloudWatch 통합 대시보드 구성 항목에 기록돼 있습니다.

## 2. 변경 계획

CloudWatch Agent는 EC2 안에서 메모리 사용량과 시스템 로그를 수집해 CloudWatch로 전달하는 프로그램입니다. 기존 Agent 설정에 메모리 지표를 추가하고, 인스턴스별 사용량과 ASG 평균 사용률을 함께 확인하도록 구성합니다.

메모리 운영 경보는 기존 CPU 운영 경보와 같은 기준으로 설정합니다. ASG 평균 메모리 사용률이 80% 이상인 5분 구간이 3회 연속 발생하면 경보 상태로 변경합니다.

통합 대시보드에는 ASG·EC2·ALB·WAF의 지표, 관련 경보와 Logs Insights 조회 결과를 모읍니다. 최근 7일을 5분 단위로 집계해 AMI 교체 전후의 상태를 같은 시간대에서 비교합니다.

현재 구성의 EC2 최소 2대·최대 4대는 유지합니다. 메모리 기반 ASG 확장 정책과 Instance Refresh 자동 롤백은 [ASG 변경 기록](asg-instance-refresh-rolling-deployment.md)에 따로 기록합니다.

## 3. 변경 후

### 3.1 CloudWatch Agent 메모리 수집

[API Agent 구성](../../env/api/monitoring.tf)의 기존 Agent 설정에 다음 항목을 추가했습니다.

| 항목 | 설정과 의미 |
|---|---|
| 네임스페이스 | `CWAgent` |
| `mem_used_percent` | EC2 전체 메모리 사용률, `Percent` |
| `mem_available` | EC2 가용 메모리, `Bytes` |
| Agent `mem.measurement` | `used_percent`, `available` — 게시되는 지표에는 `mem_` 접두사가 붙음 |
| 수집 주기 | 60초 |
| 개별 인스턴스 차원 | `AutoScalingGroupName`, `InstanceId` |
| ASG 집계 차원 | `aggregation_dimensions = [["AutoScalingGroupName"]]` |

기존 Image Builder가 이 JSON을 AMI 안에 기록합니다. 운영 EC2는 기존 user data의 Agent 시작 명령으로 설정을 읽습니다. 따라서 변경한 Terraform을 적용해 새 AMI를 빌드·배포해야 운영 인스턴스에서 수집됩니다. 기존 `CloudWatchAgentServerPolicy`를 사용하며 메모리 수집을 위한 별도 API 코드나 SDK 계측은 추가하지 않습니다.

API는 systemd 서비스로 실행됩니다. API와 시스템 로그는 기존 journald 수집 경로인 `/arcamap/ec2/system`에서 함께 조회합니다. `/arcamap/api/application` 로그 그룹은 정의돼 있지만 별도 수집 경로가 연결돼 있지 않아 대시보드 조회 대상에서 제외했습니다.

[CloudWatch Agent 지표](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/metrics-collected-by-CloudWatch-agent.html), [AWS 메모리 수집·ASG 집계 예제](https://aws.amazon.com/blogs/mt/create-amazon-ec2-auto-scaling-policy-memory-utilization-metric-linux/)

### 3.2 메모리 운영 경보

| 항목 | 값 |
|---|---|
| 경보 이름 | `arcamap-ec2-memory` |
| 지표 | `CWAgent / mem_used_percent` |
| 차원 | `AutoScalingGroupName=arcamap-api` |
| 통계 | `Average` |
| 임계값 | 80% 이상 |
| 평가 주기 | 300초 |
| 경보 판정 | 최근 3개 구간 중 3개 충족, 즉 5분 구간 3개 연속 |
| 누락 데이터 | `missing` |
| 알림 동작 | 기존 CPU 운영 경보처럼 비활성 |

이 경보는 운영 상태 표시용입니다. ASG의 50% 목표 추적 정책은 별도 정책이며, 목표 추적에 필요한 경보는 AWS Auto Scaling이 관리합니다. 운영 경보를 확장 정책에 직접 연결하지 않습니다.

### 3.3 통합 대시보드

#### 관리 위치와 연결

대시보드 이름은 arcamap-operations입니다. [대시보드 모듈](../../modules/cloudwatch-dashboard/main.tf)에서 리소스와 위젯을 정의하고, [CloudWatch 환경](../../env/monitoring/main.tf)에서 모니터링 대상을 조회해 모듈에 연결합니다.

ASG·ALB·Web ACL은 이름으로 조회하고, ALB 대상 그룹은 ASG에 연결된 정보를 사용합니다. 로그 그룹은 이름의 접두사로 조회합니다. 각 조회 결과가 정확히 하나일 때만 연결하므로, CloudFront 배포 ID가 바뀌어도 로그 그룹 이름을 직접 입력할 필요가 없습니다. 같은 접두사의 로그 그룹이 여러 개라면 조회 조건을 조정해야 합니다.

경보는 WAS 환경에서 생성합니다. 대시보드에서는 코드에 지정한 경보 이름과 현재 계정 ID를 조합해 경보 ARN을 연결합니다. WAS·WEB 리소스를 배포한 뒤 CloudWatch 환경을 적용하면 대상 리소스를 조회해 통합 대시보드를 생성합니다.

#### 조회 기준

기본 조회 범위는 **최근 7일**, 집계 단위는 **5분**입니다. `start="-P7D"`, `periodOverride="inherit"`, 지표 위젯 `period=300`, 로그 통계 `bin(5m)`를 사용합니다. 위젯별 별도 시작·종료 시간을 지정하지 않아 같은 조회 시간대를 사용합니다.

로그 원문 표는 선택한 시간대의 최근 100건을 표시합니다. 경보 위젯은 과거 7일의 경보 이력이 아닌 **현재 경보 상태**를 표시합니다. 대시보드의 5분 집계는 Agent 수집 주기·경보 평가 주기·새로고침 주기를 바꾸지 않습니다.

| 위젯 | 지표·조회 내용 | 통계 |
|---|---|---|
| ASG 인스턴스 수 | `GroupInServiceInstances`, `GroupDesiredCapacity` | 평균 |
| CPU·메모리 사용률 | `CPUUtilization`, `mem_used_percent` | ASG 평균 |
| EC2별 메모리 | `CWAgent`의 ASG·InstanceId 차원을 검색 | 인스턴스별 평균 |
| 가용 메모리 | `mem_available` | ASG 인스턴스당 평균 Bytes |
| 정상 대상 수 | `HealthyHostCount` — ALB 대상 그룹의 정상 대상 수 | 최솟값 |
| 요청량 | `RequestCount` — ALB가 처리한 요청 수 | 합계 |
| 응답 시간 | `TargetResponseTime` — ALB가 API 대상으로 요청을 보낸 뒤 응답 헤더를 받기 시작할 때까지의 시간 | 평균 초 |
| ALB·API HTTP 오류 | `HTTPCode_ELB_4XX_Count`, `HTTPCode_ELB_5XX_Count`는 ALB 자체 오류, `HTTPCode_Target_4XX_Count`, `HTTPCode_Target_5XX_Count`는 API 대상 오류 | 합계 |
| WAF 허용·차단 | 각 Web ACL의 `AllowedRequests`, `BlockedRequests` | 합계 |
| ALB 로그 | 기존 접근·연결·상태 검사 로그 | 최근 원문 100건 |
| 시스템·API 오류 로그 | 기존 journald 로그에서 오류 관련 문구 검색 | 최근 원문 100건, 완전한 오류 판별기는 아님 |
| WAF 규칙별 차단 | `action=BLOCK`, `terminatingRuleId`와 관리형 그룹 내부의 실제 차단 규칙 | 5분 합계 |
| 경보 | ASG 인스턴스 수·EC2 상태 검사·CPU·메모리·ALB 정상 대상 수·ALB 자체 5xx·API 대상 5xx | 현재 상태 |

API 지표·로그의 리전은 `ap-northeast-2`, CloudFront WAF의 리전은 `us-east-1`입니다. CloudFront WAF 지표에는 `Region` 차원을 넣지 않습니다. 현재 두 Web ACL은 이름과 `visibility_config.metric_name`이 같으므로, 조회한 이름을 지표의 WebACL 차원에 사용합니다.

[AWS 대시보드 본문](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Dashboard-Body-Structure.html), [AWS WAF 지표](https://docs.aws.amazon.com/waf/latest/developerguide/waf-metrics.html), [WAF 실제 차단 규칙 확인](https://repost.aws/knowledge-center/waf-detect-false-positives-from-amrs)

## 4. 보존 기간과 비용

로그 보존 기간은 기존 설정인 WAS 로그 30일·WAF 로그 14일을 유지했습니다. 대시보드에서는 이 중 최근 7일을 조회합니다. insight.md 초안의 일괄 7일 보존은 이번 변경에 적용하지 않았습니다.

하루 집계를 5분 집계로 바꾸는 것 자체에 추가 요금이 붙지는 않습니다. 커스텀 지표·경보·대시보드의 사용 요금과 로그 조회 비용은 별도입니다. Logs Insights는 스캔 용량으로 과금하며 대시보드 새로고침 시 쿼리가 다시 실행됩니다. 최근 7일치 로그를 반복 조회하는 비용은 실제 로그량과 조회 횟수에 따라 달라집니다. [CloudWatch 요금](https://aws.amazon.com/cloudwatch/pricing/)

## 5. 검증

Terraform 형식·유효성 검사와 모의 Provider를 사용한 plan 검사를 수행했습니다. 현재 계정에는 배포된 리소스가 없으므로, 실제 지표 수집과 로그 조회, 경보 전환과 자동 롤백은 아직 검증하지 않았습니다.

### 로컬 검사 결과

- `terraform -chdir=env/was validate`: 통과. Agent·경보·ASG·이미지 빌드 입력의 구문·참조 검사.
- `terraform -chdir=env/cloudwatch validate`: 통과.
- `terraform -chdir=modules/cloudwatch-dashboard validate`: 통과.
- `terraform -chdir=env/cloudwatch test`: 모의 Provider를 사용한 plan 검사 3개 통과.
  - `environment_connections`: 환경의 데이터 소스·모듈 연결.
  - `dashboard_time_regions_and_logs`: 최근 7일·5분 집계, CloudFront WAF 리전·차원, 로그 SOURCE 연결.
  - `memory_scaling_and_rollback`: 최소 2·최대 4대, CPU·메모리 50% 목표, 자동 롤백과 경보 연결.
- 수정한 Terraform 파일의 `fmt -check`와 `git diff --check`: 통과.

검사는 `mock_provider`와 `command=plan`으로 실행했습니다. 검증 완료 후 테스트 코드와 임시 생성물은 삭제하고 결과만 기록했습니다.

API 배포 파일 참조는 `app/was/`로 정정했습니다. RDS CA 인증서는 현재 실제 파일 위치인 `app/data/rds-ap-northeast-2-bundle.pem`을 참조합니다. 파일 내용이나 API 실행 경로 `/opt/arcamap/was`는 변경하지 않았습니다.
