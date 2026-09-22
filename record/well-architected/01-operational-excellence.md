# Operational Excellence(운영 우수성)

**⚙️ 이미지로 API를 배포하고, 로그·지표로 서비스 상태를 파악하는 운영 구성**

ArcaMap은 세계의 저장소·보존 시설을 지도에서 탐색하는 서비스입니다. CloudFront와 S3가 웹·지도·사진을 제공하고, ALB를 거친 API가 RDS PostgreSQL의 데이터를 조회합니다. Image Builder와 Auto Scaling Group(ASG)이 API 이미지 생성과 인스턴스 교체·용량 조절을 맡으며, CloudWatch와 S3에 운영 기록을 모읍니다.

**공통 집계 기간**은 KST **2026-09-14 00:00 이상~2026-09-22 00:00 미만**, **구성 확인 시점**은 KST **2026-09-22 15:41~15:56**입니다. 본문의 시각은 KST입니다.

[현재 운영 현황](#1-current-operations현재-운영-현황) · [기둥 원칙](#2-pillar-principles기둥의-원칙에-따른-검토) · [질문·모범 사례](#3-questions-and-best-practices질문-및-모범-사례별-상세-점검) · [발견 사항](#4-findings-and-insights발견-사항-및-인사이트) · [결론](#5-conclusion결론)

## 1. Current Operations(현재 운영 현황)

API·RDS·주요 로그는 **서울**에 있습니다. CloudFront가 전 세계에 콘텐츠를 제공하며, 연결된 WAF와 CloudFront 로그 전달 설정은 **버지니아 북부**에서 관리합니다.

### 1.1 리소스 구성

| 운영 대상 | 역할·구성 | Terraform 정의 |
|---|---|---|
| API 진입점 | ALB `arcamap-api`가 두 가용 영역의 API 서버로 요청을 분산합니다. HTTP는 HTTPS로 전환하고, HTTPS 요청은 내부 HTTP 8080으로 전달합니다. | [ALB·대상 그룹](../../terraform/modules/alb/main.tf#L1), [리스너](../../terraform/modules/alb/main.tf#L38) |
| API 실행·용량 | ASG `arcamap-api`는 `t3.small` 2대를 운영하며 최대 4대까지 늘어납니다. 평균 CPU 50%를 목표로 용량을 조절하고 ELB 상태 검사로 비정상 인스턴스를 감지합니다. 상태 검사 유예와 워밍업은 각각 5분입니다. | [ASG](../../terraform/modules/compute/main.tf#L44), [CPU 정책](../../terraform/modules/compute/main.tf#L81) |
| 이미지 배포 | Image Builder `arcamap-api`의 이미지 1.1.2/1은 사용 가능한 상태이며, 생성된 AMI가 시작 템플릿 v2에 연결됩니다. 이미지 테스트에는 Agent 작동·시스템 로그 전달·FastAPI 기동·DB 연결 검사가 포함됩니다. | [이미지·레시피](../../terraform/modules/image-builder/main.tf#L195), [API 테스트](../../terraform/modules/image-builder/fastapi.tf#L95), [시작 템플릿](../../terraform/modules/compute/main.tf#L1) |
| 데이터베이스 | RDS `arcamap-postgres`는 PostgreSQL 17.11·`db.t4g.medium`을 사용합니다. Multi-AZ, 자동 백업 3일, 삭제 보호를 설정하고 저장 공간은 20 GiB에서 최대 100 GiB까지 확장합니다. | [RDS](../../terraform/modules/database/main.tf#L6), [DB 연결](../../terraform/env/db/main.tf#L72) |
| 통신·운영 접속 | 보안 그룹이 ALB → API의 8080 포트, API → DB의 5432 포트를 허용합니다. API 두 대는 Systems Manager에 연결되어 있으며, SSH 포트를 열지 않고 Session Manager로 접속합니다. | [보안 그룹](../../terraform/modules/security/main.tf#L1), [운영 역할](../../terraform/env/was/iam.tf) |
| 웹·지도·사진 | `arcamap.app`의 CloudFront가 S3 오리진 3개를 연결합니다. OAC가 오리진 접근을 제한하며 WAF의 관리형 규칙 4개는 Count 모드로 요청을 검사합니다. | [CloudFront](../../terraform/modules/cloudfront/main.tf#L60), [콘텐츠 버킷](../../terraform/env/web/main.tf#L14), [WAF](../../terraform/modules/cloudfront/waf.tf#L29) |

API 배포는 **S3 배포 객체 → Image Builder AMI → 시작 템플릿 → ASG Instance Refresh** 순서로 진행됩니다. 새 이미지를 반영하면 ASG가 인스턴스를 교체하며, 실제 교체 중 처리 용량의 변화는 [배포 기록](#41-api-배포의-정상-처리-용량-공백)에 있습니다.

### 1.2 옵저빌리티 구성

CloudWatch는 로그·지표로 API 처리 용량, 정상 대상 수, 서버 오류와 DB 자원 부족을 감지합니다. ALB는 `/health`의 HTTP 200 응답을 30초마다 검사하며, 이미지 테스트는 `/health/db`로 DB 연결도 점검합니다.

| 관측 대상 | 도구·감지 구성 | 운영 상태 |
|---|---|---|
| API 처리 용량 | ASG 인스턴스 수와 CPU 지표, 목표 추적 경보 | CPU 목표 추적 경보 2개가 인스턴스 확장·축소 정책을 실행합니다. |
| API 응답·서버 상태 | ALB 정상 대상·5xx, EC2 상태 검사·CPU 경보 | 서비스 경보가 이상 상태를 표시합니다. |
| 시스템·애플리케이션 | CloudWatch Agent의 journald 수집 | API 관련 기록은 시스템 로그 그룹에 모이며 전용 API 그룹에는 스트림이 없습니다. |
| DB | RDS 기본 지표, PostgreSQL 로그, CPU·메모리·저장 공간 경보 | Enhanced Monitoring과 Performance Insights는 꺼져 있습니다. |
| 콘텐츠·웹 위협 | CloudFront 접근 로그와 WAF 로그·지표 | 콘텐츠 요청은 S3에, WAF 판정은 CloudWatch Logs에 저장합니다. |
| 경보 전달·현황판 | 서비스 경보 9개, CloudWatch 대시보드 | 서비스 경보의 알림 동작은 꺼져 있으며 대시보드는 없습니다. |
| 사용자 경험·앱 자원 | RUM·Synthetics·CWAgent 사용자 지표 | 해당 수집 설정은 없고 외부 계측 여부는 미확인입니다. |

서비스 경보의 주요 조건은 다음과 같습니다. HTTP 5xx는 서버 오류 응답이며 ALB 자체 오류와 API 대상 오류를 따로 감지합니다.

| 경보 | 감지 조건 |
|---|---|
| `arcamap-asg-inservice` | 서비스 중인 인스턴스 수의 1분 최솟값 **2대 미만**, 최근 3회 중 2회 |
| `arcamap-ec2-status-check` | EC2 상태 검사 실패의 1분 최댓값 **1 이상**, 최근 3회 중 2회 |
| `arcamap-ec2-cpu` | CPU의 5분 평균 **80% 이상**, 3회 연속 |
| `arcamap-alb-healthy-hosts` | 정상 대상 수의 1분 최솟값 **2대 미만**, 최근 3회 중 2회 |
| `arcamap-alb-5xx`·`arcamap-api-5xx` | 각각의 5분 오류 합계 **5건 이상** |
| `arcamap-rds-cpu` | CPU의 5분 평균 **80% 이상**, 3회 연속 |
| `arcamap-rds-free-memory` | 가용 메모리의 5분 최솟값 **512 MiB 미만**, 3회 연속 |
| `arcamap-rds-free-storage` | 가용 저장 공간의 5분 최솟값 **5 GiB 미만** |

경보 정의는 [API 경보](../../terraform/env/was/main.tf#L59), [DB 경보](../../terraform/env/db/main.tf#L19), [공통 경보 모듈](../../terraform/modules/cloudwatch-alarm/main.tf#L1)에 있습니다. 실제 감지와 전달 상태는 [경보 이력](#42-서비스-경보의-감지와-전달)에 연결됩니다.

> **운영 목표의 제약**: 검색 성공률·응답 시간·가용성의 목표와 서비스 수준 목표(SLO)에 대한 합의 자료가 없어, 자원 임계값이 이용자 요구에 적합한지 판단하기 어렵습니다.

### 1.3 텔레메트리 수집 현황

| 기록 | 수집 위치·대상 | 보존 |
|---|---|---|
| 시스템·API | 서울 `/arcamap/ec2/system`의 인스턴스별 스트림에 시스템·API 관련 기록을 저장합니다. | 30일 |
| ALB | 서울 `/aws/vendedlogs/elb/arcamap-api`에 접근·연결·헬스 체크 로그를 전달합니다. | 30일 |
| 이미지 빌드 | 서울 `/aws/imagebuilder/arcamap-api`의 버전별 스트림에 빌드·테스트 기록을 저장합니다. | 30일 |
| DB | 서울 `/aws/rds/instance/arcamap-postgres/postgresql`에 DB 기록을 저장합니다. upgrade 그룹에는 스트림이 없습니다. | 30일 |
| WAF | 버지니아 북부 `aws-waf-logs-CloudFrontDistribution-E39UQTOCMBVZB3`에 요청 판정을 저장하며 인증·쿠키 헤더를 가립니다. | 14일 |
| CloudFront | [CloudFront 로그 버킷](../../terraform/env/web/main.tf#L26)에 접근 로그를 저장합니다. | 30일 |
| 지표·운영 이벤트 | CloudWatch의 ALB·ASG·EC2·RDS 지표와 경보 이력, ASG 활동·인스턴스 교체 이력입니다. | 배포·경보·초기 운영 기록은 4번에 있습니다. |

로그 정의는 [API·ALB·시스템·빌드 그룹](../../terraform/env/was/main.tf#L135), [DB 그룹](../../terraform/env/db/main.tf#L61), [ALB 전달](../../terraform/modules/alb/main.tf#L72), [WAF 전달](../../terraform/modules/cloudfront/waf.tf#L1)에 있습니다. 분산 추적의 관측 결과와 자료 제약은 [4.6](#46-운영-절차와-개선-판단의-자료-제약)에 있습니다.

## 2. [Pillar Principles(기둥의 원칙에 따른 검토)](https://docs.aws.amazon.com/wellarchitected/latest/framework/operational-excellence.html)

운영 우수성은 서비스를 개발·실행·관측하여 사업 가치를 제공하고 지원 절차를 지속적으로 개선하는 능력입니다. AWS의 공식 정의는 조직·준비·운영·발전의 네 영역을 다룹니다.

| [공식 설계 원칙](https://docs.aws.amazon.com/wellarchitected/latest/framework/oe-design-principles.html) | ArcaMap의 운영 |
|---|---|
| Organize teams around business outcomes | 시설 탐색이라는 서비스 목적은 명확합니다. 운영 책임과 검색 성공·응답 시간 등 성과 목표의 합의 자료는 부족합니다. |
| Implement observability for actionable insights | ALB·앱·DB·콘텐츠 기록이 수집되지만 [서비스 경보](#42-서비스-경보의-감지와-전달)가 운영자에게 전달되지 않습니다. |
| Safely automate where possible | 이미지 생성·인스턴스 교체·용량 조절은 자동화되어 있습니다. [교체 중 정상 용량 유지](#41-api-배포의-정상-처리-용량-공백)가 부족합니다. |
| Make frequent, small, reversible changes | 이미지와 시작 템플릿의 버전을 관리하지만 실제 교체는 두 인스턴스에 동시에 영향을 주었습니다. |
| Refine operations procedures frequently | 구성·배포 설명은 저장소에 있습니다. 런북의 사용·갱신 이력이 없어 절차 개선 여부는 미확인입니다. |
| Anticipate failure | Multi-AZ·상태 검사·이미지 테스트를 사용합니다. [초기 준비 지연](#44-초기-api-준비-지연과-alb-오류)에 대비한 서비스 준비·복구 조건을 구체화할 필요가 있습니다. |
| Learn from all operational events and metrics | 사건을 분석할 로그·지표는 있으나 [사후 분석과 개선 반영 기록](#46-운영-절차와-개선-판단의-자료-제약)은 부족합니다. |
| Use managed services | CloudFront·S3·RDS·Image Builder·CloudWatch가 콘텐츠 전달·저장·DB·이미지·관측 작업을 맡습니다. |

## 3. [Questions and Best Practices(질문 및 모범 사례별 상세 점검)](https://docs.aws.amazon.com/wellarchitected/latest/framework/a-operational-excellence.html)

공식 기준은 **OPS01~OPS11의 11개 질문·68개 모범 사례(BP)**입니다. 판정은 **충족 0·부분 충족 6·미충족 1·해당 없음 0·확인 불가 61개**입니다.

### 3.1 OPS01 — 우선순위 결정

**공식 질문**: [OPS 1. How do you determine what your priorities are?](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops-01.html)

| 공식 BP·명칭·원문 | 점검 기준 | 실제 현재 상태 | 확인 근거 | 판정 | 판정 사유 |
|---|---|---|---|---|---|
| [OPS01-BP01 Evaluate external customer needs](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_priorities_ext_cust_needs.html) | 외부 이용자의 요구를 운영 우선순위에 반영합니다. | 시설 탐색 서비스를 제공하지만 이용자 요구 수집·우선순위 결정 기록은 없습니다. | [서비스 설명](../../README.md) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 운영 우선순위에 이용자 요구가 반영되는지 미확인입니다. |
| [OPS01-BP02 Evaluate internal customer needs](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_priorities_int_cust_needs.html) | 내부 이용자·운영자의 요구를 평가합니다. | 인프라는 app·db·was·web으로 나뉘며 운영자 요구·합의 자료는 없습니다. | [Terraform 운영 구조](../../terraform/README.md) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 내부 이용자 요구의 평가·반영 여부는 미확인입니다. |
| [OPS01-BP03 Evaluate governance requirements](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_priorities_governance_reqs.html) | 의사결정에 적용할 거버넌스 요구를 검토합니다. | 변경 승인 권한·정책·예외 승인 기록이 없습니다. | [서비스 설명](../../README.md) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 운영 의사결정에 적용할 규칙을 확인할 근거가 부족합니다. |
| [OPS01-BP04 Evaluate compliance requirements](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_priorities_compliance_reqs.html) | 적용되는 준수 요구와 통제를 식별합니다. | 적용되는 규정·계약·내부 준수 요구 목록이 없습니다. | [서비스 설명](../../README.md) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 필요한 준수 통제의 범위를 판단할 근거가 부족합니다. |
| [OPS01-BP05 Evaluate threat landscape](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_priorities_eval_threat_landscape.html) | 위협과 그 변화를 운영 우선순위에 반영합니다. | WAF가 관리형 규칙으로 요청을 검사하고 기록합니다. 위협 검토 주기·평가 기록은 없습니다. | [리소스 구성](#11-리소스-구성) · [콘텐츠·DB 기록](#45-콘텐츠db-로그와-관측-범위) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 위협 변화가 운영 우선순위에 반영되는지 미확인입니다. |
| [OPS01-BP06 Evaluate tradeoffs while managing benefits and risks](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_priorities_eval_tradeoffs.html) | 편익·위험의 상충 관계를 검토하고 수용 여부를 결정합니다. | README에 배포·알림 제약이 있지만 위험 수용 주체·허용 시간·재검토 기준은 없습니다. | [서비스 설명](../../README.md) · [배포 기록](#41-api-배포의-정상-처리-용량-공백) · [경보 이력](#42-서비스-경보의-감지와-전달) | 확인 불가 | 업무 차원의 편익·위험 합의 여부는 미확인입니다. |

### 3.2 OPS02 — 성과를 지원하는 조직 구조

**공식 질문**: [OPS 2. How do you structure your organization to support your business outcomes?](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops-02.html)

| 공식 BP·명칭·원문 | 점검 기준 | 실제 현재 상태 | 확인 근거 | 판정 | 판정 사유 |
|---|---|---|---|---|---|
| [OPS02-BP01 Resources have identified owners](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_ops_model_def_resource_owners.html) | 각 리소스의 책임자를 식별할 수 있어야 합니다. | README에는 리소스 역할이 있으며 운영 책임자 자료는 없습니다. | [리소스 구성](#11-리소스-구성) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 각 리소스의 관리·대응 책임자를 판단할 근거가 부족합니다. |
| [OPS02-BP02 Processes and procedures have identified owners](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_ops_model_def_proc_owners.html) | 절차마다 유지·개선 책임자를 지정합니다. | 배포 흐름은 문서화되어 있으나 절차별 책임자 자료는 없습니다. | [API 운영 설명](../../terraform/env/was/README.md) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 절차를 유지·개선할 담당자의 지정 여부는 미확인입니다. |
| [OPS02-BP03 Operations activities have identified owners responsible for their performance](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_ops_model_def_activity_owners.html) | 운영 활동의 실행과 성과에 책임질 주체를 지정합니다. | 관리형 서비스와 자동화가 운영 작업을 수행하며 담당자의 책임 범위는 미확인입니다. | [리소스 구성](#11-리소스-구성) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 운영 활동의 실행·성과에 대한 책임 배분 자료가 필요합니다. |
| [OPS02-BP04 Mechanisms exist to manage responsibilities and ownership](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_ops_model_def_responsibilities_ownership.html) | 소유권·책임 변경을 관리하는 절차를 마련합니다. | 인수인계·담당 변경·책임 조정 기록이 없습니다. | [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 소유권과 책임 변경을 관리하는 절차는 미확인입니다. |
| [OPS02-BP05 Mechanisms exist to request additions, changes, and exceptions](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_ops_model_req_add_chg_exception.html) | 추가·변경·예외 요청의 접수와 판단 경로를 정합니다. | Terraform 변경 이력은 있으며 요청·승인·예외 처리 기록은 없습니다. | [변경 관리 근거](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 변경 요청의 접수·판단 경로는 미확인입니다. |
| [OPS02-BP06 Responsibilities between teams are predefined or negotiated](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_ops_model_def_neg_team_agreements.html) | 팀 간 역할과 의존 관계를 합의합니다. | 팀 구성과 협업 합의 자료가 없습니다. | [Terraform 운영 구조](../../terraform/README.md) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 팀 간 책임과 의존 관계의 합의 여부는 미확인입니다. |

### 3.3 OPS03 — 조직 문화

**공식 질문**: [OPS 3. How does your organizational culture support your business outcomes?](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops-03.html)

| 공식 BP·명칭·원문 | 점검 기준 | 실제 현재 상태 | 확인 근거 | 판정 | 판정 사유 |
|---|---|---|---|---|---|
| [OPS03-BP01 Provide executive sponsorship](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_org_culture_executive_sponsor.html) | 운영 모델을 뒷받침할 의사결정권자의 지원을 확보합니다. | 지원 주체와 자원 배정 기록이 없습니다. | [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 운영 모델에 대한 의사결정권자의 지원 여부는 미확인입니다. |
| [OPS03-BP02 Team members are empowered to take action when outcomes are at risk](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_org_culture_team_emp_take_action.html) | 성과가 위험할 때 담당자가 대응할 권한을 갖습니다. | SSM으로 인스턴스에 접속할 수 있으며 대응 권한·위임 규칙은 미확인입니다. | [리소스 구성](#11-리소스-구성) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 성과 위험에 대응할 담당자의 재량 범위를 확인할 자료가 필요합니다. |
| [OPS03-BP03 Escalation is encouraged](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_org_culture_team_enc_escalation.html) | 문제를 적시에 상위 담당자에게 알릴 수 있어야 합니다. | 문제를 상위 담당자에게 알리는 정책·실행 기록이 없습니다. | [경보 이력](#42-서비스-경보의-감지와-전달) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 문제 제기를 장려하고 지원하는 방식은 미확인입니다. |
| [OPS03-BP04 Communications are timely, clear, and actionable](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_org_culture_effective_comms.html) | 운영 의사소통이 적시성·명확성·실행 가능성을 갖춥니다. | README에 구성·제약이 설명되어 있으며 사건 당시 의사소통 기록은 없습니다. | [서비스 설명](../../README.md) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 사건 안내의 적시성·명확성·실행 가능성을 평가할 자료가 부족합니다. |
| [OPS03-BP05 Experimentation is encouraged](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_org_culture_team_enc_experiment.html) | 안전하게 실험하고 학습할 수 있도록 지원합니다. | 이미지 테스트를 사용하며 실험 지원 정책·실행 자료는 없습니다. | [이미지·테스트 정의](../../terraform/modules/image-builder/main.tf#L195) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 운영 개선을 위한 실험과 학습 지원 여부는 미확인입니다. |
| [OPS03-BP06 Team members are encouraged to maintain and grow their skill sets](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_org_culture_team_enc_learn.html) | 담당자의 역량 유지·성장을 지원합니다. | 교육·학습·숙련도 점검 자료가 없습니다. | [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 담당자의 역량 유지·성장 지원 여부는 미확인입니다. |
| [OPS03-BP07 Resource teams appropriately](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_org_culture_team_res_appro.html) | 운영 부담과 목표에 맞는 인력·시간을 확보합니다. | 근무·당직·지원 범위·업무량 자료가 없습니다. | [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 운영 부담에 맞는 인력·시간의 적정성을 판단하기 어렵습니다. |

### 3.4 OPS04 — 관측 체계 구현

**공식 질문**: [OPS 4. How do you implement observability in your workload?](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops-04.html)

| 공식 BP·명칭·원문 | 점검 기준 | 실제 현재 상태 | 확인 근거 | 판정 | 판정 사유 |
|---|---|---|---|---|---|
| [OPS04-BP01 Identify key performance indicators](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_observability_identify_kpis.html) | 사업·기술 성과를 나타내는 KPI와 목표를 정의합니다. | CPU 확장 목표와 자원·오류 임계값을 사용하며 검색 성공률·응답 시간·가용성 목표는 미확인입니다. | [관측 설정](#12-옵저빌리티-구성) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 업무 성과와 기술 지표를 연결한 목표 자료가 부족합니다. |
| [OPS04-BP02 Implement application telemetry](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_observability_application_telemetry.html) | 애플리케이션 상태를 설명할 로그·지표·추적을 수집합니다. | ALB 지표·로그와 시스템 그룹의 API 기록이 수집됩니다. 요청 식별자·업무 지표·오류 문맥의 범위는 미확인입니다. | [관측 설정](#12-옵저빌리티-구성) · [API 로그](#43-시스템-로그와-api-기록-수집) | 확인 불가 | 앱 상태와 업무 요청을 연계하는 계측 자료가 부족합니다. |
| [OPS04-BP03 Implement user experience telemetry](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_observability_customer_telemetry.html) | 실제 또는 합성 사용자 흐름의 경험을 관측합니다. | CloudFront 요청 기록이 있으며 RUM·Synthetics는 사용하지 않습니다. 외부 사용자 계측은 미확인입니다. | [관측 설정](#12-옵저빌리티-구성) · [콘텐츠·DB 기록](#45-콘텐츠db-로그와-관측-범위) | 확인 불가 | 브라우저의 화면 표시와 기능별 경험을 설명할 자료가 부족합니다. |
| [OPS04-BP04 Implement dependency telemetry](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_observability_dependency_telemetry.html) | DB·외부 서비스 등 의존성의 가용성·성능을 관측합니다. | RDS 로그·자원 경보와 이미지 빌드 시 DB 검사가 있습니다. RDS 경보의 전달 동작은 꺼져 있습니다. | [관측 설정](#12-옵저빌리티-구성) · [경보 이력](#42-서비스-경보의-감지와-전달) · [API 테스트](../../terraform/modules/image-builder/fastapi.tf#L95) | 부분 충족 | DB 상태를 수집하지만 경보가 운영자 대응으로 전달되지 않습니다. |
| [OPS04-BP05 Implement distributed tracing](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_observability_dist_trace.html) | 요청이 여러 구성 요소를 지나는 경로를 추적합니다. | 공통 기간의 서울 X-Ray 서비스 그래프가 비어 있습니다. 개별 요청 추적과 외부 계측 범위는 미확인입니다. | [추적 자료](#46-운영-절차와-개선-판단의-자료-제약) · [X-Ray 서비스 그래프](03-reliability.md#44-로그-수집-경로와-업무-관측의-공백) | 확인 불가 | API·DB의 요청 경로를 연결하는 추적 근거가 부족합니다. |

### 3.5 OPS05 — 변경 품질과 운영 반영

**공식 질문**: [OPS 5. How do you reduce defects, ease remediation, and improve flow into production?](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops-05.html)

| 공식 BP·명칭·원문 | 점검 기준 | 실제 현재 상태 | 확인 근거 | 판정 | 판정 사유 |
|---|---|---|---|---|---|
| [OPS05-BP01 Use version control](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_dev_integ_version_control.html) | 코드·구성·산출물의 변경과 릴리스를 추적하고 이전 버전으로 되돌릴 수 있도록 관리합니다. | Terraform·이미지·시작 템플릿은 버전으로 관리합니다. 비공개 앱의 버전·협업·복원 절차는 미확인입니다. | [변경 관리 근거](#46-운영-절차와-개선-판단의-자료-제약) · [배포 기록](#41-api-배포의-정상-처리-용량-공백) | 확인 불가 | 앱과 산출물 전체의 변경 추적·복원 범위를 판단할 자료가 부족합니다. |
| [OPS05-BP02 Test and validate changes](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_dev_integ_test_val_chg.html) | 빌드 산출물을 만들기 전부터 코드·구성 변경을 테스트하고 요구 사항과 의도한 결과를 검증합니다. | 이미지에 Agent·FastAPI·DB 검사가 구성되어 있습니다. 앱의 단위·통합 테스트 자료는 없습니다. | [이미지·테스트 정의](../../terraform/modules/image-builder/main.tf#L195) · [API 테스트](../../terraform/modules/image-builder/fastapi.tf#L95) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 요구 사항별 변경 검증 범위와 실행 결과는 미확인입니다. |
| [OPS05-BP03 Use configuration management systems](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_dev_integ_conf_mgmt_sys.html) | 구성을 일관되게 배포하고 버전·변경·드리프트를 관리합니다. | Terraform과 버전 지정 시작 템플릿을 사용합니다. 구성 드리프트 검사·앱 구성 관리 자료는 없습니다. | [리소스 구성](#11-리소스-구성) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 운영 구성의 지속적인 변경·이탈 관리 여부는 미확인입니다. |
| [OPS05-BP04 Use build and deployment management systems](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_dev_integ_build_mgmt_sys.html) | 빌드·배포 시스템으로 반복 작업과 오류를 줄이고 올바른 구성을 안전하게 배포합니다. | Image Builder의 AMI가 시작 템플릿과 인스턴스 교체로 연결됩니다. 교체 중 정상 대상이 0이 되었습니다. | [리소스 구성](#11-리소스-구성) · [배포 기록](#41-api-배포의-정상-처리-용량-공백) | 부분 충족 | 빌드·배포 관리는 작동하지만 안전한 운영 교체가 부족합니다. |
| [OPS05-BP05 Perform patch management](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_dev_integ_patch_mgmt.html) | 패치 대상·주기·검증·적용 상태를 관리합니다. | SSM Agent는 최신 버전으로 표시되지 않고 RDS 자동 마이너 업그레이드는 꺼져 있습니다. 패치 운영 자료는 없습니다. | [리소스 구성](#11-리소스-구성) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 패치 대상·일정·검증·적용 상태를 판단할 근거가 부족합니다. |
| [OPS05-BP06 Share design standards](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_dev_integ_share_design_stds.html) | 설계 기준을 공유·갱신하고 필요한 변경·예외 절차를 마련합니다. | README에 계층 분리·접근 통제·관측·배포 기준이 있습니다. 갱신·공유·예외 처리 자료는 없습니다. | [서비스 설명](../../README.md) · [Terraform 운영 구조](../../terraform/README.md) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 설계 기준의 지속적인 관리와 조직 내 적용 방식은 미확인입니다. |
| [OPS05-BP07 Implement practices to improve code quality](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_dev_integ_code_quality.html) | 코드 품질을 유지하는 검토·검사 절차를 적용합니다. | 이미지 테스트는 있으며 앱 리뷰·정적 검사·CI 실행 자료는 없습니다. | [API 테스트](../../terraform/modules/image-builder/fastapi.tf#L95) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 개발 단계의 코드 품질 관리 절차는 미확인입니다. |
| [OPS05-BP08 Use multiple environments](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_dev_integ_multi_env.html) | 운영 영향 없이 검증할 복수 환경을 사용합니다. | Terraform env는 관리 영역을 구분합니다. 별도 검증 환경의 위치·역할은 미확인입니다. | [리소스 구성](#11-리소스-구성) · [Terraform 운영 구조](../../terraform/README.md) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 운영 영향 없이 변경을 시험할 환경 자료가 필요합니다. |
| [OPS05-BP09 Make frequent, small, reversible changes](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_dev_integ_freq_sm_rev_chg.html) | 작고 자주 되돌릴 수 있는 변경으로 영향 범위를 줄입니다. | 이미지와 템플릿을 버전으로 관리하지만 두 인스턴스를 함께 교체하고 자동 롤백은 꺼져 있습니다. | [배포 기록](#41-api-배포의-정상-처리-용량-공백) | 부분 충족 | 배포 영향이 전체 API 용량에 미치며 자동 복귀 수단이 없습니다. |
| [OPS05-BP10 Fully automate integration and deployment](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_dev_integ_auto_integ_deploy.html) | 통합부터 테스트·배포까지 자동으로 연결합니다. | 이미지 빌드·교체 단계는 자동화되어 있으며 코드 변경을 연계하는 외부 CI 자료는 없습니다. | [리소스 구성](#11-리소스-구성) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 통합부터 테스트·배포까지 이어지는 자동화 범위는 미확인입니다. |

### 3.6 OPS06 — 배포 위험 완화

**공식 질문**: [OPS 6. How do you mitigate deployment risks?](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops-06.html)

| 공식 BP·명칭·원문 | 점검 기준 | 실제 현재 상태 | 확인 근거 | 판정 | 판정 사유 |
|---|---|---|---|---|---|
| [OPS06-BP01 Plan for unsuccessful changes](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_mit_deploy_risks_plan_for_unsucessful_changes.html) | 실패한 변경의 복구 방법·판단 기준을 미리 정합니다. | 자동 롤백은 꺼져 있으며 수동 복구 절차·목표·실행 기록은 없습니다. | [배포 기록](#41-api-배포의-정상-처리-용량-공백) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 실패 시 복구 방법과 판단 기준의 준비 여부는 미확인입니다. |
| [OPS06-BP02 Test deployments](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_mit_deploy_risks_test_val_chg.html) | 운영 투입 전에 배포 절차 전체와 성공·실패 경로를 운영에 가까운 환경에서 검증합니다. | 이미지 테스트와 운영 교체 이력이 있으며 배포·롤백 사전 시험 기록은 없습니다. | [이미지·테스트 정의](../../terraform/modules/image-builder/main.tf#L195) · [API 테스트](../../terraform/modules/image-builder/fastapi.tf#L95) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 배포 절차 전체의 성공·실패 경로를 검증했는지 미확인입니다. |
| [OPS06-BP03 Employ safe deployment strategies](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_mit_deploy_risks_deploy_mgmt_sys.html) | 안전장치로 배포 실패의 고객 영향 범위를 제한합니다. | 실제 교체는 최소 정상 비율 0%로 두 대를 함께 제외했고 정상 대상 수가 0이 되었습니다. | [배포 기록](#41-api-배포의-정상-처리-용량-공백) | 미충족 | 교체 중 정상 처리 용량을 유지하는 안전장치가 부족합니다. |
| [OPS06-BP04 Automate testing and rollback](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_mit_deploy_risks_auto_testing_and_rollback.html) | 자동 테스트와 실패 조건에 따른 자동 롤백을 연결합니다. | 이미지 테스트는 활성화되어 있지만 인스턴스 교체의 자동 롤백과 경보 연결은 꺼져 있습니다. | [이미지·테스트 정의](../../terraform/modules/image-builder/main.tf#L195) · [배포 기록](#41-api-배포의-정상-처리-용량-공백) | 부분 충족 | 자동 테스트가 실패 배포의 자동 복귀로 연결되지 않습니다. |

### 3.7 OPS07 — 운영 지원 준비

**공식 질문**: [OPS 7. How do you know that you are ready to support a workload?](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops-07.html)

| 공식 BP·명칭·원문 | 점검 기준 | 실제 현재 상태 | 확인 근거 | 판정 | 판정 사유 |
|---|---|---|---|---|---|
| [OPS07-BP01 Ensure personnel capability](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_ready_to_support_personnel_capability.html) | 운영자가 지원에 필요한 역량을 갖추었는지 확인합니다. | SSM 운영 접속을 사용하며 담당자 역량·훈련 자료는 없습니다. | [리소스 구성](#11-리소스-구성) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 업무 지원에 필요한 숙련도와 인력 준비도는 미확인입니다. |
| [OPS07-BP02: Ensure a consistent review of operational readiness](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_ready_to_support_const_orr.html) | 일관된 운영 준비 검토를 반복합니다. | README에 배포 확인 기준이 있지만 운영 준비 검토·승인 기록은 없습니다. | [서비스 설명](../../README.md) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 일관된 준비 검토의 반복 수행 여부는 미확인입니다. |
| [OPS07-BP03 Use runbooks to perform procedures](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_ready_to_support_use_runbooks.html) | 반복 절차를 실행 가능한 런북으로 관리합니다. | README가 빌드·배포·접속 흐름을 설명하며 실행 가능한 런북과 사용 기록은 없습니다. | [API 운영 설명](../../terraform/env/was/README.md) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 실패 분기·담당·실행·결과 확인을 포함한 반복 절차 자료가 필요합니다. |
| [OPS07-BP04 Use playbooks to investigate issues](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_ready_to_support_use_playbooks.html) | 문제 조사를 위한 플레이북을 사용합니다. | 경보·로그를 수집하며 문제별 조사 플레이북과 사용 기록은 없습니다. | [수집 위치](#13-텔레메트리-수집-현황) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 사건 유형에 맞춘 조사 절차의 운영 여부는 미확인입니다. |
| [OPS07-BP05 Make informed decisions to deploy systems and changes](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_ready_to_support_informed_deploy_decisions.html) | 준비도·위험을 근거로 배포 여부를 결정합니다. | 실제 교체 이력이 있으며 배포 전 준비도·위험 검토 기록은 없습니다. | [배포 기록](#41-api-배포의-정상-처리-용량-공백) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 배포 여부를 결정한 근거를 확인할 자료가 필요합니다. |
| [OPS07-BP06 Create support plans for production workloads](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_ready_to_support_enable_support_plans.html) | 운영 서비스의 지원 계획과 외부 지원 경로를 마련합니다. | 운영 지원 계획·AWS Support 범위·연락 경로 자료가 없습니다. | [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 내부·외부 지원 체계의 준비 여부는 미확인입니다. |

### 3.8 OPS08 — 관측 자료 활용

**공식 질문**: [OPS 8. How do you utilize workload observability in your organization?](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops-08.html)

| 공식 BP·명칭·원문 | 점검 기준 | 실제 현재 상태 | 확인 근거 | 판정 | 판정 사유 |
|---|---|---|---|---|---|
| [OPS08-BP01 Analyze workload metrics](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_workload_observability_analyze_workload_metrics.html) | 사업·기술 목표와 연결된 지표를 정기적으로 분석하고 기준선·이상·추세를 활용합니다. | 자원·HTTP 경보가 지표를 평가하며 KPI별 분석 주기·기준선·대응 결정 자료는 없습니다. | [관측 설정](#12-옵저빌리티-구성) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 목표에 따른 정기 분석과 운영 활용 여부는 미확인입니다. |
| [OPS08-BP02 Analyze workload logs](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_workload_observability_analyze_workload_logs.html) | 로그를 분석해 상태·문제의 원인을 파악합니다. | ALB·시스템·DB·콘텐츠 로그가 수집되며 정기 분석·사건 대응 활용 기록은 없습니다. | [API 로그](#43-시스템-로그와-api-기록-수집) · [초기 API 기록](#44-초기-api-준비-지연과-alb-오류) · [콘텐츠·DB 기록](#45-콘텐츠db-로그와-관측-범위) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 로그를 운영 판단에 지속적으로 사용하는지 미확인입니다. |
| [OPS08-BP03 Analyze workload traces](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_workload_observability_analyze_workload_traces.html) | 추적 자료로 요청 경로와 병목을 분석합니다. | 서울 X-Ray 서비스 그래프가 비어 있으며 개별 요청 추적·외부 분석 기록은 미확인입니다. | [추적 자료](#46-운영-절차와-개선-판단의-자료-제약) · [X-Ray 서비스 그래프](03-reliability.md#44-로그-수집-경로와-업무-관측의-공백) | 확인 불가 | 요청 경로와 병목을 분석하는 운영 절차는 미확인입니다. |
| [OPS08-BP04 Create actionable alerts](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_workload_observability_create_alerts.html) | 성과 위험을 적시에 전달하고 대응 가능한 경보를 만듭니다. | 서비스 경보 9개에 전달 동작이 없습니다. CPU 목표 추적 경보 2개는 ASG 정책을 실행합니다. | [경보 이력](#42-서비스-경보의-감지와-전달) | 부분 충족 | 서비스 이상은 감지하지만 운영자에게 전달하는 연결이 빠져 있습니다. |
| [OPS08-BP05 Create dashboards](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_workload_observability_create_dashboards.html) | 시스템·사업 상태를 이해할 대시보드를 제공합니다. | CloudWatch 대시보드는 없으며 외부 현황판 자료는 없습니다. | [관측 설정](#12-옵저빌리티-구성) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 업무·시스템 상태를 한눈에 파악하는 수단은 미확인입니다. |

### 3.9 OPS09 — 운영 활동의 건강 상태

**공식 질문**: [OPS 9. How do you understand the health of your operations?](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops-09.html)

| 공식 BP·명칭·원문 | 점검 기준 | 실제 현재 상태 | 확인 근거 | 판정 | 판정 사유 |
|---|---|---|---|---|---|
| [OPS09-BP01 Measure operations goals and KPIs with metrics](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_operations_health_measure_ops_goals_kpis.html) | 운영 목표를 KPI로 정하고 측정합니다. | 자원·요청 지표는 있으며 배포 실패율·복구 시간 등의 운영 목표는 미확인입니다. | [관측 설정](#12-옵저빌리티-구성) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 운영 활동의 성과 목표와 측정 기준 자료가 필요합니다. |
| [OPS09-BP02 Communicate status and trends to ensure visibility into operation](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_operations_health_communicate_status_trends.html) | 운영 상태와 추세를 이해관계자에게 공유합니다. | CloudWatch 대시보드는 없으며 상태 보고·추세 공유 자료도 없습니다. | [관측 설정](#12-옵저빌리티-구성) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 운영 성과를 이해관계자에게 공유하는 방식은 미확인입니다. |
| [OPS09-BP03 Review operations metrics and prioritize improvement](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_operations_health_review_ops_metrics_prioritize_improvement.html) | 운영 지표를 검토해 개선 우선순위를 정합니다. | 정기 지표 검토·우선순위 변경·개선 효과 기록이 없습니다. | [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 운영 지표에 근거한 개선 과제 선정 여부는 미확인입니다. |

### 3.10 OPS10 — 이벤트와 사건 대응

**공식 질문**: [OPS 10. How do you manage workload and operations events?](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops-10.html)

| 공식 BP·명칭·원문 | 점검 기준 | 실제 현재 상태 | 확인 근거 | 판정 | 판정 사유 |
|---|---|---|---|---|---|
| [OPS10-BP01 Use a process for event, incident, and problem management](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_event_response_event_incident_problem_process.html) | 이벤트·사건·문제의 접수와 해결 절차를 구분해 관리합니다. | ASG 실패·교체·경보 기록은 있으며 사건 등록·해결 기록은 없습니다. | [배포 기록](#41-api-배포의-정상-처리-용량-공백) · [초기 API 기록](#44-초기-api-준비-지연과-alb-오류) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 이벤트 접수부터 원인 해결까지의 관리 절차는 미확인입니다. |
| [OPS10-BP02 Have a process per alert](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_event_response_process_per_alert.html) | 각 경보에 대응 절차를 연결합니다. | 서비스 경보 9개에 알림 동작이 없으며 별도 대응 절차 자료도 없습니다. | [경보 이력](#42-서비스-경보의-감지와-전달) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 경보별 담당·판단·조치 기준은 미확인입니다. |
| [OPS10-BP03 Prioritize operational events based on business impact](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_event_response_prioritize_events.html) | 사업 영향에 따라 사건 우선순위를 결정합니다. | 정상 대상 공백과 ALB 오류 기록은 있으며 당시 사업 영향 등급·대응 결정 자료는 없습니다. | [배포 기록](#41-api-배포의-정상-처리-용량-공백) · [초기 API 기록](#44-초기-api-준비-지연과-alb-오류) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 업무 영향에 따라 대응 순서를 정했는지 미확인입니다. |
| [OPS10-BP04 Define escalation paths](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_event_response_define_escalation_paths.html) | 담당자·조건·시간에 따른 에스컬레이션 경로를 정합니다. | 당직·연락망·상위 담당자 통보 기준 자료가 없습니다. | [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 대응 지연이나 권한 부족 시 문제를 넘길 경로는 미확인입니다. |
| [OPS10-BP05 Define a customer communication plan for service-impacting events](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_event_response_push_notify.html) | 서비스 영향 사건의 고객 안내 계획을 정합니다. | 배포 중단 가능성은 문서화되어 있으나 이용자 안내 계획·실행 기록은 없습니다. | [서비스 설명](../../README.md) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 서비스 영향 사건의 안내 시점·담당·내용은 미확인입니다. |
| [OPS10-BP06 Communicate status through dashboards](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_event_response_dashboards.html) | 사건 상태를 대시보드로 공유합니다. | CloudWatch 대시보드는 없으며 외부 상태 페이지 자료도 없습니다. | [관측 설정](#12-옵저빌리티-구성) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 사건 진행 상황을 공유하는 현황판은 미확인입니다. |
| [OPS10-BP07 Automate responses to events](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_event_response_auto_event_response.html) | 확인된 이벤트에 대한 대응을 자동화합니다. | ASG 상태 검사와 CPU 목표 추적이 작동하며 서비스 경보의 대응 동작은 꺼져 있습니다. | [리소스 구성](#11-리소스-구성) · [경보 이력](#42-서비스-경보의-감지와-전달) | 부분 충족 | 인스턴스·용량 대응은 자동화되어 있지만 오류·DB 경보의 대응 연결은 없습니다. |

### 3.11 OPS11 — 운영 개선

**공식 질문**: [OPS 11. How do you evolve operations?](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops-11.html)

| 공식 BP·명칭·원문 | 점검 기준 | 실제 현재 상태 | 확인 근거 | 판정 | 판정 사유 |
|---|---|---|---|---|---|
| [OPS11-BP01 Have a process for continuous improvement](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_evolve_ops_process_cont_imp.html) | 운영을 지속적으로 개선하는 절차를 유지합니다. | 구성·제약 문서는 있으며 반복 개선 주기·담당·성과 기록은 없습니다. | [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 개선 과제의 선정·실행·검증 절차는 미확인입니다. |
| [OPS11-BP02 Perform post-incident analysis](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_evolve_ops_perform_rca_process.html) | 사건 이후 원인·영향·재발 방지 사항을 분석합니다. | 초기 시작 실패와 배포 공백 기록은 있으나 사후 분석 자료는 없습니다. | [배포 기록](#41-api-배포의-정상-처리-용량-공백) · [초기 API 기록](#44-초기-api-준비-지연과-alb-오류) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 원인·영향·재발 방지 사항을 정리한 운영 기록이 필요합니다. |
| [OPS11-BP03 Implement feedback loops](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_evolve_ops_feedback_loops.html) | 운영 경험이 개발·설계·절차로 돌아가는 경로를 마련합니다. | 피드백 접수·반영·효과 검증 기록이 없습니다. | [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 운영 경험이 개발·설계·절차에 반영되는 경로는 미확인입니다. |
| [OPS11-BP04 Perform knowledge management](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_evolve_ops_knowledge_management.html) | 운영 지식을 공유하고 추가·갱신·보관 절차로 정확성과 최신성을 유지합니다. | README와 모듈 문서에 운영 지식을 저장하며 갱신·활용·보관 절차는 미확인입니다. | [서비스 설명](../../README.md) · [Terraform 운영 구조](../../terraform/README.md) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 지식의 최신성과 활용을 유지하는 관리 자료가 필요합니다. |
| [OPS11-BP05 Define drivers for improvement](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_evolve_ops_drivers_for_imp.html) | 개선을 촉진할 목표와 근거를 정의합니다. | CPU 목표·경보 임계값은 있으며 개선 목표·성과 기준·과제 선정 근거는 없습니다. | [관측 설정](#12-옵저빌리티-구성) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 개선을 촉진하는 업무 목표와 우선순위는 미확인입니다. |
| [OPS11-BP06 Validate insights](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_evolve_ops_validate_insights.html) | 사업 책임자·기술 동료와 분석 결과의 타당성을 검토하고 충분한 근거로 개선 판단을 검증합니다. | 사건을 분석할 지표·로그는 있으며 관계자와 가설을 검토한 기록은 없습니다. | [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 분석 결과를 업무 맥락과 대조하여 검증한 자료가 필요합니다. |
| [OPS11-BP07 Perform operations metrics reviews](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_evolve_ops_metrics_review.html) | 운영 지표를 정기적으로 검토합니다. | 운영 지표의 검토 주기·참여자·회의 자료가 없습니다. | [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 운영 성과와 추세의 정기 검토 여부는 미확인입니다. |
| [OPS11-BP08 Document and share lessons learned](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_evolve_ops_share_lessons_learned.html) | 학습한 내용을 기록하고 공유합니다. | 구성 문서는 있으며 사건의 교훈을 공유·반영한 기록은 없습니다. | [서비스 설명](../../README.md) · [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 운영 학습이 담당자와 관련 절차에 전달되는지 미확인입니다. |
| [OPS11-BP09 Allocate time to make improvements](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_evolve_ops_allocate_time_for_imp.html) | 개선을 실험하고 결과를 검증할 시간과 자원을 배정합니다. | 개선·실험·효과 검증의 작업 배정 자료가 없습니다. | [운영 자료 제약](#46-운영-절차와-개선-판단의-자료-제약) | 확인 불가 | 개선에 필요한 시간과 자원의 확보 여부는 미확인입니다. |

## 4. Findings and Insights(발견 사항 및 인사이트)

### 4.1 API 배포의 정상 처리 용량 공백

**인스턴스 교체 중 API의 정상 처리 용량이 사라졌습니다.** 서울 ASG `arcamap-api`의 9월 15일 교체는 최소 정상 비율 0%·최대 용량 비율 100%로 실행되었고, 자동 롤백과 경보 연결은 꺼져 있었습니다. [Terraform 교체 정책](../../terraform/modules/compute/main.tf#L66)도 같은 조건을 사용합니다.

| 시각(09-15) | 배포·운영 기록 |
|---|---|
| 01:33:33 | 시작 템플릿 v2에 새 AMI가 반영되었습니다. |
| 01:33:46~01:33:48 | 기존 두 인스턴스가 서비스에서 제외되고 새 두 인스턴스의 시작 활동이 이어졌습니다. Instance Refresh는 01:33:47에 시작되었습니다. |
| 01:34·01:35 | ALB 정상 대상 수인 HealthyHostCount의 1분 최솟값이 각각 **0대**였습니다. |
| 01:36·01:37 | 정상 대상 수의 1분 최솟값이 각각 **2대**로 회복되었습니다. |
| 01:38:43 | 정상 대상 부족 경보가 ALARM으로 바뀌었습니다. |
| 01:39:33 | Instance Refresh가 성공 상태로 종료되었습니다. |
| 01:40:43 | 정상 대상 경보가 OK로 돌아왔습니다. |

ASG 활동과 ALB `arcamap-api`의 CloudWatch 기록은 기존 두 대를 먼저 제외한 뒤 새 대상이 준비된 흐름을 보여 줍니다. 교체 완료 전까지 정상 용량을 유지하지 못한 것이 **OPS05-BP04·BP09, OPS06-BP03·BP04**의 부족한 부분입니다. 배포 전후 20분인 **01:25 이상~01:45 미만의 요청은 3건**으로, 당시 부하는 낮았습니다.

개선의 우선순위는 **기존 정상 용량을 남긴 상태에서 새 인스턴스를 준비하는 것**입니다. 최소 정상 비율과 추가 기동 여유를 정하고, 사용자 요청 실패를 교체 중지·롤백 조건에 연결해야 합니다. 이미지·시작 템플릿의 버전 관리는 유지하면서 추가 인스턴스 비용, DB 동시 연결과 준비 시간을 함께 고려해야 합니다.

> **배포 영향의 제약**: 정상 대상 수는 1분 최솟값이며 01:33의 값은 없습니다. 실제 실패 요청과 이용자 기록이 부족해 정확한 중단 시간·업무 손실은 판단하기 어렵습니다.

### 4.2 서비스 경보의 감지와 전달

**서비스 경보 9개가 이상을 감지하지만 운영자에게 알림을 보내지 않습니다.** 서울 CloudWatch의 API·DB 경보에는 전달 대상이 없고 동작도 꺼져 있습니다. CPU 목표 추적 경보 2개는 ASG의 확장·축소 정책을 실행합니다.

| 경보 | 발생·회복 시각 | 감지한 상태 |
|---|---|---|
| `arcamap-alb-healthy-hosts` | 09-14 18:08:43 → 22:46:43 | 정상 대상 0대를 감지했고, 22:42·22:43의 2대 기록을 바탕으로 회복했습니다. |
| `arcamap-alb-5xx` | 09-14 19:59:28 → 20:11:28 | 5분 오류 합계 21건을 감지했습니다. |
| 같은 경보 | 09-14 21:25:28 → 21:27:28 | 5분 오류 합계 5건을 감지했습니다. |
| `arcamap-alb-healthy-hosts` | 09-15 01:38:43 → 01:40:43 | [인스턴스 교체](#41-api-배포의-정상-처리-용량-공백) 중 정상 대상 부족을 감지했습니다. |

경보 구성 이력에는 DB 경보가 **9월 14일 00:56**, API 경보가 **18:07**에 생성된 기록이 있습니다. 생성 당시부터 전달 동작이 꺼져 있었고 이후 변경 기록도 없어, 위 사건의 감지는 해당 경보를 통해 운영자에게 전달되지 않았습니다.

**OPS08-BP04·OPS10-BP07**에 따라 서비스 영향이 큰 경보부터 담당자·전달 경로·대응 절차를 연결해야 합니다. 정상 대상 부족, HTTP 오류, DB 자원 부족에 맞는 조치 기준을 정하고 실제 알림 수신과 대응 시작까지 점검하면 감지 이후의 대응 공백을 줄일 수 있습니다.

> **대응 기록의 제약**: 수동 감시나 외부 알림, 실제 조치 기록이 없어 운영자의 인지·대응·복구 시간은 알 수 없습니다.

### 4.3 시스템 로그와 API 기록 수집

**API 관련 기록은 시스템 로그 그룹에 모입니다.** 서울 `/arcamap/ec2/system`에는 공통 기간 동안 `arcamap-api` 또는 `uvicorn` 문자열이 포함된 이벤트가 **88,710건** 있습니다. 현재·이전 API 인스턴스와 빌드 시간대의 스트림에 걸친 기록이며, 프로세스 시작 등 요청 처리 외의 메시지도 포함됩니다.

[CloudWatch Agent 설정](../../terraform/env/was/main.tf#L44)은 journald 기록을 시스템 그룹으로 보냅니다. 전용 `/arcamap/api/application` 그룹에는 스트림이 없지만 API 관련 로그는 기존 경로로 수집되고 있습니다.

**OPS04-BP02·OPS08-BP02**의 운영 과제는 이 기록을 ALB 요청·API 예외·DB 연결과 연결하는 것입니다. 요청 식별자와 오류 문맥이 있으면 사건 시각의 실패 경로를 따라가기 쉬워집니다. 기존 스트림과 필드로 구분할 수 있다면 이를 활용하고, 접근 권한이나 보존 기간을 달리해야 할 때 로그 그룹 분리를 검토하는 것이 적절합니다.

> **업무 연계의 제약**: 앱 코드와 로그 스키마 자료가 없어 요청별 성공·실패와 DB 호출의 연결 범위는 미확인입니다. 로그 보완 시에는 인증정보·개인정보 보호와 현행 보존 정책을 유지해야 합니다.

### 4.4 초기 API 준비 지연과 ALB 오류

**인스턴스가 기동된 뒤에도 API의 정상 응답 준비가 지연되었습니다.** 서울 `arcamap-api`의 ASG 활동, ALB 정상 대상 지표와 헬스 체크 로그에 다음 기록이 있습니다.

| 시각(09-14) | 초기 운영 기록 |
|---|---|
| 01:51~01:52 | 인스턴스 시작 활동 3건이 실패했습니다. `AWSServiceRoleForAutoScaling` 역할 인수 거부로 로드 밸런서 구성 검증에 실패한 기록입니다. |
| 01:52~01:59 | 다음 두 인스턴스의 시작 활동이 진행되어 성공으로 끝났습니다. |
| 01:52~22:41 | ALB 정상 대상 수의 1분 최솟값이 계속 **0대**였습니다. |
| 22:34 | 이전 API 두 대의 시스템 스트림에 API 관련 첫 기록이 있습니다. |
| 22:40 | ALB 헬스 체크에 첫 HTTP 200 성공 기록이 있습니다. |
| 22:42·22:43 | 정상 대상 수의 1분 최솟값이 각각 **2대**였습니다. |

초기 시작 실패의 원인은 역할 인수 거부입니다. 이후 인스턴스 기동은 성공했지만 정상 응답까지는 지연이 이어졌습니다. IAM 권한 변경과 앱 내부 사건 자료가 부족해 권한 문제가 해소된 경위와 후속 준비 지연의 근본 원인은 미확인입니다.

공통 기간 ALB 오류는 **307건**이며, 서울 `/aws/vendedlogs/elb/arcamap-api`의 접근 로그에는 **502 응답 303건·503 응답 4건**이 있습니다. 503은 9월 14일 **01:27~01:48**, 502는 **01:55~22:35**에 발생했습니다. 헬스 체크에는 연결 재설정과 시간 초과가 기록되어 있어 요청 처리 준비를 인스턴스 기동 여부만으로 판단하기 어렵습니다.

CloudWatch의 ALB 정상 대상·요청 기록은 **9월 14일 01:52부터**, ASG의 서비스 중 인스턴스 수 기록은 **18:07부터** 있습니다. ASG는 2대를 표시하는 동안에도 ALB 정상 대상은 0인 구간이 있었습니다. 상세 접근·헬스 체크 기록은 [신뢰성 문서의 로그 근거](03-reliability.md#44-로그-수집-경로와-업무-관측의-공백)에 있습니다.

**OPS06-BP02·OPS07-BP02·OPS11-BP02**에 따라 초기 적용과 배포의 종료 조건에 ALB 정상 대상, 실제 API 응답과 DB 연결을 포함해야 합니다. 실패 시 확인할 로그·권한·복구 경로도 절차로 남겨야 합니다. 현재 `/health` 검사와 DB 의존성 검사를 역할에 맞게 유지하면서, 일시적인 DB 문제로 모든 API 인스턴스를 불필요하게 교체하지 않도록 해야 합니다.

> **초기 영향의 제약**: 공개 개시 시점과 시험·봇·이용자 요청의 구분이 없어 업무 피해 규모는 미확인입니다. 1분 단위 지표로 정확한 연속 중단 시간을 산정하기도 어렵습니다.

### 4.5 콘텐츠·DB 로그와 관측 범위

**CloudFront·DB·이미지 빌드 기록이 API 운영 분석을 뒷받침합니다.** CloudFront는 S3 로그 버킷으로, ALB는 CloudWatch Logs로 기록을 전달합니다. 각 서비스의 로그 전달 구성은 [CloudFront](../../terraform/modules/cloudfront/main.tf#L137)와 [ALB](../../terraform/modules/alb/main.tf#L72)에 정의되어 있습니다.

| 기록 | 공통 기간의 운영 근거 | 활용 |
|---|---|---|
| CloudFront 접근 로그 | 응답 완료 시각 기준 **14,181건**이며 기록은 **09-14 01:07:08~09-21 23:57:55**에 있습니다. | 콘텐츠 요청의 응답 상태·캐시 처리·지연을 구분합니다. [성능 문서 4.5](04-performance-efficiency.md#45-cloudfront-캐시-결과와-콘텐츠별-응답-성능) |
| PostgreSQL 로그 | `/aws/rds/instance/arcamap-postgres/postgresql`에 **09-14 00:44~09-21 23:58** 기록이 있습니다. | API 오류 시각과 DB 내부 사건을 대조합니다. |
| 이미지 빌드 로그 | `/aws/imagebuilder/arcamap-api`에 **09-14 01:04~09-15 01:05**의 버전별 기록이 있습니다. | 이미지 생성·테스트와 인스턴스 교체의 경위를 연결합니다. |
| WAF 로그 | **09-15 02:43~09-21 23:57** 요청 판정이 기록되어 있으며 관리형 규칙은 Count로 동작합니다. | 허용 요청에 포함된 위협 탐지 결과를 분석합니다. |

CloudFront 기록은 응답 상태와 전송 중 연결 종료를 구분할 수 있어 콘텐츠 오류의 운영 판단에 활용할 수 있습니다. DB·빌드 기록은 같은 사건 시각과 배포 버전으로 연결하면 초기 준비 지연과 배포 실패를 조사하는 데 도움이 됩니다. **OPS04-BP02·BP04, OPS08-BP02**에서 필요한 다음 근거는 요청과 업무 기능을 연결하는 앱 기록입니다.

> **콘텐츠 관측의 제약**: 표준 로그에는 전달 지연·누락 가능성이 있으며, 응답 기록만으로 화면 표시 완료나 검색 성공 여부까지 알 수는 없습니다.

> **WAF 기록의 제약**: 첫 기록 이전의 요청은 해당 로그에 없어 공통 기간 초반의 요청 판정을 설명할 수 없습니다.

### 4.6 운영 절차와 개선 판단의 자료 제약

[서비스 README](../../README.md)와 [API 운영 설명](../../terraform/env/was/README.md)은 구성·배포·접속·운영 제약을 설명합니다. Terraform의 Git 이력과 [배포 객체](../../terraform/env/was/deployment.tf#L1), 이미지·시작 템플릿의 버전은 인프라 변경을 추적하는 기반입니다. 비공개 앱의 개발 절차와 조직의 실제 운영을 판단하려면 다음 자료가 필요합니다.

| 영역 | 부족한 자료 | 판단에 미치는 영향 |
|---|---|---|
| 우선순위·책임 | 이용자 요구·업무 목표, 책임자·승인권자, 위험 수용·인력·교육 기록 | OPS01~OPS03의 책임 배분과 조직 지원 여부가 미확인입니다. |
| 품질·배포 준비 | 앱 테스트·리뷰·CI, 검증 환경, 배포·복구 시험, 지원 계획 | OPS05~OPS07의 개발 품질과 사전 준비 수준이 미확인입니다. |
| 분석·대응 | KPI·SLO, 정기 분석, 경보별 대응 절차·담당·고객 안내·사건 기록 | OPS04·OPS08~OPS10의 업무 목표와 실제 대응 성과가 미확인입니다. |
| 학습·개선 | 사후 분석, 관계자 검토, 피드백 반영, 지식 갱신, 개선 시간·성과 기록 | OPS11의 지속적인 학습과 개선 여부가 미확인입니다. |

공통 기간의 **서울 X-Ray 서비스 그래프는 비어 있습니다.** [신뢰성 문서 4.4](03-reliability.md#44-로그-수집-경로와-업무-관측의-공백)에 해당 근거가 있습니다. 서비스 그래프는 서비스 간 연결을 나타내며 개별 요청의 추적 요약과는 다릅니다. 현재 AWS 추적 자료로는 API·DB의 요청 경로를 설명하기 어렵습니다.

> **요청 추적의 제약**: 개별 요청 추적 요약과 외부 계측 자료가 부족해 요청 경로의 실패·지연을 분석하는 범위는 미확인입니다.

운영 절차의 자료는 담당자와 사용 사례를 중심으로 보완하는 것이 적절합니다. 특히 배포 실패의 복구 판단, 주요 경보의 대응, 초기 준비 지연의 사후 분석을 실제 사례와 연결하면 책임과 절차를 구체화할 수 있습니다.

## 5. Conclusion(결론)

ArcaMap은 이미지 기반 배포, ASG 용량 조절과 로그·지표 수집을 갖추고 있습니다. **배포 중 정상 처리 용량이 사라진 점과 서비스 경보가 운영자에게 전달되지 않는 점**이 우선 개선 대상입니다.

배포는 기존 정상 용량을 유지하며 진행하고, 실패 시 중지·복귀 기준을 마련해야 합니다. 주요 경보에는 담당자와 대응 절차를 연결해야 합니다. 추가 인스턴스 비용·DB 연결 부담·운영자의 대응 가능 시간을 함께 고려하며 실제 요청 처리와 알림 수신으로 효과를 확인할 수 있습니다.

[CloudFront 요청 기록](04-performance-efficiency.md#45-cloudfront-캐시-결과와-콘텐츠별-응답-성능)은 콘텐츠 응답을 설명하지만 업무 기능과의 연결은 부족합니다. 앱 계측과 운영 책임·사건·개선 기록이 보완되어야 요청 실패의 원인과 조직의 운영 수준을 판단할 수 있습니다.
