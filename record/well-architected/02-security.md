# Security(보안)

**🔒 공개 진입점과 내부 서버를 구분하고 역할별 권한으로 데이터 접근을 제한하는 구성**

웹·지도·사진은 CloudFront와 비공개 S3에서 제공하며, API는 ALB를 거쳐 프라이빗 EC2와 RDS에서 처리합니다. 공개 구간에는 HTTPS를, 저장소에는 암호화를 적용합니다. CloudFront에 연결한 WAF는 위협 규칙에 일치하는 요청을 기록하며 현재는 차단하지 않습니다.

**공통 집계 기간**은 KST **2026-09-14 00:00 이상, 2026-09-22 00:00 미만**입니다. **구성 확인 시점**은 KST **2026-09-22 15:45~15:53**입니다. 본문의 시각은 KST입니다.

[현재 운영 현황](#1-current-operations현재-운영-현황) · [기둥의 원칙](#2-pillar-principles기둥의-원칙에-따른-검토) · [질문 및 모범 사례](#3-questions-and-best-practices질문-및-모범-사례별-상세-점검) · [발견 사항](#4-findings-and-insights발견-사항-및-인사이트) · [결론](#5-conclusion결론)

## 1. Current Operations(현재 운영 현황)

<a id="sec-resources"></a>

### 1.1 리소스 구성

API·DB·S3는 서울에 있으며, CloudFront용 WAF와 인증서는 버지니아에 있습니다. 보안 그룹은 공개 진입점에서 API와 DB로 이어지는 통신을 제한합니다.

| 보호 대상·접근 경로 | 현재 설정과 역할 | Terraform 정의 |
|---|---|---|
| 네트워크 | `arcamap-vpc`는 두 가용 영역에 퍼블릭·API·DB 서브넷을 둡니다. 퍼블릭은 인터넷 게이트웨이, API는 NAT Gateway, DB는 VPC 내부 경로를 사용합니다. | [VPC·서브넷·라우팅](../../terraform/modules/network/main.tf#L1) |
| 계층 간 통신 | `arcamap-alb` 보안 그룹은 인터넷의 80·443을 받고 API로 8080만 보냅니다. `arcamap-api`는 ALB의 8080을 받고 DB의 5432와 외부 HTTPS로 연결합니다. `arcamap-database`는 API의 5432만 받습니다. SSH 포트는 열지 않습니다. | [보안 그룹·통신 규칙](../../terraform/modules/security/main.tf#L1) |
| API 진입점 | ALB `arcamap-api`는 HTTP 요청을 HTTPS로 전환하고 인증서로 TLS 연결을 종료합니다. API 서버에는 **HTTP 8080**으로 전달하며 WAF는 연결하지 않습니다. | [ALB·대상 그룹·리스너](../../terraform/modules/alb/main.tf#L1) |
| API 서버 | 운영 서버 두 대는 프라이빗 서브넷에 있으며 공개 IP가 없습니다. 인스턴스 메타데이터 접근에는 토큰을 요구하는 **IMDSv2**를 사용하고 루트 볼륨을 암호화합니다. | [시작 템플릿·ASG](../../terraform/modules/compute/main.tf#L1) |
| 데이터베이스 | `arcamap-postgres`는 비공개 Multi-AZ RDS이며 저장 암호화·삭제 보호와 3일 자동 백업을 사용합니다. 연결 설정은 TLS 1.2 이상을 요구합니다. | [RDS·DB 서브넷 그룹](../../terraform/modules/database/main.tf#L1) |
| 정적 콘텐츠 | CloudFront는 웹·지도·사진을 HTTPS로 제공합니다. 오리진 접근 제어인 **OAC**가 S3 요청에 서명합니다. WAF `CreatedByCloudFront-609132c8`의 관리형 규칙 그룹 네 개는 **Count**, 기본 동작은 **Allow**입니다. | [CloudFront·OAC](../../terraform/modules/cloudfront/main.tf#L5), [WAF](../../terraform/modules/cloudfront/waf.tf#L29) |
| 서비스 권한 | `arcamap-api-ec2`와 `arcamap-imagebuilder-ec2` 역할은 운영·빌드 권한을 나눕니다. 지정 DB Secret을 읽으며 빌드 역할에만 지정 배포 객체 읽기 권한을 추가합니다. | [IAM 역할·권한](../../terraform/env/was/iam.tf#L1) |
| DB 인증정보 | Secrets Manager의 `arcamap/api/database`에 보관하고 서비스 시작 시 가져옵니다. 자동 교체 설정은 없습니다. | [Secret](../../terraform/env/was/deployment.tf#L42) |
| 이미지 배포 | Image Builder `arcamap-api/1.1.2/1`은 시험을 활성화한 이미지이며 운영 서버 두 대가 이 이미지의 AMI를 사용합니다. | [이미지·빌드 환경](../../terraform/modules/image-builder/main.tf#L195), [설치·시험](../../terraform/modules/image-builder/fastapi.tf#L1) |
| 키·인증서 | EBS·RDS·Secrets Manager는 AWS 관리형 KMS 키를 사용합니다. 공개 종단의 인증서는 ACM에서 발급·갱신하며 키 내보내기를 허용하지 않습니다. | [EBS 암호화](../../terraform/modules/compute/main.tf#L15), [RDS 암호화](../../terraform/modules/database/main.tf#L23), [ALB 인증서](../../terraform/modules/alb/main.tf#L54), [CloudFront 인증서](../../terraform/modules/cloudfront/main.tf#L130) |

보안 그룹은 연결 상태를 추적하므로 DB에 별도 아웃바운드 규칙이 없어도 허용된 연결에 응답할 수 있습니다. API의 외부 HTTPS 통신에는 목적지 제한이 없습니다.

S3 버킷 다섯 개는 공개 접근 차단과 AES256 기본 암호화를 사용합니다. 콘텐츠 버킷은 지정 CloudFront 배포의 읽기 요청을 허용하며, 배포 파일과 로그는 별도 버킷에 보관합니다.

| 저장 역할 | 접근·보존 설정 | Terraform 정의 |
|---|---|---|
| 웹 오리진 | CloudFront의 객체 읽기를 허용합니다. 버전 관리·수명 주기는 설정하지 않습니다. | [웹 버킷](../../terraform/env/web/main.tf#L14), [오리진 정책](../../terraform/modules/cloudfront/main.tf#L162) |
| 사진 오리진 | CloudFront의 객체 읽기를 허용합니다. 버전 관리를 사용하고 이전 버전은 7일 후 만료합니다. | [사진 버킷·수명 주기](../../terraform/modules/s3-bucket/main.tf#L33) |
| 지도 오리진 | CloudFront에 `20260907.pmtiles` 읽기만 허용합니다. 버전 관리·수명 주기는 설정하지 않습니다. | [지도 버킷 참조](../../terraform/env/web/main.tf#L3), [객체 정책](../../terraform/modules/cloudfront/main.tf#L162) |
| CloudFront 접근 로그 | 로그 전달 서비스의 쓰기를 허용하며 객체는 30일 후 만료합니다. | [로그 버킷·전달 정책](../../terraform/modules/cloudfront/main.tf#L183) |
| API 배포 파일 | 빌드 역할이 지정 아카이브를 읽습니다. 버킷 정책은 비TLS 요청을 거부하며 버전 관리·수명 주기는 설정하지 않습니다. | [배포 버킷·전송 정책](../../terraform/env/was/deployment.tf#L6) |

<a id="sec-observability"></a>

### 1.2 옵저빌리티 구성

WAF·ALB·서버·DB 로그는 요청 검사와 접근 경로를 추적하는 데 사용합니다. CloudWatch 경보는 서비스 상태를 표시하지만 운영자에게 알림을 보내지는 않습니다.

| 관측 대상 | 도구·수집 경로 | 경보·보호 설정 |
|---|---|---|
| 정적 콘텐츠의 위협 규칙 일치 | WAF → 버지니아 CloudWatch Logs·`AWS/WAFV2` 지표 | WAF 경보는 없습니다. 로그의 `authorization`·`cookie`·`proxy-authorization` 헤더는 가립니다. [WAF 로그](../../terraform/modules/cloudfront/waf.tf#L1) |
| API 접근·TLS 연결·헬스 체크 | ALB의 세 로그 전달 소스 → 서울 `/aws/vendedlogs/elb/arcamap-api` | ALB·API 5xx와 정상 대상 수를 감시합니다. [로그 전달](../../terraform/modules/alb/main.tf#L67) |
| 서버·DB 상태 | EC2의 journald → CloudWatch Agent → 시스템 로그, RDS → PostgreSQL·upgrade 로그 | 운영 경보 9개는 알림이 비활성화돼 있습니다. 목표 추적 경보 2개는 서버 용량을 조절합니다. [API 경보](../../terraform/env/was/main.tf#L213), [DB 경보](../../terraform/env/db/main.tf#L89) |
| 정적 콘텐츠 접근 | CloudFront의 `arcamap-cloudfront` 로그 전달 소스 → 서울 S3 로그 버킷 | 접근 기록을 30일간 보관합니다. [CloudFront 로그 전달](../../terraform/modules/cloudfront/main.tf#L137) |
| 관리 작업 | 서울·버지니아 CloudTrail Event history | 최근 90일의 관리 이벤트를 제공합니다. 별도 Trail·Event Data Store·VPC Flow Logs는 없습니다. |

CloudWatch 대시보드와 로그 지표 필터는 없으며, [경보 모듈](../../terraform/modules/cloudwatch-alarm/main.tf#L1)도 운영자 알림을 설정하지 않습니다. 서울·버지니아의 Config recorder·Access Analyzer·GuardDuty detector는 없고 Inspector 검사는 비활성화돼 있습니다. Security Hub와 Macie도 활성화하지 않습니다.

> **대응 체계의 제약**: 외부 보안 분석·통지 체계와 담당자·대응 시간 목표에 관한 운영 기록이 없어, 탐지 결과가 실제 대응으로 이어지는지는 판단하기 어렵습니다.

<a id="sec-telemetry"></a>

### 1.3 텔레메트리 수집 현황

| 기록 종류 | 실제 수집 위치·대상 | 보존·수집 범위 |
|---|---|---|
| WAF 로그·지표 | 버지니아 `aws-waf-logs-CloudFrontDistribution-E39UQTOCMBVZB3`의 `cloudfront_CreatedByCloudFront-609132c8_0` 스트림과 WAF 지표 | 로그 14일입니다. 9월 15일 WAF 도입 이후 요청 기록이 있습니다. [WAF 동작](#sec-f01) |
| ALB 로그 | 서울 `/aws/vendedlogs/elb/arcamap-api`의 `ALB_Access_Logs/`·`ALB_Connection_Logs/`·`ALB_Health_Check_Logs/` 스트림 | 30일입니다. 공통 기간의 접근·연결·헬스 체크 기록이 있습니다. |
| EC2 시스템·API 기록 | 서울 `/arcamap/ec2/system`의 인스턴스별 `/system` 스트림 | 30일입니다. 공통 기간에 `arcamap-api` 또는 `uvicorn`이 포함된 기록 **88,710건**이 있습니다. [운영 우수성의 API 기록](01-operational-excellence.md#43-시스템-로그와-api-기록-수집) |
| API 전용 로그 | 서울 `/arcamap/api/application` | 30일 보존 설정이며 스트림은 없습니다. API 프로세스 출력은 시스템 로그에 수집됩니다. |
| DB 로그 | 서울 `/aws/rds/instance/arcamap-postgres/postgresql`의 `arcamap-postgres` 스트림과 별도 `upgrade` 그룹 | 30일입니다. PostgreSQL 기록은 있고 upgrade 그룹에는 스트림이 없습니다. |
| 이미지 빌드 로그 | 서울 `/aws/imagebuilder/arcamap-api`의 버전별 스트림 | 30일입니다. 1.0.0·1.1.0·1.1.1·1.1.2의 빌드 기록이 있습니다. |
| CloudFront 접근 로그 | 서울 [CloudFront 로그 버킷](../../terraform/modules/cloudfront/main.tf#L183)의 배포별 압축 객체 | 30일 만료입니다. 공통 기간의 응답 완료 시각에 해당하는 요청 **14,181건**이 있습니다. [성능 분석의 접근 로그](04-performance-efficiency.md#45-cloudfront-캐시-결과와-콘텐츠별-응답-성능) |
| 관리 이벤트 | 서울·버지니아 CloudTrail Event history | WAF 생성·CloudFront 연결·로그 설정 이력이 있습니다. 분산 추적 자료는 미확인입니다. |

> **보안 기록의 제약**: API 기록의 인증·인가 결과와 민감정보 포함 여부, DB 감사 범위는 로그 스키마 자료가 없어 확인하기 어렵습니다. CloudWatch 로그 그룹에는 삭제 보호가 없고 변경 불가능한 보존·외부 복제 자료도 없어, 장기 증거 보존에는 제약이 있습니다.

## 2. [Pillar Principles(기둥의 원칙에 따른 검토)](https://docs.aws.amazon.com/wellarchitected/latest/framework/security.html)

보안 기둥은 **데이터·시스템·자산을 보호하는 능력**을 다룹니다. [공식 정의](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec-def.html)는 보안 기반, 자격 증명·접근 관리, 탐지, 인프라 보호, 데이터 보호, 사고 대응, 애플리케이션 보안을 포함합니다. ArcaMap은 관리형 서비스의 보호 기능과 함께 EC2 소프트웨어·인력 권한·데이터 취급·사고 대응을 관리해야 합니다.

| [공식 설계 원칙](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec-design.html) | 현재 구성 | 운영상 과제 |
|---|---|---|
| Implement a strong identity foundation | 서비스 역할을 분리하고 지정 Secret 접근과 MFA를 사용합니다. | 인력의 중앙 인증과 직무별 권한을 적용해 상시 관리자 권한을 줄여야 합니다. [접근 권한](#sec-f03) |
| Maintain traceability | WAF·ALB·API·DB와 관리 이벤트의 기록이 있습니다. | 장기 기록과 담당자 통지를 연결해야 합니다. [보안 기록](#sec-f02) |
| Apply security at all layers | 네트워크 계층·보안 그룹·OAC·IMDSv2·암호화를 적용합니다. | WAF 검사는 정적 경로에 한정되며 규칙 일치 요청을 차단하지 않습니다. [WAF](#sec-f01) |
| Automate security best practices | Terraform으로 주요 통제를 정의하고 이미지 생성 때 실행 환경을 시험합니다. | 의존성 서명 검증을 보완하고 지속적인 취약점 관리 기록을 연결해야 합니다. [이미지 보호](#sec-f05) |
| Protect data in transit and at rest | 공개 TLS와 EBS·RDS·S3 암호화를 사용합니다. | EBS 기본 암호화·S3 전송 조건과 내부 HTTP의 보호 요구를 정해야 합니다. [암호화](#sec-f04) |
| Keep people away from data | 서비스 역할이 Secret을 읽고 실행용 인증정보를 메모리 파일시스템에 보관하도록 이미지를 구성합니다. | 사람의 데이터 접근은 상시 관리자 권한으로 열려 있습니다. [접근 권한](#sec-f03) |
| Prepare for security events | 로그·Session Manager·DB 백업이 조사와 복구 수단을 제공합니다. | 사고 계획·담당자·훈련 기록이 부족해 대응 준비 수준은 미확인입니다. [운영 정책과 대응](#sec-f06) |

## 3. [Questions and Best Practices(질문 및 모범 사례별 상세 점검)](https://docs.aws.amazon.com/wellarchitected/latest/framework/a-security.html)

[공식 질문·BP](https://docs.aws.amazon.com/wellarchitected/latest/framework/appendix.html)는 보안 질문 **11개·모범 사례 63개**로 구성됩니다.

### 3.1 워크로드 보안 운영(SEC01)

[SEC 1. How do you securely operate your workload?](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec-01.html)

**부분 충족** — 기본 접근 통제와 위협 검사는 있으며 WAF의 규칙 일치 요청 차단은 적용하지 않습니다.

| 공식 BP·명칭 | 점검 기준 | 현재 상태 | 확인 근거 | 판정 | 판정 사유 |
|---|---|---|---|---|---|
| [SEC01-BP01 Separate workloads using accounts](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_securely_operate_multi_accounts.html) | 워크로드·환경·클라우드 운영을 계정 경계로 격리합니다. | 환경별 격리 기준과 배치 자료는 미확인입니다. | [운영 정책·대응](#sec-f06) | **확인 불가** | 격리해야 할 환경과 실제 배치를 대조할 근거가 부족합니다. |
| [SEC01-BP02 Secure account root user and properties](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_securely_operate_aws_account.html) | 루트 액세스 키를 없애고 MFA·사용 감시·복구 절차를 갖춥니다. | 루트 MFA는 활성이고 액세스 키는 없습니다. 루트 사용 CloudWatch 경보는 없습니다. | [접근 권한](#sec-f03) | **확인 불가** | 외부 탐지·통지, 루트 사용 통제와 복구 절차의 운영 기록이 부족합니다. |
| [SEC01-BP03 Identify and validate control objectives](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_securely_operate_control_objectives.html) | 위협·사업 요구에 맞는 통제 목표를 정의하고 검증합니다. | 접근 통제는 적용돼 있으며 승인된 보안 목표는 미확인입니다. | [운영 정책·대응](#sec-f06) | **확인 불가** | 사업·규제 요구에 맞는 통제 범위와 효과를 판단할 기준이 부족합니다. |
| [SEC01-BP04 Stay up to date with security threats and recommendations](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_securely_operate_updated_threats.html) | 최신 위협 정보를 확보하고 탐지·완화에 반영합니다. | 관리형 WAF 규칙으로 검사하며 Count 모드를 사용합니다. | [WAF](#sec-f01) | **부분 충족** | 위협 규칙을 활용하지만 일치 요청을 차단하지 않습니다. |
| [SEC01-BP05 Reduce security management scope](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_securely_operate_reduce_management_scope.html) | 공동 책임·보안 관리 부담을 고려해 관리형 서비스를 선택합니다. | RDS·S3·CloudFront·ACM을 사용합니다. | [리소스 구성](#sec-resources) | **확인 불가** | 서비스 선택 시 보안 책임·관리 부담을 검토한 기록이 부족합니다. |
| [SEC01-BP06 Automate deployment of standard security controls](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_securely_operate_automate_security_controls.html) | 표준 통제를 코드화하고 시험·승인·배포를 자동화합니다. | 보안 그룹·IAM·S3·WAF를 Terraform으로 정의합니다. | [리소스 구성](#sec-resources) | **확인 불가** | 변경 검사·승인·자동 배포의 실행 기록이 부족합니다. |
| [SEC01-BP07 Identify threats and prioritize mitigations using a threat model](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_securely_operate_threat_model.html) | 위협 모델을 유지하고 완화 우선순위를 정합니다. | WAF는 도입 때부터 Count이며 위협 모델은 미확인입니다. | [운영 정책·대응](#sec-f06) | **확인 불가** | 위험 수용 기준과 완화 우선순위의 근거가 부족합니다. |
| [SEC01-BP08 Evaluate and implement new security services and features regularly](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_securely_operate_implement_services_features.html) | 새 보안 서비스·기능을 정기적으로 평가합니다. | 현재 보안 서비스 설정은 있으나 정기 평가 기록은 미확인입니다. | [운영 정책·대응](#sec-f06) | **확인 불가** | 새 기능의 도입·미도입을 결정하는 검토 이력이 부족합니다. |

### 3.2 사람과 기계의 인증(SEC02)

[SEC 2. How do you manage authentication for people and machines?](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec-02.html)

**부분 충족** — 역할·MFA·Secret을 사용하지만 인력의 중앙 인증과 그룹·속성 기반 권한 부여는 없습니다.

| 공식 BP·명칭 | 점검 기준 | 현재 상태 | 확인 근거 | 판정 | 판정 사유 |
|---|---|---|---|---|---|
| [SEC02-BP01 Use strong sign-in mechanisms](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_identities_enforce_mechanisms.html) | MFA를 필수로 사용하고 강한 암호 정책·이상 로그인 탐지를 적용합니다. | 루트·사용자 MFA가 등록돼 있고 IAM 기본 암호 정책을 사용합니다. 로그인 CloudWatch 경보는 없습니다. | [접근 권한](#sec-f03) | **확인 불가** | MFA 강제와 로그인 이상 탐지의 운영 근거가 부족합니다. |
| [SEC02-BP02 Use temporary credentials](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_identities_unique.html) | 사용자·서비스 인증에는 가능한 한 임시 자격 증명을 사용합니다. | EC2는 역할의 임시 자격 증명을 사용합니다. 인력의 자격 증명 수명은 미확인입니다. | [접근 권한](#sec-f03) | **확인 불가** | 인력 접근에 사용하는 키·세션의 수명과 발급 기록이 부족합니다. |
| [SEC02-BP03 Store and use secrets securely](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_identities_secrets.html) | 인증정보를 암호화해 보관하고 접근 제한·감사·교체를 적용합니다. | Secret 보관과 서비스별 읽기 권한은 있으며 사람은 상시 관리자 권한을 보유합니다. | [접근 권한](#sec-f03) | **부분 충족** | 비밀을 전용 저장소에 보관하지만 인력의 접근 범위가 넓습니다. |
| [SEC02-BP04 Rely on a centralized identity provider](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_identities_identity_provider.html) | 인력 인증을 중앙 인증 제공자와 통합합니다. | IAM 사용자 한 명을 사용하며 SAML·OIDC·Identity Center 연동은 없습니다. | [접근 권한](#sec-f03) | **미충족** | 현재 인력 접근 경로에 중앙 인증 제공자를 연결하지 않습니다. |
| [SEC02-BP05 Audit and rotate credentials periodically](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_identities_audit.html) | 장기 자격 증명의 사용과 교체를 정기적으로 감사합니다. | Secret 자동 교체 설정은 없고 수동 교체·키 감사 기록은 미확인입니다. | [접근 권한](#sec-f03) | **확인 불가** | 장기 자격 증명의 실제 교체·감사 주기를 판단할 기록이 부족합니다. |
| [SEC02-BP06 Employ user groups and attributes](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_identities_groups_attributes.html) | 그룹·속성으로 직무별 권한을 부여합니다. | 그룹 없이 사용자에게 `AdministratorAccess`를 직접 부여합니다. | [접근 권한](#sec-f03) | **미충족** | 인력 권한을 그룹·속성으로 관리하지 않습니다. |

### 3.3 사람과 기계의 권한(SEC03)

[SEC 3. How do you manage permissions for people and machines?](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec-03.html)

**부분 충족** — 서비스별 권한은 나뉘며 사람에게는 관리자 권한을 상시 부여합니다.

| 공식 BP·명칭 | 점검 기준 | 현재 상태 | 확인 근거 | 판정 | 판정 사유 |
|---|---|---|---|---|---|
| [SEC03-BP01 Define access requirements](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_permissions_define.html) | 주체별 자원 접근 필요성과 인증·인가 방식을 정의합니다. | 운영·빌드 역할의 권한은 나뉘며 인력·DB 사용자 접근 요구는 미확인입니다. | [접근 권한](#sec-f03) | **확인 불가** | 주체별 업무와 승인된 접근 범위를 대조할 자료가 부족합니다. |
| [SEC03-BP02 Grant least privilege access](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_permissions_least_privileges.html) | 작업·자원·조건·기간을 필요한 범위로 제한합니다. | 서비스의 Secret·배포 객체 접근은 제한되며 인력의 관리자 권한은 상시입니다. | [접근 권한](#sec-f03) | **부분 충족** | 일상 업무에서 사용할 인력 권한을 좁히지 않습니다. |
| [SEC03-BP03 Establish emergency access process](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_permissions_emergency_process.html) | 정상 인증 경로 실패에 대비한 비상 접근 절차를 시험합니다. | 비상 접근의 승인·대체 인증·시험 기록은 미확인입니다. | [운영 정책·대응](#sec-f06) | **확인 불가** | 정상 인증 경로가 실패했을 때의 접근 가능성을 판단하기 어렵습니다. |
| [SEC03-BP04 Reduce permissions continuously](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_permissions_continuous_reduction.html) | 미사용 주체·권한을 지속적으로 줄입니다. | Access Analyzer는 없고 정기 권한 검토·회수 기록은 미확인입니다. | [접근 권한](#sec-f03) | **확인 불가** | 미사용 주체와 권한을 줄이는 운영 이력이 부족합니다. |
| [SEC03-BP05 Define permission guardrails for your organization](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_permissions_define_guardrails.html) | 계정·주체·리소스별로 부여 가능한 권한의 상한을 둡니다. | S3 공개 차단·비TLS 거부 정책은 있으며 사용자·서비스 역할의 권한 경계는 없습니다. | [접근 권한](#sec-f03) | **부분 충족** | 리소스 통제는 있으나 상시 관리자 권한에는 별도 상한을 두지 않습니다. |
| [SEC03-BP06 Manage access based on lifecycle](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_permissions_lifecycle.html) | 입사·직무 변경·퇴사에 맞춰 권한을 조정·회수합니다. | 인력의 권한 변경·회수 기록은 미확인입니다. | [운영 정책·대응](#sec-f06) | **확인 불가** | 직무 변경·퇴사 때 접근을 회수하는 절차와 실행 근거가 부족합니다. |
| [SEC03-BP07 Analyze public and cross-account access](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_permissions_analyze_cross_account.html) | 공개·교차 계정 접근을 지속 분석하고 승인 범위를 유지합니다. | S3는 비공개이며 CloudFront 배포 조건으로 접근을 제한합니다. | [리소스 구성](#sec-resources) | **확인 불가** | 공유 승인·지속 분석·예외 접근 알림의 운영 기록이 부족합니다. |
| [SEC03-BP08 Share resources securely within your organization](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_permissions_share_securely.html) | 내부 자원 공유를 명시적으로 제한하고 지속 감시합니다. | CloudFront와 S3 사이에 OAC·배포 조건을 적용합니다. | [리소스 구성](#sec-resources) | **확인 불가** | 내부 공유 기준과 정기 검토·변경 감시의 운영 기록이 부족합니다. |
| [SEC03-BP09 Share resources securely with a third party](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_permissions_share_securely_third_party.html) | 제삼자 접근에 임시·최소 권한·회수 절차를 적용합니다. | 운영·빌드 역할은 EC2만 신뢰하며 외부 업체의 접근 자료는 미확인입니다. | [운영 정책·대응](#sec-f06) | **확인 불가** | 제삼자 관여 범위와 권한 승인·회수 기록이 부족합니다. |

### 3.4 보안 이벤트 탐지와 조사(SEC04)

[SEC 4. How do you detect and investigate security events?](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec-04.html)

**부분 충족** — 서비스 기록은 남지만 장기 관리 기록·네트워크 흐름·운영자 통지는 제한됩니다.

| 공식 BP·명칭 | 점검 기준 | 현재 상태 | 확인 근거 | 판정 | 판정 사유 |
|---|---|---|---|---|---|
| [SEC04-BP01 Configure service and application logging](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_detect_investigate_events_app_service_logging.html) | 조사에 필요한 서비스·애플리케이션 보안 기록을 보존합니다. | WAF·ALB·API·DB 기록을 수집하며 별도 Trail·Flow Logs는 없습니다. | [보안 기록](#sec-f02) | **부분 충족** | 서비스 기록은 있으나 장기 관리 기록과 네트워크 흐름 기록은 제한됩니다. |
| [SEC04-BP02 Capture logs, findings, and metrics in standardized locations](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_detect_investigate_events_logs.html) | 로그·탐지·지표를 정해진 위치에 모아 분석·대응에 연결합니다. | CloudWatch·S3에 로그를 모으지만 운영 경보의 알림은 비활성화돼 있습니다. | [보안 기록](#sec-f02) | **부분 충족** | 수집한 기록과 운영자 통지를 연결하는 경보 동작이 없습니다. |
| [SEC04-BP03 Correlate and enrich security alerts](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_detect_investigate_events_security_alerts.html) | 보안 경보를 자동으로 연관 분석하고 주체·자원 정보를 보강합니다. | WAF 기록은 있으며 보안 경보 연관 분석 자료는 미확인입니다. | [운영 정책·대응](#sec-f06) | **확인 불가** | 요청·주체·자원 정보를 결합한 분석 실행 기록이 부족합니다. |
| [SEC04-BP04 Initiate remediation for non-compliant resources](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_detect_investigate_events_noncompliant_resources.html) | 비준수 탐지와 검증된 수정 절차를 연결합니다. | Config recorder·SSM association은 없고 별도 정책 검사·수정 기록은 미확인입니다. | [관측 구성](#sec-observability) | **확인 불가** | 비준수 자원의 탐지부터 수정까지 이어지는 실행 근거가 부족합니다. |

### 3.5 네트워크 자원 보호(SEC05)

[SEC 5. How do you protect your network resources?](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec-05.html)

**부분 충족** — 네트워크 계층을 분리하며 외부 통신 목적지와 검사·차단 범위에는 공백이 있습니다.

| 공식 BP·명칭 | 점검 기준 | 현재 상태 | 확인 근거 | 판정 | 판정 사유 |
|---|---|---|---|---|---|
| [SEC05-BP01 Create network layers](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_network_protection_create_layers.html) | 인터넷 진입점·처리·저장 계층을 분리합니다. | 퍼블릭·API·DB 서브넷과 계층별 라우팅을 구분합니다. | [리소스 구성](#sec-resources) | **충족** | 공개 진입점·처리·저장 계층에 맞는 통신 경계를 적용합니다. |
| [SEC05-BP02 Control traffic flow within your network layers](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_network_protection_layered.html) | 계층 간·외부 통신을 필요한 흐름으로 제한합니다. | ALB→API 8080·API→DB 5432를 허용하며 API의 외부 HTTPS 목적지는 제한하지 않습니다. | [리소스 구성](#sec-resources) | **부분 충족** | 내부 통신은 제한하지만 외부 목적지를 필요한 서비스로 좁히지 않습니다. |
| [SEC05-BP03 Implement inspection-based protection](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_network_protection_inspection.html) | 내용·위협 정보·기준 동작에 따른 검사와 허용·거부를 적용합니다. | CloudFront의 WAF는 Count이며 API ALB에는 연결하지 않습니다. | [WAF](#sec-f01) | **부분 충족** | 정적 경로의 검사는 있지만 규칙 일치 요청 차단과 API 진입점 검사는 없습니다. |
| [SEC05-BP04 Automate network protection](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_network_auto_protect.html) | 네트워크 통제의 시험·배포·구성 이탈 탐지를 자동화합니다. | 보안 그룹·WAF를 Terraform으로 정의합니다. | [리소스 구성](#sec-resources) | **확인 불가** | 변경 시험·자동 배포·구성 이탈 탐지의 실행 기록이 부족합니다. |

### 3.6 컴퓨팅 자원 보호(SEC06)

[SEC 6. How do you protect your compute resources?](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec-06.html)

**부분 충족** — 이미지 강화·시험은 있으며 설치 파일의 서명 검증 범위는 제한됩니다.

| 공식 BP·명칭 | 점검 기준 | 현재 상태 | 확인 근거 | 판정 | 판정 사유 |
|---|---|---|---|---|---|
| [SEC06-BP01 Perform vulnerability management](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_protect_compute_vulnerability_management.html) | 호스트·코드·의존성의 취약점을 정기 검사하고 우선순위에 따라 패치합니다. | Inspector 검사는 비활성이고 별도 취약점 검사·패치 기록은 미확인입니다. | [이미지 보호](#sec-f05) | **확인 불가** | 검사 주기·발견 사항·패치 완료 여부를 판단할 자료가 부족합니다. |
| [SEC06-BP02 Provision compute from hardened images](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_protect_compute_hardened_images.html) | 신뢰할 수 있는 공급원의 보안 강화 이미지를 검증·갱신해 배포합니다. | IMDSv2·암호화·비루트 실행 시험은 있으며 AWS CLI·Agent의 서명 검증은 없습니다. | [이미지 보호](#sec-f05) | **부분 충족** | 실행 환경을 강화하지만 설치 파일 전체의 공급자 서명을 검증하지 않습니다. |
| [SEC06-BP03 Reduce manual management and interactive access](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_protect_compute_reduce_manual_management.html) | 수동 접속을 비상 상황으로 제한하고 활동을 기록합니다. | SSH는 열지 않고 Session Manager를 사용하며 사람의 관리자 권한은 상시입니다. | [접근 권한](#sec-f03) | **부분 충족** | 관리 접속 경로는 제한하지만 직접 관리 권한을 비상시에만 부여하지 않습니다. |
| [SEC06-BP04 Validate software integrity](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_protect_compute_validate_software_integrity.html) | 공급원과 암호학적 서명으로 소프트웨어 무결성을 확인합니다. | 앱·uv·RDS CA의 해시를 검사하며 AWS CLI·Agent의 서명 검증은 없습니다. | [이미지 보호](#sec-f05) | **부분 충족** | 파일 변경 검사는 일부 있으나 공급자의 암호학적 서명 검증이 빠져 있습니다. |
| [SEC06-BP05 Automate compute protection](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_protect_compute_auto_protection.html) | 검사·패치·무결성 검증·복구를 자동화합니다. | 이미지 시험을 자동화하며 예약 빌드·SSM association은 없습니다. | [이미지 보호](#sec-f05) | **부분 충족** | 빌드 시 보호는 적용하지만 설치 파일의 서명 검증 자동화가 빠져 있습니다. |

### 3.7 데이터 분류(SEC07)

[SEC 7. How do you classify your data?](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec-07.html)

**확인 불가** — 데이터 분류·소유자·취급 기준이 없어 현재 보호 설정의 적합성을 판단하기 어렵습니다.

| 공식 BP·명칭 | 점검 기준 | 현재 상태 | 확인 근거 | 판정 | 판정 사유 |
|---|---|---|---|---|---|
| [SEC07-BP01 Understand your data classification scheme](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_data_classification_identify_data.html) | 데이터의 민감도·소유자·취급·규제 요건을 정의합니다. | 웹·사진·지도·DB·비밀·로그의 저장 위치를 구분합니다. | [운영 정책·대응](#sec-f06) | **확인 불가** | 민감도·소유자·취급 요구를 정한 분류 정책이 부족합니다. |
| [SEC07-BP02 Apply data protection controls based on data sensitivity](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_data_classification_define_protection.html) | 민감도에 맞는 저장·처리·접근 통제와 감시를 적용합니다. | 비공개 S3·암호화·Secret 분리를 적용합니다. | [암호화](#sec-f04) | **확인 불가** | 민감도별 요구사항이 없어 통제의 적합성을 판단하기 어렵습니다. |
| [SEC07-BP03 Automate identification and classification](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_data_classification_auto_classification.html) | 민감 정보 식별·분류·취급 위반 감지를 자동화합니다. | Macie는 비활성이며 별도 자동 분류의 실행 기록은 미확인입니다. | [운영 정책·대응](#sec-f06) | **확인 불가** | 민감정보 식별·분류·취급 위반 탐지의 운영 근거가 부족합니다. |
| [SEC07-BP04 Define scalable data lifecycle management](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_data_classification_lifecycle_management.html) | 분류에 맞는 수집·변환·보존·폐기 수명 주기를 관리합니다. | 사진 이전 버전 7일·CDN 로그 30일·WAF 로그 14일·RDS 백업 3일을 적용합니다. | [리소스 구성](#sec-resources) | **확인 불가** | 데이터별 보존·삭제 요구가 없어 설정 기간의 적합성을 판단하기 어렵습니다. |

### 3.8 저장 데이터 보호(SEC08)

[SEC 8. How do you protect your data at rest?](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec-08.html)

**부분 충족** — 운영 저장소는 암호화되며 EBS 기본 암호화와 인력의 데이터 접근 제한은 부족합니다.

| 공식 BP·명칭 | 점검 기준 | 현재 상태 | 확인 근거 | 판정 | 판정 사유 |
|---|---|---|---|---|---|
| [SEC08-BP01 Implement secure key management](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_protect_data_rest_key_mgmt.html) | 키 저장·회전·최소 권한·사용 감사를 관리합니다. | AWS 관리형 KMS 키는 활성 상태이며 365일마다 자동 회전합니다. | [암호화](#sec-f04) | **확인 불가** | 키 접근 정책과 사용 감시의 운영 근거가 부족합니다. |
| [SEC08-BP02 Enforce encryption at rest](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_protect_data_rest_encrypt.html) | 비공개 데이터를 기본 암호화하고 평문 데이터를 통제합니다. | 운영 EBS·RDS·S3는 암호화되며 서울 EBS 기본 암호화는 꺼져 있습니다. | [암호화](#sec-f04) | **부분 충족** | 시작 템플릿 밖에서 EBS를 생성할 때 기본 암호화를 적용하지 않습니다. |
| [SEC08-BP03 Automate data at rest protection](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_protect_data_rest_automate_protection.html) | 저장 통제의 자동 적용·검사·수정·백업을 운영합니다. | S3 기본 암호화·공개 차단과 RDS 자동 백업을 사용합니다. | [암호화](#sec-f04) | **부분 충족** | 일부 보호는 자동 적용하지만 EBS 기본 암호화는 꺼져 있습니다. |
| [SEC08-BP04 Enforce access control](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_protect_data_rest_access_control.html) | 격리·최소 권한·조건부 접근·버전 관리로 데이터를 보호합니다. | OAC·비공개 DB·백업·사진 버전 관리를 사용하며 사람은 상시 관리자입니다. | [접근 권한](#sec-f03) | **부분 충족** | 서비스 경계는 있으나 사람의 데이터 접근을 업무·기간으로 제한하지 않습니다. |

### 3.9 전송 데이터 보호(SEC09)

[SEC 9. How do you protect your data in transit?](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec-09.html)

**부분 충족** — 공개·DB 구간에는 TLS를 사용하며 내부 API는 HTTP로 통신합니다.

| 공식 BP·명칭 | 점검 기준 | 현재 상태 | 확인 근거 | 판정 | 판정 사유 |
|---|---|---|---|---|---|
| [SEC09-BP01 Implement secure key and certificate management](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_protect_data_transit_key_cert_mgmt.html) | 인증서 발급·키 보호·배포·갱신을 관리합니다. | 공개 종단의 ACM 인증서 두 개는 발급·연결돼 있고 자동 갱신 대상이며 키 내보내기는 비활성입니다. | [암호화](#sec-f04) | **충족** | 공개 TLS 종단에 관리형 발급·갱신과 키 보호를 적용합니다. |
| [SEC09-BP02 Enforce encryption in transit](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_protect_data_transit_encrypt.html) | 정의한 요구에 맞는 안전한 전송 암호화를 강제합니다. | 공개 HTTPS·DB TLS를 사용하며 내부 API는 HTTP입니다. S3 비TLS 거부는 배포 버킷에만 있습니다. | [암호화](#sec-f04) | **부분 충족** | 다른 네 버킷에는 비TLS 거부 정책이 없으며 내부 통신은 암호화하지 않습니다. |
| [SEC09-BP03 Authenticate network communications](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_protect_data_transit_authentication.html) | 인증을 지원하는 표준 프로토콜로 통신 상대를 검증합니다. | 공개 TLS·OAC 서명을 사용하며 내부 API 통신은 보안 그룹으로 제한합니다. | [암호화](#sec-f04) | **부분 충족** | 내부 HTTP 구간에는 암호학적 상대 인증이 없습니다. |

### 3.10 보안 사고 예상·대응·복구(SEC10)

[SEC 10. How do you anticipate, respond to, and recover from incidents?](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec-10.html)

**확인 불가** — 대응 계획·담당자·훈련·포렌식 운영 기록이 부족합니다.

| 공식 BP·명칭 | 점검 기준 | 현재 상태 | 확인 근거 | 판정 | 판정 사유 |
|---|---|---|---|---|---|
| [SEC10-BP01 Identify key personnel and external resources](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_incident_response_identify_personnel.html) | 사고 담당자·외부 지원과 연락·보고 경로를 정합니다. | 사고 담당자·외부 지원·연락망 자료는 미확인입니다. | [운영 정책·대응](#sec-f06) | **확인 불가** | 사고 발생 시 연락과 의사결정 책임을 판단할 근거가 부족합니다. |
| [SEC10-BP02 Develop incident management plans](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_incident_response_develop_management_plans.html) | 탐지·분석·격리·복구를 포함한 사고 대응 계획을 유지합니다. | 로그와 복구 수단은 있으며 보안 사고 대응 계획은 미확인입니다. | [운영 정책·대응](#sec-f06) | **확인 불가** | 탐지·분석·격리·복구의 절차와 책임 자료가 부족합니다. |
| [SEC10-BP03 Prepare forensic capabilities](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_incident_response_prepare_forensic.html) | 사전에 증거 수집·보존·분석 역량을 준비합니다. | 서비스 로그·관리 이벤트·DB 백업은 있으며 별도 Trail·Flow Logs는 없습니다. | [보안 기록](#sec-f02) | **부분 충족** | 조사 수단은 있으나 장기 관리 기록과 네트워크 흐름 증거가 제한됩니다. |
| [SEC10-BP04 Develop and test security incident response playbooks](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_incident_response_playbooks.html) | 사고 유형별 대응 절차를 작성하고 시험합니다. | 사고 유형별 대응 절차와 시험 결과는 미확인입니다. | [운영 정책·대응](#sec-f06) | **확인 불가** | 실제 상황에서 절차를 실행할 수 있는지 판단할 근거가 부족합니다. |
| [SEC10-BP05 Pre-provision access](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_incident_response_pre_provision_access.html) | 사고 대응 접근을 미리 준비하고 통제·시험합니다. | 일반 관리자·EC2 역할은 있으며 대응 전용 접근의 승인·시험 기록은 미확인입니다. | [접근 권한](#sec-f03) | **확인 불가** | 사고 대응 권한의 범위·기간과 사전 준비 상태를 판단하기 어렵습니다. |
| [SEC10-BP06 Pre-deploy tools](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_incident_response_pre_deploy_tools.html) | 조사·격리·복구 도구를 사전 배치·검증합니다. | Session Manager와 로그를 사용하며 대응 도구의 준비 시험은 미확인입니다. | [운영 정책·대응](#sec-f06) | **확인 불가** | 조사·격리·복구 도구의 가용성을 판단할 시험 기록이 부족합니다. |
| [SEC10-BP07 Run simulations](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_incident_response_run_game_days.html) | 실제와 유사한 보안 사고 대응 훈련을 반복합니다. | 보안 사고 대응 훈련 기록은 미확인입니다. | [운영 정책·대응](#sec-f06) | **확인 불가** | 반복 훈련과 발견 과제의 조치 이력이 부족합니다. |
| [SEC10-BP08 Establish a framework for learning from incidents](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_incident_response_establish_incident_framework.html) | 사고 회고·원인 분석·개선 추적 체계를 유지합니다. | 보안 사고 회고·원인 분석·개선 추적 기록은 미확인입니다. | [운영 정책·대응](#sec-f06) | **확인 불가** | 사고에서 얻은 교훈을 운영에 반영하는 체계의 근거가 부족합니다. |

### 3.11 개발·배포 과정의 애플리케이션 보안(SEC11)

[SEC 11. How do you incorporate and validate the security properties of applications throughout the design, development, and deployment lifecycle?](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec-11.html)

**확인 불가** — 이미지 시험 외에 개발 보안 검사·독립 검토·교육·침투 시험 기록은 미확인입니다.

| 공식 BP·명칭 | 점검 기준 | 현재 상태 | 확인 근거 | 판정 | 판정 사유 |
|---|---|---|---|---|---|
| [SEC11-BP01 Train for application security](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_appsec_train_for_application_security.html) | 개발·운영 인력을 보안 교육하고 역량을 평가합니다. | 보안 교육 계획·참여·평가 자료는 미확인입니다. | [운영 정책·대응](#sec-f06) | **확인 불가** | 개발·운영 인력의 교육 이수와 역량 평가 근거가 부족합니다. |
| [SEC11-BP02 Automate testing throughout the development and release lifecycle](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_appsec_automate_testing_throughout_lifecycle.html) | 개발부터 릴리스까지 보안 시험을 자동화합니다. | 이미지의 비루트 실행·파일 권한·메모리 보관을 시험합니다. | [이미지 보호](#sec-f05) | **확인 불가** | 코드·의존성 검사와 릴리스 단계의 보안 시험 기록이 부족합니다. |
| [SEC11-BP03 Perform regular penetration testing](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_appsec_perform_regular_penetration_testing.html) | 정기 침투 시험과 발견 사항 재검증을 수행합니다. | 침투 시험 일정·보고서·조치 결과는 미확인입니다. | [운영 정책·대응](#sec-f06) | **확인 불가** | 정기 시험과 발견 사항의 재검증 근거가 부족합니다. |
| [SEC11-BP04 Conduct code reviews](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_appsec_manual_code_reviews.html) | 작성자 외의 검토와 도구로 코드 보안을 점검합니다. | 비공개 앱의 코드 검토·승인 이력은 미확인입니다. | [운영 정책·대응](#sec-f06) | **확인 불가** | 작성자 외의 보안 검토와 승인 절차의 근거가 부족합니다. |
| [SEC11-BP05 Centralize services for packages and dependencies](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_appsec_centralize_services_for_packages_and_dependencies.html) | 사전 검증한 패키지·의존성을 중앙 경로로 제공합니다. | 앱은 지정 S3 객체에서, AWS CLI·uv·Agent는 외부 공급원에서 받습니다. | [이미지 보호](#sec-f05) | **확인 불가** | 의존성의 승인·검증 정책이 없어 중앙 관리 범위를 판단하기 어렵습니다. |
| [SEC11-BP06 Deploy software programmatically](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_appsec_deploy_software_programmatically.html) | 검증한 동일 산출물을 자동 배포하고 서명을 검증합니다. | 시험한 AMI를 운영 서버에 배포하며 앱 아카이브는 해시를 검사합니다. | [이미지 보호](#sec-f05) | **부분 충족** | 이미지 배포는 자동화하지만 앱·전체 의존성의 서명 검증은 없습니다. |
| [SEC11-BP07 Regularly assess security properties of the pipelines](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_appsec_regularly_assess_security_properties_of_pipelines.html) | 파이프라인 권한·검사·산출물 무결성을 정기 평가합니다. | 운영·빌드 역할을 분리하며 파이프라인의 정기 보안 평가 기록은 미확인입니다. | [운영 정책·대응](#sec-f06) | **확인 불가** | 권한·검사 우회 방지·산출물 보호를 정기 검토한 근거가 부족합니다. |
| [SEC11-BP08 Build a program that embeds security ownership in workload teams](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_appsec_build_program_that_embeds_security_ownership_in_teams.html) | 워크로드 팀에 보안 책임·의사결정·피드백 체계를 둡니다. | 팀의 보안 담당 역할·의사결정·피드백 기록은 미확인입니다. | [운영 정책·대응](#sec-f06) | **확인 불가** | 업무에 보안 책임을 배정하고 유지하는 운영 근거가 부족합니다. |

## 4. Findings and Insights(발견 사항 및 인사이트)

<a id="sec-f01"></a>

### 4.1 CloudFront WAF는 규칙 일치 요청을 기록하지만 차단하지 않습니다

CloudFront의 Web ACL `CreatedByCloudFront-609132c8`은 정적 콘텐츠 요청을 검사합니다. 관리형 규칙 그룹 네 개는 판정 결과를 **Count**로 기록하며 기본 동작은 **Allow**입니다. API 요청을 받는 ALB에는 WAF가 연결돼 있지 않습니다. [WAF 정의](../../terraform/modules/cloudfront/waf.tf#L29)는 이 검사 범위를 구성합니다.

공통 기간의 버지니아 CloudTrail 관리 이벤트와 WAF 로그에는 다음 도입 이력이 남아 있습니다.

| 발생 시각(KST) | 운영 이력 |
|---|---|
| 09-15 02:37 | WAF가 생성됐고 CloudFront에 연결됐습니다. 생성 때부터 네 규칙 그룹 모두 Count였습니다. |
| 09-15 02:38 | WAF 로그 수집과 인증정보 헤더 가림이 설정됐습니다. |
| 09-15 02:43 | WAF 요청 로그가 남기 시작했습니다. |

공통 기간에 이 Web ACL의 `AWS/WAFV2` 허용 요청 지표인 `AllowedRequests` 합계는 **8,896건**, Count 평가 지표인 `CountedRequests` 합계는 **1,400건**입니다. Count 지표는 규칙별 일치를 집계하므로 고유 공격 요청 수와 다릅니다. 같은 기간 WAF 로그 **8,891건**은 모두 최종 동작 `ALLOW`와 `Default_Action`을 기록했습니다.

[규칙 그룹의 Count 재정의](https://docs.aws.amazon.com/waf/latest/APIReference/API_OverrideAction.html)는 그룹 내부의 규칙 평가를 유지하면서 최종 결과를 Count로 바꿉니다. 내부 규칙에 차단 지표가 있더라도 이 경로의 최종 요청은 허용됩니다. **SEC01-BP04·SEC05-BP03**에 따른 현재 보호는 위협 규칙을 이용한 검사까지이며, 규칙에 일치하는 요청의 차단은 적용하지 않습니다.

> **기록 범위의 제약**: WAF 도입 전과 9월 15일 02:43 이전의 요청 기록은 없어 앞선 구간의 위협을 추적하기 어렵습니다. 9월 15일의 허용 지표와 로그에는 5건의 차이가 있으며 원인은 미확인입니다. 침해 여부를 판단할 후속 조사 기록도 없습니다.

차단을 적용하려면 정상 요청과 오탐을 구분할 기준, 통지 담당자와 되돌림 조건을 먼저 정해야 합니다. API 진입점의 검사 범위도 함께 정하면 공개 경로의 보호 공백을 줄일 수 있습니다. 규칙을 바꿀 때는 정상 콘텐츠·API 요청의 가용성을 유지해야 합니다.

<a id="sec-f02"></a>

### 4.2 서비스 기록은 남지만 장기 보안 조사와 담당자 통지에는 공백이 있습니다

**API 프로세스 기록은 시스템 로그에 수집됩니다.** 서울 `/arcamap/ec2/system`에는 공통 기간의 로그 시각을 기준으로 `arcamap-api` 또는 `uvicorn`이 포함된 기록이 **88,710건** 있습니다. 현재·이전 서버와 빌드 시간대의 여섯 스트림에 해당하며, 요청 수가 아닌 문자열 일치 이벤트 수입니다. [운영 우수성의 API 기록](01-operational-excellence.md#43-시스템-로그와-api-기록-수집)은 수집 경로와 공통 기간의 기록 범위를 설명합니다.

[수집 설정](../../terraform/env/was/main.tf#L44)은 journald를 시스템 로그 그룹으로 보냅니다. 이 경로로 API 프로세스 출력도 전달되며 `/arcamap/api/application`에는 스트림이 없습니다. 보안 조사에는 기존 기록의 요청 식별자·인증 실패·권한 거부 필드를 연결하는 것이 우선입니다. 전용 로그 그룹은 접근 권한이나 보존 기간을 다르게 운영해야 할 때 구분하면 됩니다.

CloudFront의 [접근 로그 버킷](../../terraform/modules/cloudfront/main.tf#L183)에는 공통 기간의 응답 완료 시각에 해당하는 요청 **14,181건**이 있습니다. [성능 분석의 접근 로그](04-performance-efficiency.md#45-cloudfront-캐시-결과와-콘텐츠별-응답-성능)는 로그 본문의 응답 완료 시각과 요청 지표를 연결합니다.

| 기록·확인 위치 | 공통 기간 안의 기록 시각(KST) | 조사에 사용할 수 있는 내용 |
|---|---|---|
| WAF [요청 로그](#sec-telemetry) | 09-15 02:43~09-21 23:57 | 규칙 평가와 최종 허용 결과입니다. |
| ALB `/aws/vendedlogs/elb/arcamap-api`의 접근 스트림 | 09-14 01:17~09-21 23:56 | 요청·응답 상태를 시스템 기록과 대조할 수 있습니다. |
| 시스템 로그의 API 문자열 일치 기록 | 09-14 22:34~09-21 23:59 | API 프로세스 출력과 서버별 실행 시간대를 제공합니다. |
| PostgreSQL `arcamap-postgres` 스트림 | 09-14 00:44~09-21 23:58 | API 사건과 DB 내부 기록을 연결할 수 있습니다. |
| Image Builder의 버전별 스트림 | 09-14 01:04~09-15 01:05 | 이미지 생성·시험과 배포 시점을 연결할 수 있습니다. |
| CloudFront 접근 로그 | 09-14 01:07~09-21 23:57 | 콘텐츠 요청의 응답 상태와 완료 시각을 제공합니다. |

> **사건 분석의 제약**: API 로그의 인증·인가 필드와 DB 감사 범위는 미확인입니다. CloudFront 표준 로그는 지연·누락이 가능해 전체 전달 여부와 보안 사건의 원인을 이 수집량만으로 판단하기 어렵습니다.

[CloudTrail Event history](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/view-cloudtrail-events.html)는 최근 90일의 관리 이벤트를 제공합니다. 별도 Trail·Event Data Store·VPC Flow Logs가 없어 장기 관리 작업과 네트워크 흐름을 추적할 기록은 제한됩니다. CloudWatch 로그의 보존 기간은 WAF 14일, 나머지 서비스 30일이며 삭제 보호는 설정하지 않습니다.

운영 경보 9개는 알림을 보내지 않고, 목표 추적 경보 2개는 서버 용량만 조절합니다. WAF 경보도 없습니다. **SEC04-BP01·BP02, SEC10-BP03**의 관점에서는 기록 수집을 담당자 통지·조사·증거 보존으로 연결해야 합니다. 사건별 보존 요건과 필요한 보안 필드를 정하고 기존 로그를 활용하면 중복 수집을 줄이면서 접근 경로를 추적할 수 있습니다. 민감정보 노출과 불필요한 장기 보관을 줄이도록 열람 권한과 만료 기준도 함께 정해야 합니다.

<a id="sec-f03"></a>

### 4.3 서비스별 권한은 구분되지만 사람의 관리자 권한은 상시입니다

IAM 사용자 한 명에게 MFA가 등록돼 있으며 **`AdministratorAccess`를 직접 부여**합니다. 그룹과 SAML·OIDC·Identity Center 연동은 없습니다. 사용자와 운영·빌드 역할에는 권한 경계를 설정하지 않습니다.

| 주체·보호 대상 | 현재 권한 | 운영상 의미 |
|---|---|---|
| `arcamap-api-ec2` | EC2 신뢰, SSM·CloudWatch 정책, 지정 DB Secret 읽기 | 운영 서버가 필요한 인증정보를 역할로 가져옵니다. |
| `arcamap-imagebuilder-ec2` | EC2 신뢰, 이미지 빌드·SSM·CloudWatch 정책, 지정 Secret·배포 객체 읽기, 시스템 로그 조회 | 빌드·DB 연결·로그 전달 시험에 필요한 권한을 운영 역할과 구분합니다. |
| IAM 사용자 | 상시 `AdministratorAccess` | 인프라와 데이터 서비스의 변경 권한이 일상 업무·기간별로 제한되지 않습니다. |
| S3 정책 | 공개 차단, CloudFront 배포 조건, 배포 버킷의 비TLS 거부 | 서비스의 접근 경로와 전송 조건을 제한합니다. |

서비스 권한은 [IAM 역할 정의](../../terraform/env/was/iam.tf#L1)에 대응합니다. Secrets Manager의 `arcamap/api/database`는 DB 접속 정보를 보관하며 자동 교체는 설정하지 않습니다.

루트 MFA는 활성이고 루트 액세스 키는 없습니다. IAM 사용자는 기본 암호 정책을 사용합니다. 루트 사용과 로그인 이상을 알리는 CloudWatch 경보는 없습니다. **SEC01-BP02**는 루트 사용 통제·탐지·복구를, **SEC02-BP01**은 MFA 강제·강한 암호 정책·이상 로그인 탐지를 요구합니다.

> **인증 운영 자료의 제약**: MFA 강제, 외부 탐지·통지, 루트 사용·복구 절차와 자격 증명 교체·감사 기록은 미확인입니다. 두 BP의 전체 충족 여부와 실제 인증정보 관리 주기를 판단할 근거가 부족합니다.

인력의 상시 관리자 권한은 오용이나 인증정보 노출 시 여러 서비스에 영향을 줄 수 있습니다. **SEC02-BP04·BP06, SEC03-BP02·BP05, SEC08-BP04**에 따라 일상 업무에는 직무별 권한을 부여하고 비상 작업에는 승인된 임시 권한 상승을 사용하는 방향이 적절합니다. 중앙 인증과 권한 회수를 연결하면 상시 접근 범위를 줄일 수 있으며, 비상 복구와 빌드·배포에 필요한 접근은 유지해야 합니다.

<a id="sec-f04"></a>

### 4.4 현재 저장 암호화와 모든 생성·통신 경로의 강제 범위는 다릅니다

운영 서버의 EBS와 RDS는 암호화되며 S3 다섯 버킷에는 기본 암호화가 적용됩니다. EBS·RDS·Secrets Manager의 AWS 관리형 KMS 키는 활성 상태이며 **365일 자동 회전**을 사용합니다.

| 보호 경로 | 현재 통제 | 보호 범위 |
|---|---|---|
| EBS 생성 | [시작 템플릿](../../terraform/modules/compute/main.tf#L15)이 암호화를 지정합니다. | 서울의 EBS 기본 암호화는 꺼져 있어 템플릿 밖의 생성 경로에는 자동 적용되지 않습니다. |
| 인터넷→CloudFront·ALB | HTTPS 전환과 ACM 인증서를 사용합니다. | 공개 연결을 암호화하며 인증서는 자동 갱신 대상·키 내보내기 비활성 상태입니다. |
| CloudFront→S3 | OAC가 SigV4로 요청에 서명합니다. | 지정 배포의 오리진 요청을 인증합니다. |
| ALB→API | [대상 그룹](../../terraform/modules/alb/main.tf#L14)은 HTTP 8080을 사용합니다. | 보안 그룹으로 연결을 제한하지만 구간 암호화·암호학적 상대 인증은 없습니다. |
| API→RDS | `rds.force_ssl=1`과 최소 TLS 1.2를 적용합니다. | DB 서버가 TLS 연결을 요구합니다. |
| S3 접근 | [배포 버킷 정책](../../terraform/env/was/deployment.tf#L12)은 비TLS 요청을 거부합니다. | 다른 네 버킷에는 같은 거부 정책이 없습니다. |

> **보호 요건의 제약**: 데이터 민감도·위험 수용 기준과 DB 클라이언트의 인증서 검증 설정은 미확인입니다. 내부 HTTP의 허용 여부와 DB 상대 인증 수준을 판단하기 어렵습니다. 키 접근·사용 감시 자료도 부족해 **SEC08-BP01**은 확인 불가입니다.

**SEC08-BP02·BP03, SEC09-BP02·BP03**에 따라 EBS 생성 기본값과 S3 전송 정책을 맞추면 새 리소스나 다른 접근 경로에서 보호를 빠뜨릴 가능성을 줄일 수 있습니다. 내부 TLS는 전송 기밀성과 상대 인증을 강화합니다. 적용 범위는 데이터 보호 요건에 맞춰 정하고, 기존 클라이언트·로그 전달·헬스 체크와 인증서 갱신을 유지해야 합니다.

<a id="sec-f05"></a>

### 4.5 이미지 시험은 있지만 의존성 서명 검증과 배포 후 보호의 증거는 제한됩니다

Image Builder `arcamap-api/1.1.2/1`은 시험을 활성화한 **AVAILABLE** 이미지이며 운영 서버 두 대가 출력 AMI를 사용합니다. 등록된 이미지 구성은 비루트 실행, 인증정보의 메모리 보관, 기능·로그 전달을 시험합니다.

| 보호 대상 | 이미지의 동작 | 남은 보완 사항 |
|---|---|---|
| 앱·uv·RDS CA 파일 | SHA-256 해시로 파일 변경을 검사합니다. | 공급자의 암호학적 서명 검증이 필요합니다. |
| AWS CLI·CloudWatch Agent | HTTPS로 설치 파일을 받고 Agent 버전·아키텍처를 검사합니다. | 설치 파일의 서명 검증 단계가 없습니다. |
| 실행 중 인증정보 | `/run/arcamap/runtime.env`의 소유자·권한과 메모리 파일시스템인 tmpfs 사용을 시험합니다. | 운영 중의 변경 감시 자료는 미확인입니다. |
| 실행 주체·기능 | 비루트 사용자와 자동 시작, `/health`·`/health/db`를 시험합니다. | 애플리케이션 인증·인가와 코드·의존성 보안 검사 기록은 미확인입니다. |
| 로그 전달 | journald 시험 기록의 CloudWatch 도착을 시험합니다. | API 보안 필드의 충분성은 미확인입니다. |

이 동작은 [FastAPI 설치·시험](../../terraform/modules/image-builder/fastapi.tf#L18)과 [기본 Agent 설치](../../terraform/modules/image-builder/main.tf#L36)에 정의돼 있습니다. **SEC06-BP02·BP04, SEC11-BP06**에서 요구하는 공급원·무결성 보호에는 설치 파일의 서명 검증이 빠져 있습니다.

Image Builder의 예약 빌드와 SSM association은 없으며 Inspector 검사는 비활성화돼 있습니다. 외부 스캐너·수동 패치·별도 CI의 실행 기록이 없어 배포 후 취약점 관리 주기와 조치 상태는 미확인입니다.

현재 이미지 시험을 유지하면서 승인 공급원과 서명 검증을 연결하고, 취약점 발견 시 이미지 재생성·배포까지 이어지도록 해야 합니다. 이를 통해 변조 파일의 설치와 취약한 이미지의 장기 사용을 줄일 수 있습니다. 서명 검증 실패 시 배포를 중단하고 복구 가능한 기존 이미지를 유지해야 합니다.

<a id="sec-f06"></a>

### 4.6 운영 정책과 대응 기록의 부족으로 보안 적합성을 확정하기 어렵습니다

보안 목표와 데이터 취급 기준이 있어야 WAF 차단 범위·내부 TLS·로그 보존 기간을 서비스에 맞게 정할 수 있습니다. [프로젝트 운영 기준](../../README.md#4-operational-criteria-and-constraints운영-기준-및-제약)은 요청 경로·접근 제약·복구 수단을 설명하며, 다음 운영 자료는 미확인입니다.

| 필요한 운영 자료 | 관련 기준 | 판단에 미치는 영향 |
|---|---|---|
| 환경 격리 기준·배치, 보안 목표·위협 모델·위험 수용 | SEC01 | 격리·검사·차단 범위의 적합성과 우선순위를 판단하기 어렵습니다. |
| 데이터 분류·소유자·취급·보존 정책 | SEC07 | 민감도별 보호와 보존·폐기 요건을 현재 설정과 대조하기 어렵습니다. |
| 인력 접근·자격 증명 교체·공유·비상 접근 기록 | SEC02·SEC03 | 정기 권한 축소, 교체, 회수와 비상 접근의 실행 여부가 불명확합니다. |
| 사고 계획·담당자·포렌식·훈련·회고 | SEC10 | 사고 시 실행 능력과 대응 시간을 판단하기 어렵습니다. |
| 취약점 관리·코드 검토·교육·침투 시험·배포 승인 | SEC06·SEC11 | 개발부터 운영까지 이어지는 보안 검사와 조치 수준이 불명확합니다. |

통제 목표·데이터 분류와 일상·비상 접근 기준을 먼저 정리하면 보호 범위와 보존 부담을 함께 결정할 수 있습니다. 기존 운영 절차와 실행 기록을 연결해 필요한 통제부터 보완하는 것이 적절합니다.

## 5. Conclusion(결론)

ArcaMap은 **네트워크 계층 분리·역할별 권한·비공개 S3·저장 암호화·공개 HTTPS**로 시스템과 데이터를 보호합니다. WAF는 정적 콘텐츠 요청을 검사하며 규칙에 일치한 요청도 허용합니다. API 진입점의 검사, 사람의 상시 관리자 권한, 장기 기록과 운영자 통지는 우선 보완할 영역입니다.

[WAF 검사·차단 범위](#sec-f01), [보안 기록과 통지](#sec-f02), [일상·비상 권한 구분](#sec-f03)을 먼저 정하고, [암호화 적용 범위](#sec-f04)와 [이미지 서명 검증·취약점 관리](#sec-f05)를 연결해야 합니다. 정상 요청·배포·복구 경로를 유지하면서 공개 접근과 상시 권한의 영향을 줄이는 방향입니다.

공식 63개 BP의 판정은 **충족 2개·부분 충족 19개·미충족 2개·해당 없음 0개·확인 불가 40개**입니다. [데이터 분류·권한 검토·사고 대응·개발 보안의 운영 기록](#sec-f06)이 부족해 통제의 적합성과 실제 대응 능력은 미확인입니다.
