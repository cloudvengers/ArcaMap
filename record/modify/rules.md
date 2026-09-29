# 단일 구성 전 운영 개선 항목

## 1. 목적과 현재 상태

기존 ArcaMap은 다중 AZ와 여러 EC2 인스턴스를 사용하는 고가용성 구성으로 운영했습니다. 운영 과정에서 AMI 교체 중 서비스 중단, WAF의 차단 범위 부족, 메모리 관측 부재와 수동 장애 대응 문제가 확인됐습니다.

현재 계정에는 배포된 리소스가 없습니다. 기존 운영 기록을 바탕으로 재배포 전에 Terraform 코드를 수정하고 있으며, 현재 코드의 EC2 최소 2대·최대 4대 구성은 유지합니다. 향후 단일 구성 전환에 앞서 배포·관측·복구 과정의 문제를 개선하고 검증 결과를 기록합니다.

작업은 다음 순서로 진행했습니다. 아래의 코드 반영 완료는 AWS 배포나 실제 동작 검증 완료를 뜻하지 않습니다.

| 항목 | 코드 반영 상태 | 상세 기록 |
|---|---|---|
| 2. ASG 무중단 롤링 배포 | 최소 정상 비율 100%·최대 용량 비율 200% 반영 | [ASG 변경 기록](asg-instance-refresh-rolling-deployment.md) |
| 3. WAF 운영 정책 개선 | CloudFront 규칙 조정·API ALB WAF 추가 반영 | [WAF 변경 기록](waf-additional-decisions.md) |
| 4. CloudWatch 통합 관측과 ASG 자동 대응 | 메모리 수집·경보·확장 정책·롤백·대시보드 반영 | [CloudWatch 변경 기록](cloudwatch-monitoring.md), [ASG 변경 기록](asg-instance-refresh-rolling-deployment.md) |

## 2. ASG Instance Refresh를 이용한 무중단 롤링 배포

### 원인

기존 Instance Refresh의 최소 정상 비율은 0%, 최대 용량 비율은 100%였습니다. 기존 API EC2가 먼저 종료되고 새 EC2가 요청을 처리하기 전까지 정상 대상이 없는 구간이 발생했습니다.

### 변경 후

[ASG 설정](../../modules/compute/main.tf)의 최소 정상 비율을 100%, 최대 용량 비율을 200%로 변경했습니다.

목표 용량이 2대라면 기존 정상 EC2 2대가 요청을 처리하는 동안 새 EC2를 최대 2대 추가로 생성할 수 있습니다. 새 EC2가 ALB의 `/health` 검사와 300초 워밍업을 마친 뒤 기존 EC2를 대상 그룹에서 제외하고 종료하도록 구성했습니다.

### 검증 상태

코드 반영을 완료했습니다. 실제 배포에서는 정상 대상 수, 배포 중 API 요청 실패 여부, 기존 대상의 `draining` 전환과 Instance Refresh의 `Successful` 상태를 확인해야 합니다.

## 3. WAF 운영 정책 개선

### 원인

기존 CloudFront WAF는 관리형 규칙 그룹 전체를 Count로 설정해 공격에 일치한 요청도 기록만 남겼습니다. API ALB에는 WAF가 연결돼 있지 않았고, Anti-DDoS 관리형 규칙 그룹의 유지 비용 비중이 높았습니다.

### 변경 후

[CloudFront WAF](../../modules/cloudfront/waf.tf)와 [API ALB WAF](../../modules/alb/waf.tf)에 다음 내용을 반영했습니다.

| 항목 | 반영 내용 |
|---|---|
| Anti-DDoS 관리형 규칙 그룹 | CloudFront의 `AWSManagedRulesAntiDDoSRuleSet` 제거 |
| 관리형 규칙 그룹 3개 | Amazon IP 신뢰도 목록·핵심 규칙 세트·알려진 잘못된 입력 규칙을 양쪽에 적용하고 그룹 전체 Count 해제 |
| DDoS 활동 IP 규칙 | `AWSManagedIPDDoSList`에 Block 지정 |
| API 보호 | 서울 리전에 Web ACL을 추가하고 ALB에 연결 |
| 외부 DB 상태 검사 차단 | URL 디코딩·경로 정규화 후 `/health/db`와 `/health/db/` 차단. `/health`는 이 규칙에서 제외 |
| 로그·지표 | 양쪽 WAF 로그 14일 보존, CloudWatch 지표 활성화 |
| 인증정보 보호 | 요청 샘플 저장 중단, 로그의 `authorization`·`cookie`·`proxy-authorization` 헤더 가림 |
| 신규 배포 구성 | 과거 WAF import 선언 제거, 로그 목적지를 로그 그룹 ARN으로 정정 |

속도 기반 규칙(Rate-based Rule)은 현재 코드에 없습니다. 기존 WAF 변경 기록에 따라 배포 후 정상 요청량을 측정하고 제한값을 검증한 뒤 추가할 항목입니다. 이번 CloudWatch 작업에서는 별도의 IP 임시 차단이나 Lambda 자동 분석을 추가하지 않았습니다.

### 검증 상태

WAF 변경 당시 CloudFront 환경·ALB 모듈의 Terraform 유효성 검사와 규칙 구성 검사를 통과했습니다. 당시 API 산출물 경로 문제로 실패했던 WAS 전체 검증은 이후 경로를 `app/was/`로 정정한 뒤 통과했습니다.

실제 AWS 요청 차단과 로그 수집은 아직 검증하지 않았습니다. 배포 후 정상 웹·API 요청, 차단 대상 요청, `/health/db` 경로 변형과 인증정보 가림 여부를 확인해야 합니다.

## 4. CloudWatch 통합 관측과 ASG 자동 대응

