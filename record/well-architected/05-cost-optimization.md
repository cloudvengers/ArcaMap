# Cost Optimization(비용 최적화)

**💰 S3·CloudFront로 콘텐츠를 제공하고 두 가용 영역의 API·DB·NAT를 유지하는 ArcaMap의 운영 구성**

CloudFront는 웹·지도·사진을 캐시하고, ALB는 API 서버로 요청을 전달합니다. 운영 비용은 RDS와 NAT의 유지 비용이 큰 비중을 차지합니다. API·DB의 낮은 사용률과 서비스 가용성 요구를 함께 고려해 필요한 용량을 판단해야 합니다.

**공통 집계 기간은 KST 2026-09-14 00:00:00 이상~2026-09-22 00:00:00 미만**, **구성 확인 시점은 KST 2026-09-22 15:45~15:54**입니다.

[현재 운영](#current-operations) · [기둥의 원칙](#pillar-principles) · [질문 및 모범 사례](#best-practices) · [발견 사항](#findings) · [결론](#conclusion)

<a id="current-operations"></a>

## 1. Current Operations(현재 운영 현황)

API·RDS·NAT·S3는 서울에서 운영합니다. CloudFront가 정적 콘텐츠를 전 세계에 제공하며, 연결된 WAF와 로그 전달 설정은 버지니아 북부에 있습니다.

<a id="resources"></a>

### 1.1 리소스 구성

| 운영 대상 | 구성·역할 | Terraform 정의 |
|---|---|---|
| API 서버 | 오토 스케일링 그룹(ASG) `arcamap-api`가 `t3.small` Linux 인스턴스 2대를 2a·2c에 배치합니다. 두 인스턴스 모두 정상 상태이며 시작 템플릿 버전 2를 사용합니다. | [시작 템플릿·ASG](../../terraform/modules/compute/main.tf#L1) |
| 용량 조절 | `arcamap-api-cpu` 정책이 평균 CPU 50%를 목표로 2~4대를 유지합니다. 축소를 허용하며 예약 확장은 없습니다. | [목표 추적 정책](../../terraform/modules/compute/main.tf#L81) |
| API 저장 공간 | 인스턴스마다 gp3 EBS 20GiB를 연결합니다. 3,000 IOPS·125MiB/s이며 인스턴스 종료 시 삭제합니다. | [루트 볼륨](../../terraform/modules/compute/main.tf#L15) |
| 데이터베이스 | `arcamap-postgres`는 PostgreSQL 17.11·`db.t4g.medium`·Multi-AZ입니다. gp3 20GiB를 사용하고 100GiB까지 자동 확장하며, 자동 백업을 3일 보존합니다. | [RDS](../../terraform/modules/database/main.tf#L6) |
| 요청 분산 | ALB `arcamap-api`가 HTTP를 HTTPS로 전환하고 API에 HTTP 8080으로 전달합니다. 유지 시간과 처리 용량에 따라 비용이 발생합니다. | [ALB](../../terraform/modules/alb/main.tf#L1) |
| 외부 연결 | API 서브넷마다 같은 가용 영역의 NAT Gateway를 사용합니다. NAT 2대가 운영 중이며 VPC Endpoint는 없습니다. NAT 유지·처리 비용과 공인 IPv4 사용료가 발생합니다. | [NAT·라우팅](../../terraform/modules/network/main.tf#L56) |
| 정적 콘텐츠 | CloudFront `E39UQTOCMBVZB3`가 오리진 접근 제어(OAC)로 웹·지도·사진 S3에 접근합니다. 가격 등급은 `PriceClass_200`, 기본·최대 캐시 유지 시간(TTL)은 웹 300초·지도와 사진 86,400초입니다. 웹 응답을 압축합니다. | [캐시 정책](../../terraform/modules/cloudfront/main.tf#L12), [배포](../../terraform/modules/cloudfront/main.tf#L60) |
| 웹 요청 검사 | WAF `CreatedByCloudFront-609132c8`의 관리형 규칙 4개는 Count 모드로 검사 결과를 기록합니다. Anti-DDoS가 포함되며 별도 속도 제한 규칙은 없습니다. | [WAF](../../terraform/modules/cloudfront/waf.tf#L29) |
| 이미지 생성 | Image Builder `arcamap-api`가 전용 역할의 `t3.small`에서 이미지를 빌드하며 실패 시 인스턴스를 종료합니다. 현재 API가 사용하는 자체 AMI와 연결 스냅샷이 각각 1개 있습니다. | [빌드 구성](../../terraform/modules/image-builder/main.tf#L232), [이미지](../../terraform/modules/image-builder/main.tf#L246) |

S3는 콘텐츠 원본·배포 자료·접근 로그를 용도별로 보관합니다.

| S3 역할 | 보존 설정 | Terraform 정의 |
|---|---|---|
| 웹 원본 | 객체 만료 규칙 없음 | [웹 버킷](../../terraform/env/web/main.tf#L14) |
| 지도 원본 | 기존 지도 버킷 사용, 객체 만료 규칙 없음 | [지도 버킷 참조](../../terraform/env/web/main.tf#L3) |
| 사진 원본 | 버전 관리 활성, 이전 버전 7일 후 삭제·삭제 마커 정리 | [사진 버킷](../../terraform/env/web/main.tf#L21), [수명 주기](../../terraform/modules/s3-bucket/main.tf#L43) |
| CloudFront 접근 로그 | 객체 30일 후 만료 | [로그 버킷](../../terraform/env/web/main.tf#L26) |
| API 배포 아카이브 | 객체 만료 규칙 없음 | [배포 버킷](../../terraform/env/was/deployment.tf#L6) |

<a id="observability"></a>

### 1.2 옵저빌리티 구성

| 목적 | 도구·설정 | 운영상 의미 |
|---|---|---|
| 비용 분석 | Cost Explorer의 일별 비용·사용량 | 서비스별 지출과 주요 과금 원인을 파악합니다. |
| 이상 비용 알림 | `Default-Services-Monitor`와 일일 이메일 구독 `Default-Services-Subscription` | 이상 비용 영향이 **100달러 이상이면서 40% 이상**이면 알림 대상입니다. |
| 비용 귀속 | 비용 할당 태그 모두 비활성, Cost Categories 미구성 | 업무·환경·소유자별 비용을 구분하기 어렵습니다. |
| 상세 비용 | 시간 단위 비용 비활성, 상세 비용·사용량 보고서(CUR)와 Data Exports 미구성 | 자원별 비용과 운영 사건의 시간대를 연결하는 자료가 부족합니다. |
| 최적화 권고 | Compute Optimizer 비활성, Cost Optimization Hub 미등록 | AWS의 자동 용량·절감 권고를 사용하지 않습니다. |
| 상태·용량 감지 | EC2·ASG·ALB·RDS CloudWatch 경보 | 목표 추적 경보 2개는 용량을 조절하며 서비스 경보 9개는 운영자 알림을 보내지 않습니다. |
| 상세 성능 | EC2 기본 모니터링, ASG 1분 용량 지표, RDS 기본 지표 | API 메모리 지표와 사용자 정의 대시보드는 없습니다. RDS Performance Insights·Enhanced Monitoring은 비활성입니다. |

로그 수집은 [API 구성](../../terraform/env/was/main.tf#L44), DB 경보는 [DB 구성](../../terraform/env/db/main.tf#L21), 알림 동작은 [경보 모듈](../../terraform/modules/cloudwatch-alarm/main.tf#L15)에 정의합니다. 예산·비용 관리 절차의 자료 제약은 [4.6 비용 귀속](#visibility-findings)에 있습니다.

<a id="telemetry"></a>

### 1.3 텔레메트리 수집 현황

| 자료 | 수집 위치·대상 | 수집 범위 |
|---|---|---|
| 비용·사용량 | Cost Explorer | 일별 운영 사용료입니다. 실제 비용 기간은 [4.1 비용 구조](#billing-findings)에 있습니다. |
| 자원·요청 지표 | 서울 CloudWatch의 API·ASG·RDS·ALB·NAT, 버지니아 북부의 CloudFront 지표 | 공통 기간의 CPU·용량·요청·전송량입니다. [자원 사용률](#capacity-findings), [전송량](#network-findings) |
| 시스템·API 로그 | 서울 `/arcamap/ec2/system`의 인스턴스별 시스템 스트림 | 시스템과 API 관련 기록을 30일 보존합니다. API 전용 `/arcamap/api/application`에는 스트림이 없습니다. |
| DB·빌드·ALB 로그 | 서울 `/aws/rds/instance/arcamap-postgres/postgresql`, `/aws/imagebuilder/arcamap-api`, `/aws/vendedlogs/elb/arcamap-api` | 공통 기간 로그가 유입되며 30일 보존합니다. RDS upgrade 로그에는 스트림이 없습니다. |
| CloudFront 접근 로그 | 로그 전달 설정 `arcamap-cloudfront` → 서울 접근 로그 버킷 | 표준 로깅 v2로 요청을 기록합니다. [전달 정의](../../terraform/modules/cloudfront/main.tf#L137), [캐시 기록](#network-findings) |
| WAF 로그 | 버지니아 북부 `aws-waf-logs-CloudFrontDistribution-E39UQTOCMBVZB3` | 요청 검사 기록을 14일 보존합니다. [로그 정의](../../terraform/modules/cloudfront/waf.tf#L1) |
| 저장 상태 | 서울 CloudWatch의 S3 버킷별 저장량·객체 수 | 일별 저장 상태입니다. [보관 규모](#lifecycle-findings) |
| 운영 사건 | ASG `arcamap-api` 활동·RDS `arcamap-postgres` 이벤트 | 공통 기간의 생성·교체·종료·백업 기록입니다. [자원 수명 주기](#lifecycle-findings) |

<a id="pillar-principles"></a>

## 2. [Pillar Principles(기둥의 원칙에 따른 검토)](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost-optimization.html)

AWS는 비용 최적화를 **업무 가치를 제공하는 시스템을 가능한 낮은 비용으로 운영하는 능력**으로 [정의합니다](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost-def.html). ArcaMap은 다음 [설계 원칙](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost-dp.html)에 따라 자원 사용량과 가용성·운영 부담을 함께 고려해야 합니다.

| 공식 설계 원칙 | 현재 운영 |
|---|---|
| **Implement Cloud Financial Management** | 일별 비용과 이상 탐지 구독을 사용합니다. 비용 책임·예산·정기 검토의 운영 자료는 부족합니다. [비용 관리](#visibility-findings) |
| **Adopt a consumption model** | API 수량은 CPU 부하에 따라 조절합니다. 최소 API 2대·Multi-AZ RDS·NAT 2대는 낮은 수요에서도 유지됩니다. [용량과 수요](#capacity-findings) |
| **Measure overall efficiency** | 자원 사용률은 낮지만 성공한 검색·시설 조회와 비용을 연결할 업무 지표는 미확인입니다. [비용과 업무 성과](#visibility-findings) |
| **Stop spending money on undifferentiated heavy lifting** | RDS·ALB·S3·CloudFront가 공통 운영 기능을 맡고 이미지 생성·교체·백업은 자동으로 실행됩니다. 대체 구성과의 운영 노력 비교는 미확인입니다. [자동화·보존](#lifecycle-findings) |
| **Analyze and attribute expenditure** | 주요 지출은 RDS·NAT 유지 비용입니다. 비용 태그가 비활성이어서 업무·소유자별 귀속은 어렵습니다. [비용 구조](#billing-findings), [귀속 설정](#visibility-findings) |

<a id="best-practices"></a>

## 3. [Questions and Best Practices(질문 및 모범 사례별 상세 점검)](https://docs.aws.amazon.com/wellarchitected/latest/framework/a-cost-optimization.html)

[AWS Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/latest/framework/welcome.html)의 [기둥 정의](https://docs.aws.amazon.com/wellarchitected/latest/framework/the-pillars-of-the-framework.html)와 [공식 질문·BP](https://docs.aws.amazon.com/wellarchitected/latest/framework/appendix.html)는 비용 최적화의 운영 기준입니다.

### 3.1 클라우드 재무 관리 — COST 1

[COST 1. How do you implement cloud financial management?](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost-01.html)

**질문 판정: 확인 불가.** 비용 도구와 이상 탐지 구독은 있지만 책임·예산·정기 검토의 이행 자료가 부족합니다.

| 공식 BP·명칭 | 점검 기준 | 현재 상태·판정 사유 | 근거 | 판정 |
|---|---|---|---|---|
| [COST01-BP01 Establish ownership of cost optimization](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_cloud_financial_management_function.html) | 비용 최적화의 책임·업무·성과 기준을 정합니다. | 비용 담당자와 업무 배정 기록이 미확인이라 책임 체계의 이행 여부를 판단할 수 없습니다. | [4.6 비용 귀속](#visibility-findings) | 확인 불가 |
| [COST01-BP02 Establish a partnership between finance and technology](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_cloud_financial_management_partnership.html) | 재무·기술 담당자가 비용과 사용량을 정기적으로 논의합니다. | 협업 참여자·주기·의사결정 기록이 미확인입니다. | [4.6 비용 귀속](#visibility-findings) | 확인 불가 |
| [COST01-BP03 Establish cloud budgets and forecasts](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_cloud_financial_management_budget_forecast.html) | 수요와 추세에 맞춰 예산·예측을 수립하고 갱신합니다. | 예산 금액·기간·경보 조건과 비용 예측 자료가 미확인입니다. | [관측 설정](#observability) | 확인 불가 |
| [COST01-BP04 Implement cost awareness in your organizational processes](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_cloud_financial_management_cost_awareness.html) | 설계·변경·교육 과정에 비용 검토를 포함합니다. | 운영 기준에 자원 조절과 용량 상한은 있지만 변경별 비용 검토·교육 기록은 미확인입니다. | [4.6 비용 귀속](#visibility-findings) | 확인 불가 |
| [COST01-BP05 Report and notify on cost optimization](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_cloud_financial_management_usage_report.html) | 목표 대비 비용 성과를 정기 보고하고 이상을 알립니다. | 일일 이상 비용 구독은 있습니다. 목표 대비 성과 보고와 후속 조치 기록은 미확인입니다. | [관측 설정](#observability) | 확인 불가 |
| [COST01-BP06 Monitor cost proactively](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_cloud_financial_management_proactive_process.html) | 비용 도구를 활용해 선제적으로 관측하고 정기 분석합니다. | Cost Explorer와 이상 탐지는 사용합니다. 정기 분석·대응 기록이 미확인이라 선제적 관리의 이행 여부를 판단할 수 없습니다. | [4.6 비용 귀속](#visibility-findings) | 확인 불가 |
| [COST01-BP07 Keep up-to-date with new service releases](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_cloud_financial_management_scheduled.html) | 새 서비스·기능·가격 변화를 정기적으로 검토합니다. | 출시 정보 구독·전문가 상담·정기 검토 이력이 미확인입니다. | [4.6 비용 귀속](#visibility-findings) | 확인 불가 |
| [COST01-BP08 Create a cost-aware culture](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_cloud_financial_management_culture.html) | 교육·성과 공유·책임 부여로 비용 인식을 높입니다. | 교육·공유·책임 부여의 운영 자료가 미확인입니다. | [4.6 비용 귀속](#visibility-findings) | 확인 불가 |
| [COST01-BP09 Quantify business value from cost optimization](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_cloud_financial_management_quantify_value.html) | 최적화에 따른 절감과 업무 가치를 측정합니다. | 성공한 검색·시설 조회 등 업무 성과와 최적화 전후 비용을 연결하는 자료가 미확인입니다. | [4.6 비용 귀속](#visibility-findings) | 확인 불가 |

### 3.2 사용량 관리 — COST 2

[COST 2. How do you govern usage?](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost-02.html)

**질문 판정: 확인 불가.** 용량 상한과 이상 비용 알림은 적용됩니다. 사용 정책과 통제의 연계는 미확인입니다.

| 공식 BP·명칭 | 점검 기준 | 현재 상태·판정 사유 | 근거 | 판정 |
|---|---|---|---|---|
| [COST02-BP01 Develop policies based on your organization requirements](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_govern_usage_policies.html) | 자원 생성·변경·폐기에 적용할 사용 정책을 정합니다. | 용량 상한과 보존 설정은 있습니다. 비용 정책·예외·검토 절차는 미확인입니다. | [리소스 구성](#resources) | 확인 불가 |
| [COST02-BP02 Implement goals and targets](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_govern_usage_goal_target.html) | 측정 가능한 비용·사용량 목표와 달성 시점을 정합니다. | ASG와 RDS의 용량 상한은 있지만 비용 목표·달성 시점과의 연계는 미확인입니다. | [리소스 구성](#resources) | 확인 불가 |
| [COST02-BP03 Implement an account structure](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_govern_usage_account_structure.html) | 비용 귀속·운영 분리 요구에 맞게 계정을 구성합니다. | 비용 귀속·운영 분리 요구와 이를 반영한 설계 근거가 미확인입니다. | [4.6 비용 귀속](#visibility-findings) | 확인 불가 |
| [COST02-BP04 Implement groups and roles](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_govern_usage_groups_roles.html) | 사용 정책에 맞는 그룹·역할로 자원 사용 권한을 제어합니다. | API와 이미지 빌드 역할은 분리되어 있습니다. 사용 정책에 따른 사람의 권한 배정은 미확인입니다. | [리소스 구성](#resources) | 확인 불가 |
| [COST02-BP05 Implement cost controls](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_govern_usage_controls.html) | 사용 정책과 권한에 맞는 지출 알림·사용 한도를 적용합니다. | ASG·RDS 용량 상한과 이상 비용 구독은 있습니다. 예산·사용 정책과 통제의 대응 관계가 미확인입니다. | [관측 설정](#observability) | 확인 불가 |
| [COST02-BP06 Track project lifecycle](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_govern_usage_track_lifecycle.html) | 프로젝트 단계·소유권·종료와 비용을 함께 추적합니다. | 자원 생성·교체 기록은 있지만 프로젝트 단계·종료일·소유권을 연결한 기록은 미확인입니다. | [4.4 자원 수명·보존](#lifecycle-findings) | 확인 불가 |

### 3.3 비용과 사용량 관측 — COST 3

[COST 3. How do you monitor your cost and usage?](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost-03.html)

**질문 판정: 부분 충족.** 일별 비용과 운영 지표는 수집하지만 업무별 비용 분류와 상세 비용 자료는 부족합니다.

| 공식 BP·명칭 | 점검 기준 | 현재 상태·판정 사유 | 근거 | 판정 |
|---|---|---|---|---|
| [COST03-BP01 Configure detailed information sources](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_monitor_usage_detailed_source.html) | 상세 비용 정보와 업무 성과를 추적할 로그를 수집합니다. | 일별 비용과 API 관련 로그는 있습니다. 자원별 상세 비용 보고서가 없어 비용과 업무를 시간별로 연결하는 데 필요한 자료가 부족합니다. | [4.6 비용 귀속](#visibility-findings) | 부분 충족 |
| [COST03-BP02 Add organization information to cost and usage](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_monitor_usage_org_information.html) | 업무·환경·소유자 정보를 비용에 연결합니다. | 비용 할당 태그가 모두 비활성이고 Cost Categories도 없습니다. ASG·RDS 태그도 비어 있어 AWS 비용 데이터의 업무·소유자별 분류가 구현되지 않았습니다. | [4.6 비용 귀속](#visibility-findings) | 미충족 |
| [COST03-BP03 Identify cost attribution categories](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_monitor_usage_define_attribution.html) | 비용을 귀속할 업무·조직·공통 비용 범주를 정합니다. | AWS 비용 범주는 구성되지 않았으며 별도 장부의 분류 기준은 미확인입니다. | [4.6 비용 귀속](#visibility-findings) | 확인 불가 |
| [COST03-BP04 Establish organization metrics](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_monitor_usage_define_kpi.html) | 업무 성과를 나타내는 지표를 정의합니다. | 요청 지표는 있지만 성공한 검색·시설 조회의 정의와 실적은 미확인입니다. | [4.6 비용 귀속](#visibility-findings) | 확인 불가 |
| [COST03-BP05 Configure billing and cost management tools](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_monitor_usage_config_tools.html) | 비용을 분류·분석·계획·통지할 도구를 구성합니다. | Cost Explorer와 이상 탐지는 사용하지만 비용 태그·범주가 구성되지 않아 업무별 분류와 추적이 부족합니다. | [관측 설정](#observability) | 부분 충족 |
| [COST03-BP06 Allocate costs based on workload metrics](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_monitor_usage_allocate_outcome.html) | 업무 성과·사용량에 따라 비용을 배분합니다. | 업무 성공 지표와 비용 배분 규칙이 미확인입니다. | [4.6 비용 귀속](#visibility-findings) | 확인 불가 |

### 3.4 자원 폐기와 보존 — COST 4

[COST 4. How do you decommission resources?](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost-04.html)

**질문 판정: 부분 충족.** 이전 API는 자동 종료됐지만 교체 중 정상 처리 용량을 유지하지 못했습니다. 전체 추적·보존 요구는 미확인입니다.

| 공식 BP·명칭 | 점검 기준 | 현재 상태·판정 사유 | 근거 | 판정 |
|---|---|---|---|---|
| [COST04-BP01 Track resources over their lifetime](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_decomissioning_resources_track.html) | 자원의 기능·연결 관계를 생성부터 종료까지 추적합니다. | ASG 교체 이력과 AMI 참조 관계는 있습니다. 전체 자원의 수명 주기 추적 방식과 이행 기록은 미확인입니다. | [4.4 자원 수명·보존](#lifecycle-findings) | 확인 불가 |
| [COST04-BP02 Implement a decommissioning process](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_decomissioning_resources_implement_process.html) | 미사용 판단과 안전한 폐기 절차를 정합니다. | 자동 종료는 적용됩니다. 사용 확인·데이터 보존·책임자를 포함한 폐기 절차는 미확인입니다. | [4.4 자원 수명·보존](#lifecycle-findings) | 확인 불가 |
| [COST04-BP03 Decommission resources](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_decomissioning_resources_decommission.html) | 더 이상 필요하지 않은 자원을 폐기합니다. | API 교체 과정에서 이전 인스턴스 2대가 종료되어 사용이 끝난 실행 자원이 정리됐습니다. | [4.4 자원 수명·보존](#lifecycle-findings) | 충족 |
| [COST04-BP04 Decommission resources automatically](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_decomissioning_resources_decomm_automated.html) | 불필요한 자원을 자동 정리하며 종료 중 서비스 처리를 유지합니다. | ASG 교체·축소와 종료 시 EBS 삭제는 적용됩니다. 09-15 동시 교체 중 ALB 정상 대상이 0대가 되어 안전한 종료에 필요한 처리 용량은 유지되지 않았습니다. | [4.4 자원 수명·보존](#lifecycle-findings) | 부분 충족 |
| [COST04-BP05 Enforce data retention policies](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_decomissioning_resources_data_retention.html) | 업무 보존 요구에 맞는 데이터 만료 정책을 적용합니다. | 로그·사진 이전 버전·DB 백업에 보존 기간을 적용합니다. 전체 보존 요구와 불필요한 데이터의 판별 기준이 미확인이라 정책 적합성은 판단할 수 없습니다. | [4.4 자원 수명·보존](#lifecycle-findings) | 확인 불가 |

### 3.5 서비스 선택의 비용 평가 — COST 5

[COST 5. How do you evaluate cost when you select services?](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost-05.html)

**질문 판정: 확인 불가.** 현재 구성과 사용료는 있지만 대안·운영 노력·라이선스의 비교 근거는 부족합니다.

| 공식 BP·명칭 | 점검 기준 | 현재 상태·판정 사유 | 근거 | 판정 |
|---|---|---|---|---|
| [COST05-BP01 Identify organization requirements for cost](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_select_service_requirements.html) | 비용과 가용성·성능 요구의 우선순위를 정합니다. | 두 가용 영역을 유지하는 운영 기준은 있지만 허용 비용과 성능의 선택 기준은 미확인입니다. | [4.2 용량·수요](#capacity-findings) | 확인 불가 |
| [COST05-BP02 Analyze all components of the workload](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_select_service_analyze_all.html) | 모든 구성 요소의 비용을 효과에 비례해 분석합니다. | 주요 AWS 서비스 비용은 구분됩니다. 전체 구성의 비용 검토 기록과 DNS·외부 계약 비용은 미확인입니다. | [4.1 비용 구조](#billing-findings) | 확인 불가 |
| [COST05-BP03 Perform a thorough analysis of each component](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_select_service_thorough_analysis.html) | 자원 요금과 운영 노력을 포함해 구성별 대안을 비교합니다. | RDS·NAT·WAF 비용은 구분되지만 대안별 성능·관리 시간·전환 비용 비교는 미확인입니다. | [4.5 검사 비용·가격 모델](#pricing-findings) | 확인 불가 |
| [COST05-BP04 Select software with cost-effective licensing](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_select_service_licensing.html) | 필요 기능을 충족하는 비용 효율적인 라이선스를 선택합니다. | API는 Linux, RDS는 PostgreSQL을 사용합니다. 앱·지도·외부 계약의 라이선스 조건과 비교 기록은 미확인입니다. | [4.5 검사 비용·가격 모델](#pricing-findings) | 확인 불가 |
| [COST05-BP05 Select components of this workload to optimize cost in line with organization priorities](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_select_service_select_for_cost.html) | 운영 우선순위에 맞는 비용 효율적인 서비스를 선택합니다. | RDS·S3·CloudFront의 관리형 기능을 사용합니다. 선정 당시 비용과 운영 요구의 비교 근거는 미확인입니다. | [리소스 구성](#resources) | 확인 불가 |
| [COST05-BP06 Perform cost analysis for different usage over time](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_select_service_analyze_over_time.html) | 시간에 따른 사용량 변화와 서비스 비용을 분석합니다. | 구축·교체가 포함된 8일의 지표는 있습니다. 장기 수요 주기와 사용량 변화에 따른 비용 검토 기록은 미확인입니다. | [4.2 용량·수요](#capacity-findings) | 확인 불가 |

### 3.6 자원 유형·크기·수량 선정 — COST 6

[COST 6. How do you meet cost targets when you select resource type, size and number?](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost-06.html)

**질문 판정: 확인 불가.** 자동 용량 조절은 적용됩니다. 크기 선정과 비용 모델의 근거는 미확인입니다.

| 공식 BP·명칭 | 점검 기준 | 현재 상태·판정 사유 | 근거 | 판정 |
|---|---|---|---|---|
| [COST06-BP01 Perform cost modeling](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_type_size_number_resources_cost_modeling.html) | 부하별 자원 유형·크기·수량과 운영 비용을 모델링합니다. | 부하 시험과 구성 대안별 비용 모델이 미확인입니다. | [4.2 용량·수요](#capacity-findings) | 확인 불가 |
| [COST06-BP02 Select resource type, size, and number based on data](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_type_size_number_resources_data.html) | CPU·메모리·처리량 등 데이터로 자원을 선정합니다. | CPU는 낮지만 API 메모리·업무 성공률·피크 부하와 용량 선정 근거가 부족해 적정 크기는 판단할 수 없습니다. | [4.2 용량·수요](#capacity-findings) | 확인 불가 |
| [COST06-BP03 Select resource type, size, and number automatically based on metrics](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_type_size_number_resources_metrics.html) | 운영 지표에 따라 자원 수량·용량을 자동 조절합니다. | ASG는 CPU 목표 50%로 2~4대를 제어하고 RDS 저장 공간은 20~100GiB에서 자동 확장합니다. | [리소스 구성](#resources) | 충족 |
| [COST06-BP04 Consider using shared resources](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_type_size_number_resources_shared.html) | 공통 기능의 자원 공유와 비용 배분을 검토합니다. | ALB와 CloudFront가 여러 대상을 연결합니다. 다른 워크로드와의 공유 대안·비용 배분 검토는 미확인입니다. | [4.6 비용 귀속](#visibility-findings) | 확인 불가 |

### 3.7 가격 모델 적용 — COST 7

[COST 7. How do you use pricing models to reduce cost?](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost-07.html)

**질문 판정: 확인 불가.** 온디맨드를 사용합니다. 약정에 필요한 사용 기간·적정 용량과 비교 근거는 미확인입니다.

| 공식 BP·명칭 | 점검 기준 | 현재 상태·판정 사유 | 근거 | 판정 |
|---|---|---|---|---|
| [COST07-BP01 Perform pricing model analysis](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_pricing_model_analysis.html) | 사용 기간·변동성·중단 허용도에 맞는 가격 모델을 비교합니다. | 온디맨드를 사용하며 약정은 없습니다. 장기 사용 기간과 모델별 비교 자료가 미확인입니다. | [4.5 검사 비용·가격 모델](#pricing-findings) | 확인 불가 |
| [COST07-BP02 Choose Regions based on cost](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_pricing_model_region_cost.html) | 리전별 비용과 지연·데이터 요구를 함께 비교합니다. | 주요 자원은 서울에 있습니다. 리전별 총비용·응답 지연 비교 기록은 미확인입니다. | [리소스 구성](#resources) | 확인 불가 |
| [COST07-BP03 Select third-party agreements with cost-efficient terms](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_pricing_model_third_party.html) | 외부 계약의 비용과 제공 가치를 비교합니다. | 지도·도메인·애플리케이션 관련 외부 계약의 조건이 미확인입니다. | [4.5 검사 비용·가격 모델](#pricing-findings) | 확인 불가 |
| [COST07-BP04 Implement pricing models for all components of this workload](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_pricing_model_implement_models.html) | 구성 요소의 수명·중단 요구에 맞는 가격 모델을 적용합니다. | 실행 자원은 온디맨드로 청구됩니다. 계속 유지할 용량과 중단 허용도가 미확인이라 약정·Spot의 적합성은 판단할 수 없습니다. | [4.5 검사 비용·가격 모델](#pricing-findings) | 확인 불가 |
| [COST07-BP05 Perform pricing model analysis at the management account level](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_pricing_model_master_analysis.html) | 관리 계정에서 사용량과 약정을 통합해 가격 모델을 분석합니다. | 통합 구매·할인 공유를 운영하지 않아 관리 계정 단위 가격 분석은 적용 대상이 아닙니다. | [4.5 검사 비용·가격 모델](#pricing-findings) | 해당 없음 |

### 3.8 데이터 전송 비용 — COST 8

[COST 8. How do you plan for data transfer charges?](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost-08.html)

**질문 판정: 확인 불가.** CDN·캐시와 가용 영역별 경로를 사용합니다. 목적지별 전송 모델과 구성 선택 근거는 미확인입니다.

| 공식 BP·명칭 | 점검 기준 | 현재 상태·판정 사유 | 근거 | 판정 |
|---|---|---|---|---|
| [COST08-BP01 Perform data transfer modeling](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_data_transfer_modeling.html) | 출발지·목적지·전송량과 업무 가치에 따른 비용을 모델링합니다. | NAT·ALB·CloudFront 전송량은 있습니다. 목적지별 비용과 전송 비용 모델은 미확인입니다. | [4.3 전송 경로](#network-findings) | 확인 불가 |
| [COST08-BP02 Select components to optimize data transfer cost](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_data_transfer_optimized_components.html) | 전송 특성에 맞는 구성과 경로로 데이터 전송 비용을 줄입니다. | CDN과 같은 가용 영역의 NAT 경로를 사용합니다. 목적지별 전송 특성과 대안 비용이 미확인이라 추가 경로의 적합성은 판단할 수 없습니다. | [4.3 전송 경로](#network-findings) | 확인 불가 |
| [COST08-BP03 Implement services to reduce data transfer costs](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_data_transfer_implement_services.html) | CDN·캐시 등으로 전송과 원본 접근을 줄입니다. | CloudFront 캐시와 웹 압축이 적용됩니다. 응답 직전 Hit·Miss·RefreshHit 로그 중 Hit 비율은 74.94%로 캐시가 실제 활용됩니다. | [4.3 전송 경로](#network-findings) | 충족 |

### 3.9 수요와 자원 공급 — COST 9

[COST 9. How do you manage demand, and supply resources?](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost-09.html)

**질문 판정: 확인 불가.** API 동적 공급은 적용됩니다. 장기 수요 분석과 애플리케이션의 수요 관리 정책은 미확인입니다.

| 공식 BP·명칭 | 점검 기준 | 현재 상태·판정 사유 | 근거 | 판정 |
|---|---|---|---|---|
| [COST09-BP01 Perform an analysis on the workload demand](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_manage_demand_resources_cost_analysis.html) | 수요의 크기·변동·계절성과 응답 요구를 분석합니다. | 8일의 요청·사용률 지표는 있지만 장기 수요와 피크·업무 요구 분석은 미확인입니다. | [4.2 용량·수요](#capacity-findings) | 확인 불가 |
| [COST09-BP02 Implement a buffer or throttle to manage demand](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_manage_demand_resources_buffer_throttle.html) | 응답 요구에 맞는 버퍼나 속도 제한으로 수요를 관리합니다. | 웹 WAF는 Count이며 속도 제한 규칙은 없습니다. API·클라이언트의 버퍼·재시도·제한 정책은 미확인입니다. | [4.5 검사 비용·가격 모델](#pricing-findings) | 확인 불가 |
| [COST09-BP03 Supply resources dynamically](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_manage_demand_resources_dynamic.html) | 수요 또는 예측 가능한 시간에 맞춰 자원을 공급합니다. | CPU 목표 추적 정책이 API 수량을 조절하며 수요 감소 시 축소를 허용합니다. | [리소스 구성](#resources) | 충족 |

### 3.10 서비스의 정기 재검토 — COST 10

[COST 10. How do you evaluate new services?](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost-10.html)

**질문 판정: 확인 불가.** 정기 검토의 기준·주기와 실행 기록이 미확인입니다.

| 공식 BP·명칭 | 점검 기준 | 현재 상태·판정 사유 | 근거 | 판정 |
|---|---|---|---|---|
| [COST10-BP01 Develop a workload review process](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_evaluate_new_services_review_process.html) | 효과·비용에 비례한 정기 검토 주기와 기준을 정합니다. | 비용 검토의 담당자·주기·범위·평가 기준이 미확인입니다. | [4.6 비용 귀속](#visibility-findings) | 확인 불가 |
| [COST10-BP02 Review and analyze this workload regularly](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_evaluate_new_services_review_workload.html) | 정해진 절차에 따라 재검토하고 변경 효과를 확인합니다. | 정기 검토 결과와 조치 전후 단위 비용 자료가 미확인입니다. | [4.6 비용 귀속](#visibility-findings) | 확인 불가 |

### 3.11 운영 노력의 비용 — COST 11

[COST 11. How do you evaluate the cost of effort?](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost-11.html)

**질문 판정: 부분 충족.** 반복 작업은 자동화되어 있지만 서비스 경보의 운영자 통지가 빠져 있습니다.

| 공식 BP·명칭 | 점검 기준 | 현재 상태·판정 사유 | 근거 | 판정 |
|---|---|---|---|---|
| [COST11-BP01 Perform automation for operations](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_evaluate_cost_effort_automations_operations.html) | 운영 노력의 비용을 평가하고 반복 작업을 자동화합니다. | 이미지 생성·교체·백업·보존은 자동화되어 있습니다. 서비스 경보의 운영자 통지는 구성되지 않았으며 운영 시간·비용 측정은 미확인입니다. | [자동화](#lifecycle-findings), [경보 설정](#observability) | 부분 충족 |

<a id="findings"></a>

## 4. Findings and Insights(발견 사항 및 인사이트)

<a id="billing-findings"></a>

### 4.1 RDS·NAT 유지 비용 중심의 지출 구조

Cost Explorer의 **KST 2026-09-14 09:00 이상~09-21 09:00 미만** 운영 사용료는 **79.02달러**입니다. RDS와 NAT를 계속 유지하는 비용이 가장 큰 비중을 차지합니다.

> **비용 기간 제약**: 시간 단위 자료가 없어 공통 집계 기간 8일의 비용은 미확정입니다. 아래 7일 비용은 아직 확정되지 않은 청구 추정값입니다.

| 서비스 | 운영 사용료(USD) | 비중 |
|---|---:|---:|
| RDS | 35.33 | 44.71% |
| EC2 기타 — NAT·EBS 등 | 20.90 | 26.45% |
| EC2 실행 | 8.75 | 11.07% |
| WAF | 6.06 | 7.67% |
| ALB | 3.78 | 4.79% |
| VPC — 공인 IPv4 등 | 3.36 | 4.26% |
| S3 | 0.75 | 0.95% |
| Secrets Manager | 0.08 | 0.11% |
| **합계** | **79.02** | **100%** |

같은 기간 CloudFront·CloudWatch의 사용료는 0달러입니다. 주요 과금 원인은 다음과 같습니다.

| 과금 대상 | 비용(USD) | 비용이 발생하는 이유 |
|---|---:|---|
| RDS Multi-AZ 실행 | 34.10 | 주·대기 구성을 168시간 유지했습니다. |
| RDS 저장 공간 | 1.22 | 할당한 gp3 용량을 보관합니다. |
| NAT 유지 | 19.82 | 두 NAT의 유지 시간이 합계 336시간입니다. |
| NAT 데이터 처리 | 0.09 | 청구상 처리량은 1.56GB입니다. |
| EC2 실행 | 8.75 | `t3.small` 인스턴스의 실행 시간에 따른 비용입니다. |
| ALB 유지 | 3.78 | 요청 진입점을 168시간 유지했습니다. |
| 사용 중인 공인 IPv4 | 3.36 | NAT·ALB의 외부 연결 주소를 유지합니다. |
| EBS gp3·스냅샷 | 0.98 | API 볼륨과 이미지 스냅샷을 보관합니다. |
| S3 Standard 저장 | 0.75 | 콘텐츠·배포 파일·로그를 보관합니다. |

**RDS 전체와 NAT 유지 비용이 운영 사용료의 69.79%**입니다. NAT 처리료는 NAT 유지·처리료 합계의 0.46%여서 전송량을 줄이는 것만으로는 지출 변화가 작습니다.

RDS와 NAT의 이중화는 [두 가용 영역을 유지하는 운영 기준](../../README.md#4-operational-criteria-and-constraints운영-기준-및-제약)에 대응합니다. 우선 DB의 실제 사용 경로와 필요한 크기, NAT의 필수 외부 연결을 검토해야 합니다. 필요한 처리량과 장애 대응 능력을 유지하면서 자원 크기·경로를 조정하는 것이 비용 감소의 핵심입니다.

관련 기준: **COST05-BP02·BP03·BP06, COST06-BP01·BP02, COST08-BP01·BP02**.

<a id="capacity-findings"></a>

### 4.2 낮은 API·DB 사용률과 용량 선정의 제약

API 평균 CPU는 **1% 미만**, RDS는 **5.23%**였습니다. CloudWatch의 시간별 CPU 지표에서 평균은 표본 가중 평균, 최대는 관측 최댓값입니다.

| 대상 | 평균 CPU | 최대 CPU | 관측 시간대(KST) |
|---|---:|---:|---|
| 교체 전 API 두 대 | 0.40~0.43% | 6.72~11.86% | 09-14 01시~09-15 01시 |
| 현재 API 2a | 0.56% | 4.70% | 09-15 01시~09-21 23시 |
| 현재 API 2c | 0.64% | 15.67% | 09-15 01시~09-21 23시 |
| RDS `arcamap-postgres` | 5.23% | 29.34% | 09-14 00시~09-21 23시 |

API 인스턴스의 교체 시각과 연결 관계는 [배포 기록](01-operational-excellence.md#41-api-배포의-정상-처리-용량-공백)에 있습니다. 같은 기간의 용량·요청 지표는 다음과 같습니다.

| 대상·지표 | 관측값 | 관측 범위(KST) |
|---|---|---|
| RDS 가용 메모리·저장 공간 | 최소 2.82GiB·17.06GiB | 공통 기간 |
| RDS 연결 수 | 평균·최소·최대 모두 0 | 공통 기간 |
| RDS 초당 입출력 횟수(IOPS) | 읽기 평균 0.27·최대 12.23, 쓰기 평균 1.97·최대 62.33 | 공통 기간 |
| ASG 희망·운영 용량 | 두 지표 모두 최소·최대 2대 | 09-14 18시~09-21 23시 |
| ALB 요청·처리량 | 합계 7,616건·10.69MiB | 09-14 01시~09-21 23시 |
| ALB 대상 응답 시간 | 표본 가중 평균 5.72ms·최대 175.95ms | 09-14 22시~09-21 23시 |

ASG는 낮은 CPU에서도 최소 용량 2대를 유지했습니다. RDS 연결 수는 측정값이 0이지만, [DB 업무 연결](04-performance-efficiency.md#43-rds-자원-사용과-미확인-업무-연결)을 설명할 실제 쿼리·업무 성공 기록은 부족합니다.

> **용량 판단 제약**: 구축·교체가 포함된 8일의 사용률이며 API 메모리와 장기 피크 수요는 미확인입니다. 적정 인스턴스 크기와 축소 후 처리 능력을 확정하기 어렵습니다. ASG 용량 지표는 09-14 18시부터 있어 초기 용량의 관측 범위도 제한됩니다.

현재는 DB의 업무 사용 경로와 API 메모리를 우선 파악해 인스턴스 크기를 검토하는 것이 적절합니다. 크기 조정 후에도 정상 요청의 응답 시간·성공률과 장애 시 필요한 용량을 유지해야 합니다. 초기 ALB 오류 307건과 배포 중 처리 용량 소실은 [초기 운영 기록](01-operational-excellence.md#44-초기-api-준비-지연과-alb-오류)과 [교체 중 가용성](03-reliability.md#41-api-동시-교체로-정상-대상이-없어진-구간)에 연결됩니다.

관련 기준: **COST03-BP04·BP06, COST06-BP01~BP03, COST09-BP01·BP03**.

<a id="network-findings"></a>

### 4.3 NAT 전송 경로와 CloudFront 캐시 활용

API의 외부 통신은 같은 가용 영역의 NAT를 통과합니다. 공통 기간 CloudWatch의 NAT별 유입 바이트 합계는 다음과 같습니다.

| NAT 위치 | 내부 자원에서 유입 | 외부 목적지에서 유입 |
|---|---:|---:|
| API 2a의 NAT | 253.59MiB | 1,117.26MiB |
| API 2c의 NAT | 250.22MiB | 433.98MiB |

CloudFront `E39UQTOCMBVZB3`의 요청은 **14,181건**, 다운로드는 **340.94MiB**였습니다. 지표가 있는 시간대는 KST 09-14 01시~09-21 23시입니다.

[CloudFront 접근 로그](04-performance-efficiency.md#45-cloudfront-캐시-결과와-콘텐츠별-응답-성능)의 응답 직전 분류는 Hit 4,068건·Miss 744건·RefreshHit 616건입니다. 이 세 분류 **5,428건 중 Hit 비율은 74.94%**로, 캐시에서 콘텐츠를 제공한 기록이 있습니다. RefreshHit는 원본에 최신 여부를 재확인한 응답입니다.

> **전송 비용 판단 제약**: NAT의 목적지별 비용과 캐시로 회피한 비용은 미확인입니다. 74.94%는 지정 로그 분류의 Hit 비율이며 CloudWatch `CacheHitRate`가 아닙니다.

현재 웹·지도·사진 캐시와 웹 압축은 원본 접근과 전송을 줄이는 기능입니다. S3로 향하는 NAT 트래픽이 확인되면 Gateway Endpoint를 통한 처리료 감소를 검토할 수 있습니다. **NAT를 계속 운영하는 동안 유지 시간료는 발생**하므로 경로 변경 효과는 [유지 비용과 처리료](#billing-findings)를 나누어 판단해야 합니다.

캐시는 실제 콘텐츠 갱신 주기에 맞춰 조정해야 합니다. 홈 HTML의 재검증과 정적 자산의 재사용 조건을 구분하면 원본 접근을 줄일 여지가 있으며, 지도 범위 요청과 콘텐츠 최신성을 유지해야 합니다.

관련 기준: **COST08-BP01~BP03**.

<a id="lifecycle-findings"></a>

### 4.4 자동 자원 정리와 배포 중 처리 용량 소실

ASG `arcamap-api`는 새 이미지로 API를 교체하고 이전 인스턴스를 종료했습니다. 공통 기간의 ASG·RDS 기록에는 초기 구축과 후속 교체가 포함됩니다.

| 시각(KST) | 운영 사건 | 비용·서비스 영향 |
|---|---|---|
| 09-14 00:45:25 | RDS 생성 이벤트가 기록됐습니다. | DB 운영이 시작된 시점입니다. |
| 09-14 00:46:36~00:54:18 | Multi-AZ 전환이 적용·완료됐습니다. | 주·대기 인스턴스 유지 구성이 마련됐습니다. |
| 09-14 01:51:22~01:52:21 | API 시작 시도 3건이 역할 사용 거부로 실패했습니다. | 초기 자원 확보가 지연됐습니다. [초기 API 기록](01-operational-excellence.md#44-초기-api-준비-지연과-alb-오류) |
| 09-14 01:57:27·01:59:25 | 후속 API 두 대의 시작 활동이 완료됐습니다. | API 실행 자원이 확보됐습니다. |
| 09-15 01:33:47~01:39:33 | 새 이미지의 Instance Refresh가 실행됐습니다. | 이전 두 대는 01:39:09·01:39:29에 종료됐습니다. |
| 09-15 01:34·01:35 | ALB 정상 대상의 1분 최솟값이 0대였습니다. | 자동 교체 중 정상 처리 용량이 유지되지 않았습니다. [가용성 기록](03-reliability.md#41-api-동시-교체로-정상-대상이-없어진-구간) |

이전 API 종료와 EBS 자동 삭제는 불필요한 실행·저장 비용의 누적을 막습니다. 다만 현재 [교체 정책](../../terraform/modules/compute/main.tf#L66)은 기존 두 대를 함께 제외하므로 새 대상이 준비될 때까지 요청을 처리할 용량이 부족해질 수 있습니다. **자동 정리와 함께 정상 처리 용량을 유지하는 교체 순서가 필요합니다.**

현재 API용 EBS와 NAT·ALB의 공인 IPv4는 모두 연결되어 있습니다. 자체 AMI `ami-0ea0a69370cebb271`와 연결 스냅샷은 현재 API가 사용합니다. 미연결 EBS·주소나 참조가 끊긴 자체 이미지 스냅샷은 없습니다.

RDS는 자동 백업을 3일 보존하며 KST 09-18~09-21의 자동 스냅샷이 남아 있습니다. 백업 실행과 복원 가능 범위는 [RDS 백업 기록](03-reliability.md#43-rds-자동-백업의-복원-범위와-미검증된-복구-목표)에 있습니다.

| 저장 대상 | 일별 평균 저장량·객체 수 | 보존·비용 판단 |
|---|---|---|
| 지도 원본 | 09-14~09-21, 128.37GiB·1개 | CloudFront가 사용하는 지도 원본입니다. |
| 웹 원본 | 09-15~09-21, 16.09MiB·22개 | 서비스의 정적 콘텐츠입니다. |
| API 배포 | 09-15~09-21, 11.47KiB·1개 | 배포 파일이 대량 누적된 상태는 아닙니다. |
| CloudFront 로그 | 09-21 기준 1.70MiB·1,067개 | 30일 후 만료되는 접근 기록입니다. |
| 사진 | 일별 저장량·객체 수 지표 없음 | [9월 22일 객체 상태](06-sustainability.md#43-보존-정책과-현재-데이터의-필요성을-함께-판단해야-합니다)에는 객체·이전 버전·삭제 마커가 없습니다. |

저장량은 [역할별 S3](#resources)의 CloudWatch 저장량·객체 수 지표입니다. 웹·배포 버킷은 09-14 지표가 없어 해당 날짜의 보관 규모는 미확인입니다.

로그와 사진 이전 버전에는 만료가 적용되지만 이미지·배포 아카이브에는 자동 만료 정책이 없습니다. 이미지는 현재 API가 사용하고 배포 파일도 1개이므로, 정리 자동화의 효과는 보관할 롤백 이력과 삭제 가능한 자산을 정한 뒤 판단해야 합니다.

> **보존 판단 제약**: 전체 데이터의 업무 보존 요구와 삭제 가능 기준이 미확인입니다. 사용 중인 원본·운영 이미지·복구용 백업의 적정 보존 기간을 확정하기 어렵습니다.

관련 기준: **COST02-BP06, COST04-BP01~BP05, COST05-BP06, COST11-BP01**.

<a id="pricing-findings"></a>

### 4.5 WAF 검사 비용과 가격 모델의 선택 조건

[7일 비용 기간](#billing-findings)의 WAF 사용료는 **6.06달러**입니다. 이 중 Anti-DDoS 기능 유지료가 **4.18달러로 68.90%**를 차지합니다.

| WAF 비용 항목 | 비용(USD) |
|---|---:|
| Anti-DDoS 기능 유지 | 4.18 |
| Web ACL 유지 | 1.04 |
| 규칙 유지 | 0.84 |

[WAF 운영 기록](02-security.md#sec-f01)에 따르면 KST 09-15 02:37에 Web ACL이 생성되고 CloudFront에 연결됐습니다. 규칙은 생성 때부터 Count로 지정됐으며, 공통 기간 로그 **8,891건의 최종 동작은 모두 ALLOW**였습니다. 현재 비용은 검사와 기록을 유지하는 데 쓰이고 있습니다. API는 이 WAF를 거치지 않고 별도 ALB로 연결됩니다.

유료 검사의 적절성은 탐지 결과를 운영 대응에 얼마나 활용하는지에 달려 있습니다. 규칙별 탐지·오탐과 대응 기록을 연결해 유지 범위를 정하면 검사 비용의 가치를 평가할 수 있습니다. 차단 전환을 검토할 때는 정상 요청의 가용성과 되돌림 조건을 함께 유지해야 합니다.

EC2·RDS는 온디맨드를 사용하며 Savings Plans·예약 인스턴스와 ASG의 Spot 혼합 정책은 없습니다. 약정은 계속 유지할 용량과 사용 기간이 정해져야 비교할 수 있습니다. 현재 크기를 조정할 여지가 있으므로 **용량 선정이 약정 검토보다 먼저**입니다.

> **가격 판단 제약**: 장기 사용 기간·중단 허용도와 대안별 운영 노력은 미확인입니다. 외부 소프트웨어·지도·도메인의 계약·라이선스 조건도 없어 약정과 전체 계약 비용의 적합성을 판단하기 어렵습니다.

관련 기준: **COST05-BP03~BP05, COST07-BP01~BP05, COST09-BP02**.

<a id="visibility-findings"></a>

### 4.6 업무별 비용 귀속과 성과 지표의 공백

**비용 할당 태그가 모두 비활성**이고 Cost Categories도 없습니다. ASG·RDS의 태그도 비어 있어 업무·환경·소유자별 비용이 구분되지 않습니다. 상세 비용 보고서가 없으므로 배포·운영 사건과 자원별 비용을 시간 단위로 연결하기도 어렵습니다.

[시스템 로그의 API 기록](01-operational-excellence.md#43-시스템-로그와-api-기록-수집)에는 `arcamap-api` 또는 `uvicorn` 문자열을 포함한 이벤트 **88,710건**이 있습니다. 현재·이전 API 인스턴스와 빌드 시간대의 기록이 포함됩니다. API 전용 그룹은 비어 있지만 [journald 수집 경로](../../terraform/env/was/main.tf#L44)를 통해 API 관련 기록이 남습니다.

> **업무 성과 제약**: 성공한 검색·시설 조회의 정의와 로그 필드가 미확인입니다. API 관련 메시지 수만으로 업무 성공 건수와 단위 비용을 계산하기 어렵습니다.

비용 관리에는 일일 이상 탐지 구독이 있습니다. 다만 예산 금액·예측·비용 책임자·정기 검토·최적화 성과 보고의 운영 자료는 미확인입니다. 목표 예산과 허용 편차가 없어 현재 알림 임계값의 적절성도 판단하기 어렵습니다.

개선의 우선순위는 **업무·환경·소유자의 비용 구분과 핵심 업무 성공 지표를 연결하는 것**입니다. 기존 시스템 로그에서 필요한 요청·결과를 구분하고 비용 태그와 상세 비용 자료를 연결하면 같은 업무 성과에 드는 비용을 비교할 수 있습니다. 운영자가 의사결정에 사용하는 범위로 구성해 관리 부담을 줄이는 것이 적절합니다.

관련 기준: **COST01-BP01~BP09, COST03-BP01~BP06, COST06-BP04, COST10-BP01·BP02**.

<a id="conclusion"></a>

## 5. Conclusion(결론)

**ArcaMap은 자원 수량 조절·캐시·자동 정리를 사용하지만, 비용은 RDS·NAT의 유지 비용에 집중됩니다.** 우선 현재 업무에 필요한 DB·API 용량을 검토하고 비용을 업무 성과와 연결해야 합니다.

- 💰 **자원 용량** — 낮은 CPU와 DB 연결 수는 용량 검토의 근거입니다. 실제 DB 사용 경로·API 메모리·피크 수요를 파악하고 장애 시 필요한 처리 능력을 유지해야 합니다.

- 🌐 **전송·검사 비용** — CloudFront 캐시는 실제 요청을 처리합니다. NAT의 필수 외부 연결과 WAF 탐지 결과의 운영 가치를 기준으로 유지 범위를 정해야 합니다.

- 💾 **자원 수명 주기** — 이전 API는 자동 종료됐지만 배포 중 정상 처리 용량이 사라졌습니다. 서비스 연속성을 유지하는 교체 순서와 업무 보존 요구에 맞는 정리 기준이 필요합니다.

- 📈 **비용과 업무의 연결** — 비용 태그·상세 비용 자료와 업무 성공 지표를 연결하면 변경 전후 효율을 비교할 수 있습니다. 예산·정기 검토와 외부 계약 자료가 부족해 관리 체계와 전체 비용의 적합성은 미확인입니다.