### 원인

기존 경보는 상태 확인 용도로 사용했고, Instance Refresh 실패 시 이전 AMI로 되돌리는 자동 롤백이 없었습니다. EC2 메모리 지표를 수집하지 않아 메모리 운영 경보와 메모리 기반 확장 정책도 없었습니다.

[기존 운영 분석](../insight.md)의 메모리 지표 수집과 통합 대시보드 구성을 바탕으로 관측 항목을 추가하고, 기존 경보를 ASG의 자동 복구 동작에 연결했습니다.

### 변경 후

#### 메모리 수집과 운영 경보

CloudWatch Agent에 다음 지표를 추가했습니다.

- `mem_used_percent` — EC2 전체 메모리 사용률(%).
- `mem_available` — EC2 가용 메모리 용량(Bytes).

60초마다 수집하고 인스턴스별 차원과 ASG 집계를 함께 게시하도록 구성했습니다. Agent 설정은 기존 Image Builder를 통해 새 AMI에 반영합니다.

운영 경보 `arcamap-ec2-memory`는 ASG 평균 메모리 사용률이 80% 이상인 5분 구간이 3회 연속 발생하면 `ALARM`이 되도록 설정했습니다. 기존 CPU 운영 경보와 같은 기준입니다.

#### 메모리 기반 ASG 확장

메모리 평균 사용률 50%를 목표로 하는 `arcamap-api-memory` 목표 추적 정책을 추가했습니다. 기존 CPU 50% 정책과 함께 사용하며, 한 정책이라도 확장을 요구하면 증설하고 두 정책이 모두 축소에 동의하면 감축합니다. 최소 2대·최대 4대는 유지합니다.

운영 경보의 80% 기준과 목표 추적 정책의 50% 기준은 역할이 다릅니다. 목표 추적에 필요한 경보는 AWS Auto Scaling이 관리합니다.

#### Instance Refresh 자동 롤백

`auto_rollback=true`로 설정하고 기존 경보 3개를 연결했습니다.

| 경보 이름 | 지표와 의미 | 경보 조건 |
|---|---|---|
| `arcamap-alb-healthy-hosts` | `HealthyHostCount` — ALB 대상 그룹의 정상 대상 수 | 1분 최솟값이 2대 미만인 구간이 최근 3개 중 2개 |
| `arcamap-alb-5xx` | `HTTPCode_ELB_5XX_Count` — ALB 자체에서 발생한 HTTP 5xx 응답 수 | 5분 합계 5건 이상 |
| `arcamap-api-5xx` | `HTTPCode_Target_5XX_Count` — API 대상에서 발생한 HTTP 5xx 응답 수 | 5분 합계 5건 이상 |

Instance Refresh 중 연결한 경보가 `ALARM`이 되거나 교체 작업 자체가 실패하면 이전 Launch Template 설정으로 롤백하도록 구성했습니다. 인스턴스 생성 실패 등은 교체를 재시도한 뒤 롤백할 수 있습니다. 배포 완료 후 발생한 장애는 이 자동 롤백의 대상이 아닙니다.

#### 통합 대시보드

[대시보드 모듈](../../modules/cloudwatch-dashboard/main.tf)에서 위젯을 정의하고, [CloudWatch 환경](../../env/monitoring/main.tf)에서 데이터 소스로 WAS·WEB의 대상을 조회해 연결합니다. 실제 적용 시에는 조회할 WAS·WEB 리소스가 먼저 배포돼 있어야 합니다.

대시보드는 최근 7일·5분 단위 집계로 다음 내용을 함께 표시합니다.

- ASG 인스턴스 수, EC2 CPU·메모리와 ALB 정상 대상 수.
- `RequestCount` — ALB가 처리한 요청 수.
- `TargetResponseTime` — ALB가 API 대상으로 요청을 보낸 뒤 응답 헤더를 받기 시작할 때까지의 시간.
- ALB 자체·API 대상의 HTTP 오류 지표와 관련 경보.
- WAF 허용·차단 추이와 규칙별 차단 내역.
- 기존 ALB·시스템·WAF 로그의 Logs Insights 조회 결과.

로그 원문은 선택한 시간대의 최근 100건, 경보 위젯은 현재 상태를 표시합니다. 로그 보존 기간은 기존 WAS 30일·WAF 14일을 유지합니다.

### 검증 상태

WAS 환경, CloudWatch 환경과 대시보드 모듈의 Terraform 유효성 검사를 통과했습니다. 모의 Provider를 사용한 plan 검사 3개에서 환경 연결, 대시보드 시간·리전·로그 설정, 메모리 정책과 롤백 경보 연결을 확인했습니다. 검증 후 테스트 코드와 임시 생성물은 삭제하고 결과는 [CloudWatch 검증 기록](cloudwatch-monitoring.md#로컬-검사-결과)에 남겼습니다.

실제 배포·AMI 빌드·부하 시험·실패 AMI 배포는 실행하지 않았습니다. 배포 후에는 다음 사항을 확인해야 합니다.

1. Agent가 인스턴스별·ASG별 메모리 지표를 게시하는지 확인합니다.
2. 메모리 운영 경보와 목표 추적 정책이 각각의 기준으로 동작하는지 확인합니다.
3. 정상 AMI 교체가 `Successful`로 완료되는지 확인합니다.
4. Refresh 진행 중 경보 발생 또는 교체 실패 시 롤백 결과와 이전 AMI 복구 여부를 확인합니다.
5. 대시보드에서 같은 시간대의 지표와 로그를 조회할 수 있는지 확인합니다.

CloudWatch의 수집·운영 경보·대시보드 내용은 CloudWatch 문서에, ASG의 확장·배포·롤백 내용은 ASG 문서에 기록합니다.
