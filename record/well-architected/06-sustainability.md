# Sustainability(지속 가능성)

**🌱 CloudFront가 콘텐츠를 캐시하고 두 가용 영역의 API·RDS가 요청 처리와 데이터 저장을 담당합니다**

ArcaMap은 S3의 웹·지도 콘텐츠를 CloudFront로 제공하고 API는 EC2 두 대와 RDS PostgreSQL을 사용합니다. API 용량은 CPU 부하에 따라 조절하며 로그와 사진의 이전 버전은 정해진 기간이 지나면 삭제합니다. 수요에 맞는 자원 규모와 보존 범위가 지속 가능성의 주요 운영 과제입니다.

**공통 집계 기간**은 **2026-09-14 00:00:00 이상, 2026-09-22 00:00:00 미만(KST)**입니다. **구성 확인 시점**은 **2026-09-22 15:46~15:57(KST)**입니다. 날짜와 시각은 모두 KST입니다.

[현재 운영 현황](#1-current-operations현재-운영-현황) · [기둥의 원칙](#2-pillar-principles기둥의-원칙에-따른-검토) · [질문 및 모범 사례](#3-questions-and-best-practices질문-및-모범-사례별-상세-점검) · [발견 사항 및 인사이트](#4-findings-and-insights발견-사항-및-인사이트) · [결론](#5-conclusion결론)

## 1. Current Operations(현재 운영 현황)

### 1.1 리소스 구성

API·RDS·S3는 서울 리전에 있으며 CloudFront가 `arcamap.app`의 콘텐츠를 제공합니다. API 인스턴스와 RDS 주·대기 인스턴스는 두 가용 영역에 나누어 배치합니다.

| 대상 | 구성과 역할 | Terraform 정의 |
|---|---|---|
| API 실행 환경 | Auto Scaling Group(ASG) `arcamap-api`가 `t3.small`·`x86_64` 인스턴스를 `ap-northeast-2a`·`ap-northeast-2c`에 한 대씩 운영합니다. 최소·희망 용량은 **2대**, 최대 용량은 **4대**입니다. | [시작 템플릿](../../terraform/modules/compute/main.tf#L1), [ASG](../../terraform/modules/compute/main.tf#L44) |
| 용량 조절 | `arcamap-api-cpu` 정책이 평균 CPU **50%**를 목표로 인스턴스를 늘리거나 줄입니다. 신규 인스턴스의 워밍업은 **300초**입니다. | [CPU 목표 추적 정책](../../terraform/modules/compute/main.tf#L81) |
| API 저장소 | 인스턴스마다 gp3 **20GiB**를 사용하며 인스턴스 종료 시 삭제합니다. | [블록 장치](../../terraform/modules/compute/main.tf#L14) |
| 관계형 데이터 | `arcamap-postgres`는 PostgreSQL **17.11**, `db.t4g.medium`, **Multi-AZ** 구성입니다. gp3 **20GiB**를 사용하고 최대 **100GiB**까지 자동 확장합니다. 자동 백업은 **3일** 보존합니다. | [RDS](../../terraform/modules/database/main.tf#L6), [DB 루트 모듈](../../terraform/env/db/main.tf#L72) |
| 요청 분산·통신 | ALB `arcamap-api`가 두 가용 영역의 API로 요청을 전달합니다. API는 같은 가용 영역의 NAT Gateway로 외부에 연결하고 DB는 VPC 내부에서 통신합니다. | [ALB·대상 그룹](../../terraform/modules/alb/main.tf#L1), [NAT·라우팅](../../terraform/modules/network/main.tf#L62) |
| 콘텐츠 제공 | CloudFront `E39UQTOCMBVZB3`는 웹 파일·사진·지도의 S3 오리진을 사용합니다. 사진 경로는 `/photos/*`, 지도 경로는 `/20260907.pmtiles`입니다. | [CloudFront 배포](../../terraform/modules/cloudfront/main.tf#L60) |
| 캐시·압축 | 기본·최대 캐시 유지 시간(TTL)은 웹 파일 **300초**, 지도·사진 **86,400초**입니다. 웹 파일은 자동 압축을 사용하고 지도·사진 경로는 사용하지 않습니다. | [웹 캐시 정책](../../terraform/modules/cloudfront/main.tf#L12), [미디어 캐시 정책](../../terraform/modules/cloudfront/main.tf#L36) |
| 이미지 빌드 | Image Builder `arcamap-api/1.1.2/1`이 임시 `t3.small`에서 이미지를 빌드·시험합니다. 실패 시 빌드 인스턴스를 종료하며 완성된 AMI는 운영 API 두 대가 사용합니다. | [빌드 인프라](../../terraform/modules/image-builder/main.tf#L232), [이미지 생성](../../terraform/modules/image-builder/main.tf#L246) |

S3는 웹·지도·사진 원본과 배포 파일·접근 로그를 용도별로 보관합니다. **사진은 이전 버전을 7일간 보존**하고 CloudFront 접근 로그는 **30일 후 삭제**합니다.

| 저장 역할 | 버전 관리·보존 설정 | Terraform 정의 |
|---|---|---|
| 웹 파일 | 버전 관리·수명 주기 정책이 없습니다. | [웹 버킷의 `static`](../../terraform/env/web/main.tf#L14) |
| 지도 | 기존 지도 버킷을 사용하며 버전 관리·수명 주기 정책이 없습니다. | [지도 버킷 참조](../../terraform/env/web/main.tf#L3) |
| 사진 | 버전 관리를 사용하며 이전 버전은 7일 후 만료합니다. 만료된 삭제 마커도 정리합니다. | [웹 버킷의 `photos`](../../terraform/env/web/main.tf#L14), [수명 주기](../../terraform/modules/s3-bucket/main.tf#L43) |
| 배포 아카이브 | 버전 관리·수명 주기 정책이 없으며 배포 객체는 Terraform으로 관리합니다. | [배포 버킷·객체](../../terraform/env/was/deployment.tf#L6) |
| CloudFront 접근 로그 | 버전 관리는 사용하지 않으며 모든 객체를 30일 후 만료합니다. | [웹 버킷의 `cloudfront_logs`](../../terraform/env/web/main.tf#L14) |

### 1.2 옵저빌리티 구성

CloudWatch는 CPU·인스턴스 상태·API 오류와 DB의 메모리·저장 공간을 관측합니다. CloudFront 접근 로그는 캐시 사용과 지도 부분 응답을 보여줍니다. [README의 지속 가능성 목표](../../README.md#3-design-principles설계-원칙)는 부하 감소 시 축소와 보존 기간이 지난 로그의 정리입니다.

| 관측 대상 | 수집·평가 설정 | 운영상 제약 |
|---|---|---|
| API 용량·가용성 | EC2·ASG·ALB 지표와 CPU 목표 추적 경보 2개를 사용합니다. 서비스 상태 경보 9개도 있습니다. | 서비스 상태 경보는 운영자에게 알림을 보내지 않습니다. |
| DB 용량 | CPU·가용 메모리·저장 공간·연결 수·I/O를 수집하고 자원 부족을 경보로 표시합니다. | Enhanced Monitoring과 Performance Insights는 비활성화돼 있어 프로세스·쿼리별 자원 분석이 제한됩니다. |
| 콘텐츠 전송·캐시 | CloudFront 요청·다운로드 지표와 S3에 저장된 CloudFront 접근 로그를 수집합니다. | 별도 캐시 적중률 지표는 없으며 실제 캐시 사용은 [접근 로그의 처리 분류](04-performance-efficiency.md#45-cloudfront-캐시-결과와-콘텐츠별-응답-성능)로 파악합니다. |
| 시스템·API·빌드 기록 | 시스템·API·Image Builder·RDS·ALB 로그는 30일, WAF 로그는 14일 보존합니다. | CloudWatch Agent는 시스템 저널(journald)을 수집합니다. EC2 메모리·파일시스템 지표와 CloudWatch 대시보드는 없습니다. |

[Agent](../../terraform/env/was/main.tf#L45)가 시스템 기록을 수집하고 [API 경보](../../terraform/env/was/main.tf#L213)와 [DB 경보](../../terraform/env/db/main.tf#L89)가 상태 감지를 담당합니다. [API 로그 그룹](../../terraform/env/was/main.tf#L135)과 [DB 로그 그룹](../../terraform/env/db/main.tf#L61)은 기록을 보관합니다. ALB의 접근·연결·헬스 체크 로그는 [로그 전달 설정](../../terraform/modules/alb/main.tf#L67)에 따라 CloudWatch Logs에 저장합니다. CloudFront 접근 로그는 [S3 전달 설정](../../terraform/modules/cloudfront/main.tf#L137)을 사용합니다.

### 1.3 텔레메트리 수집 현황

| 자료 | 수집 대상·위치 | 운영에 활용할 수 있는 정보 |
|---|---|---|
| 컴퓨팅·DB 지표 | 서울 CloudWatch의 API EC2, ASG `arcamap-api`, RDS `arcamap-postgres` | CPU·실행 대수·DB 자원 여유입니다. 실제 관측 기간과 값은 [4.1 수요와 자원 사용](#41-api의-낮은-cpu와-유효한-수요를-구분해야-합니다)에 있습니다. |
| API 요청 지표·로그 | ALB `arcamap-api`의 CloudWatch 지표와 `/aws/vendedlogs/elb/arcamap-api` | 요청량·응답 상태·정상 대상 수를 보여줍니다. |
| API 프로세스 로그 | `/arcamap/ec2/system`의 인스턴스별 `system` 스트림 | 프로세스 관련 기록이 있습니다. 전용 `/arcamap/api/application`에는 스트림이 없습니다. [4.4 API 기록](#44-시스템-로그는-있지만-업무당-자원-사용을-연결하기-어렵습니다) |
| CDN 지표·로그 | CloudFront `E39UQTOCMBVZB3`의 CloudWatch 지표와 [CloudFront 접근 로그 버킷](../../terraform/env/web/main.tf#L14) | 공통 기간에 요청 **14,181건**, 지도 부분 응답 **4,401건**이 있습니다. 캐시 처리 분류와 홈 재검증 기록은 [성능 효율성 4.5](04-performance-efficiency.md#45-cloudfront-캐시-결과와-콘텐츠별-응답-성능)에 있습니다. |
| 빌드·DB·WAF 로그 | `/aws/imagebuilder/arcamap-api`, `/aws/rds/instance/arcamap-postgres/postgresql`·`upgrade`, `aws-waf-logs-CloudFrontDistribution-E39UQTOCMBVZB3` | 빌드·DB 운영 기록과 웹 요청 검사 결과를 보관합니다. WAF 로그는 버지니아 북부에 있습니다. |
| 객체 저장 지표 | 서울 CloudWatch S3의 버킷별 저장량·객체 수 | 일일 저장 상태를 보여줍니다. 현재 객체와 일일 지표의 시점은 [4.3 데이터 보존](#43-보존-정책과-현재-데이터의-필요성을-함께-판단해야-합니다)에 있습니다. |
| 변경·빌드 이벤트 | ASG `arcamap-api`의 활동·인스턴스 교체 이력, Image Builder `arcamap-api/1.1.2/1` | 이미지 생성과 API 교체의 경위를 보여줍니다. [4.5 빌드와 배포](#45-임시-이미지-빌드와-api-교체-중-정상-처리-용량-공백) |

> **효율 측정 제약**: 업무 성공 건수와 자원 사용량을 연결하는 지표가 없어 업무 1건당 효율을 비교하기 어렵습니다. 단말의 처리 부담과 실제 전력·탄소 배출량도 자료가 없습니다.

## 2. [Pillar Principles(기둥의 원칙에 따른 검토)](https://docs.aws.amazon.com/wellarchitected/latest/framework/sustainability.html)

[지속 가능성](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus-def.html)은 필요한 총자원을 줄이고 제공된 자원을 효율적으로 사용하는 데 중점을 둡니다. [6개 설계 원칙](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus-design-principles.html)은 업무 성과와 자원 사용을 연결하고 사용자 단말에 미치는 영향까지 고려합니다.

| 공식 설계 원칙 | 현재 운영 | 검토할 사항 |
|---|---|---|
| Understand your impact — 환경 영향 이해 | CPU·요청·저장·전송량과 콘텐츠별 캐시 기록이 있습니다. | [업무 처리량과 자원 사용](#44-시스템-로그는-있지만-업무당-자원-사용을-연결하기-어렵습니다)을 연결해야 효율의 기준선을 정할 수 있습니다. |
| Establish sustainability goals — 지속 가능성 목표 수립 | 부하 감소 시 축소와 로그 정리를 운영 방향으로 삼습니다. | 측정 가능한 목표·책임자·검토 주기와 필요한 서비스 수준을 정할 자료가 부족합니다. |
| Maximize utilization — 자원 활용률 극대화 | ASG 용량 조절·RDS 저장소 자동 확장·데이터 만료를 사용합니다. | [낮은 CPU 사용률](#41-api의-낮은-cpu와-유효한-수요를-구분해야-합니다)과 실제 수요·장애 대응 용량을 함께 비교해야 적정 규모를 정할 수 있습니다. |
| Anticipate and adopt new, more efficient hardware and software offerings — 효율적인 기술 검토·도입 | RDS는 Graviton 계열이며 API는 이미지 교체로 실행 환경을 갱신합니다. | 다른 유형을 검토하려면 API·빌드의 `x86_64` 의존성과 동일 업무의 자원 사용을 비교해야 합니다. |
| Use managed services — 관리형 서비스 사용 | RDS·S3·CloudFront·ALB·Image Builder가 저장·전달·빌드를 담당합니다. | 고정 컴퓨팅 용량과 보존 범위는 업무 요구에 맞춰 관리해야 합니다. |
| Reduce the downstream impact of your cloud workloads — 사용자 측 환경 영향 감소 | 프런트엔드 압축을 사용하며 [지도 부분 응답과 캐시 활용](04-performance-efficiency.md#45-cloudfront-캐시-결과와-콘텐츠별-응답-성능)이 나타납니다. | 홈의 잦은 원본 재검증과 화면 작업당 전송량을 살펴보고 대표 단말의 렌더링·메모리 부담을 비교해야 합니다. |

## 3. [Questions and Best Practices(질문 및 모범 사례별 상세 점검)](https://docs.aws.amazon.com/wellarchitected/latest/framework/a-sustainability.html)

### 3.1 SUS 1 — 리전 선택

**공식 질문:** [How do you select Regions for your workload?](https://docs.aws.amazon.com/wellarchitected/latest/framework/w2aac19c17b7b5.html)

**질문 판정: 확인 불가** — 서울에 주요 리소스를 배치합니다. 업무 요건과 지속 가능성 목표를 비교한 리전 선정 근거는 없습니다.

| 공식 BP·원문 | 점검 기준 | 현재 상태·근거 | 판정 | 판정 사유 |
|---|---|---|---|---|
| [SUS01-BP01 Choose Region based on both business requirements and sustainability goals](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_region_a2.html) | 업무 요건과 환경 목표를 함께 비교해 리전을 선택합니다. | API·RDS·S3는 서울에 있고 글로벌 CDN을 사용합니다. [1.1 리소스 구성](#11-리소스-구성) | **확인 불가** | 사용자 분포·지연·데이터 위치 요건과 환경 목표를 비교한 선정 근거가 없습니다. |

### 3.2 SUS 2 — 수요에 맞춘 자원 공급

**공식 질문:** [How do you align cloud resources to your demand?](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus-02.html)

**질문 판정: 확인 불가** — CPU 기반 자동 조절은 구현돼 있습니다. 적정 최소 용량과 서비스 수준·통신·요청 처리 요구를 비교할 자료가 부족합니다.

| 공식 BP·원문 | 점검 기준 | 현재 상태·근거 | 판정 | 판정 사유 |
|---|---|---|---|---|
| [SUS02-BP01 Scale workload infrastructure dynamically](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_user_a2.html) | 수요에 맞춰 용량을 늘리거나 줄이고 동작을 시험합니다. | CPU 50% 목표로 2~4대를 자동 조절합니다. 관측된 실행 대수는 2대이며 API CPU 평균은 1% 미만입니다. [4.1 수요와 자원 사용](#41-api의-낮은-cpu와-유효한-수요를-구분해야-합니다) | **확인 불가** | 자동 조절은 구현돼 있으나 업무 수요·장애 대응 용량·확장 및 축소 시험 자료가 없어 적정 하한을 판단하기 어렵습니다. |
| [SUS02-BP02 Align SLAs with sustainability goals](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_user_a3.html) | 서비스 수준과 지속 가능성 목표의 절충을 정기적으로 검토합니다. | 두 가용 영역의 API와 RDS Multi-AZ·3일 백업을 운영합니다. [1.1 리소스 구성](#11-리소스-구성) | **확인 불가** | 합의된 서비스 수준·복구 목표와 자원 사용 간의 절충 근거가 없습니다. |
| [SUS02-BP03 Stop the creation and maintenance of unused assets](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_user_a4.html) | 미사용 자산을 정기적으로 식별하고 생성·유지를 중단합니다. | 운영 EBS·AMI와 지도·배포 객체를 사용하며 사진 버킷은 콘텐츠 오리진으로 연결돼 있습니다. [4.3 데이터 보존](#43-보존-정책과-현재-데이터의-필요성을-함께-판단해야-합니다) | **확인 불가** | 자산별 사용·폐기 검토 기록이 없어 불필요한 자산과 정리 절차를 판단하기 어렵습니다. |
| [SUS02-BP04 Optimize geographic placement of workloads based on their networking requirements](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_user_a5.html) | 통신 요구에 맞춰 사용자·데이터와 가까이 배치합니다. | API·DB·S3는 서울에 있고 지도는 CloudFront 캐시에서도 응답합니다. [1.1 리소스 구성](#11-리소스-구성), [성능 효율성 4.5](04-performance-efficiency.md#45-cloudfront-캐시-결과와-콘텐츠별-응답-성능) | **확인 불가** | 사용자 위치와 지연 요구를 비교한 자료가 없어 배치의 적정성을 판단하기 어렵습니다. |
| [SUS02-BP05 Optimize team member resources for activities performed](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_user_a6.html) | 팀의 작업에 맞는 장비·개발 자원과 수명 주기를 관리합니다. | 운영과 이미지 빌드의 실행 환경은 나뉘어 있습니다. [1.1 리소스 구성](#11-리소스-구성) | **확인 불가** | 팀 장비·개발환경의 사용 시간과 교체 기준 자료가 없습니다. |
| [SUS02-BP06 Implement buffering or throttling to flatten the demand curve](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_user_a7.html) | 지연 허용 범위에 맞춰 버퍼·요청 제한으로 수요를 평탄화합니다. | ALB가 API 요청을 전달하고 CloudFront가 콘텐츠를 캐시합니다. [4.1 수요와 자원 사용](#41-api의-낮은-cpu와-유효한-수요를-구분해야-합니다), [4.2 콘텐츠 전송](#42-cloudfront의-지도-부분-응답캐시-활용과-홈-재검증) | **확인 불가** | API 요청 제한·큐·재시도 구현과 작업별 지연 허용 요건을 알 수 없습니다. |

### 3.3 SUS 3 — 소프트웨어와 아키텍처

**공식 질문:** [How do you take advantage of software and architecture patterns to support your sustainability goals?](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus-03.html)

**질문 판정: 확인 불가** — 콘텐츠와 API·DB의 역할을 나누고 지도 부분 읽기·캐시를 사용합니다. 코드·쿼리·단말별 자원 사용을 판단할 자료가 부족합니다.

| 공식 BP·원문 | 점검 기준 | 현재 상태·근거 | 판정 | 판정 사유 |
|---|---|---|---|---|
| [SUS03-BP01 Optimize software and architecture for asynchronous and scheduled jobs](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_software_a2.html) | 비동기·예약 작업을 효율적으로 배치해 유휴 자원을 줄입니다. | 이미지 빌드는 임시 환경을 사용합니다. [4.5 빌드와 배포](#45-임시-이미지-빌드와-api-교체-중-정상-처리-용량-공백) | **확인 불가** | 업무 배치와 지도 갱신 작업의 일정·수요 자료가 없어 작업 배치의 효율을 판단하기 어렵습니다. |
| [SUS03-BP02 Remove or refactor workload components with low or no use](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_software_a3.html) | 구성요소별 이용률에 따라 저사용·미사용 요소를 개선합니다. | API CPU와 DB 연결 지표는 낮습니다. [4.1 수요와 자원 사용](#41-api의-낮은-cpu와-유효한-수요를-구분해야-합니다) | **확인 불가** | 기능별 사용량과 폐기·통합 검토 기록이 없어 저사용 원인과 개선 여부를 판단하기 어렵습니다. |
| [SUS03-BP03 Optimize areas of code that consume the most time or resources](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_software_a4.html) | 시간·자원을 많이 사용하는 코드를 측정하고 개선합니다. | API 프로세스 로그와 인프라 지표가 있습니다. [4.4 효율 측정](#44-시스템-로그는-있지만-업무당-자원-사용을-연결하기-어렵습니다) | **확인 불가** | 코드 프로파일·쿼리 계획·개선 전후 자료가 없어 자원 소모가 큰 처리와 개선 효과를 알 수 없습니다. |
| [SUS03-BP04 Optimize impact on devices and equipment](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_software_a5.html) | 지원 단말의 처리·전송 부담과 교체 필요성을 줄입니다. | 프런트엔드 압축을 사용하며 지도 부분 응답이 4,401건 있습니다. [4.2 콘텐츠 전송](#42-cloudfront의-지도-부분-응답캐시-활용과-홈-재검증), [성능 효율성 4.5](04-performance-efficiency.md#45-cloudfront-캐시-결과와-콘텐츠별-응답-성능) | **확인 불가** | 단말별 CPU·메모리·호환성 시험이 없어 지도 렌더링과 전송이 기기에 주는 부담을 판단하기 어렵습니다. |
| [SUS03-BP05 Use software patterns and architectures that best support data access and storage patterns](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_software_a6.html) | 데이터 형태·증가·접근 특성에 맞는 처리·저장 패턴을 사용합니다. | 콘텐츠는 S3·CloudFront, 관계형 데이터는 RDS가 담당합니다. 지도 부분 읽기와 캐시 응답을 사용합니다. [성능 효율성 4.5](04-performance-efficiency.md#45-cloudfront-캐시-결과와-콘텐츠별-응답-성능), [4.4 효율 측정](#44-시스템-로그는-있지만-업무당-자원-사용을-연결하기-어렵습니다) | **확인 불가** | 지도 전송 방식은 드러나지만 DB 쿼리·갱신 특성과 데이터 증가량을 비교할 자료가 부족합니다. |

### 3.4 SUS 4 — 데이터 관리

**공식 질문:** [How do you take advantage of data management policies and patterns to support your sustainability goals?](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus-04.html)

**질문 판정: 부분 충족** — 공유 원본·일부 보존 자동화·DB 저장소 확장을 사용합니다. API 저장소의 내부 사용량 감시가 빠져 있으며 데이터 분류·보존·압축·백업 요구는 자료가 부족합니다.

| 공식 BP·원문 | 점검 기준 | 현재 상태·근거 | 판정 | 판정 사유 |
|---|---|---|---|---|
| [SUS04-BP01 Implement a data classification policy](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_data_a2.html) | 업무 가치·민감도·보존·가용성에 따라 데이터를 분류합니다. | 콘텐츠·배포·로그를 용도별 저장소에 나누고 일부 보존 기간을 설정합니다. [4.3 데이터 보존](#43-보존-정책과-현재-데이터의-필요성을-함께-판단해야-합니다) | **확인 불가** | 데이터별 분류 정책·소유자·취급 기준 자료가 없습니다. |
| [SUS04-BP02 Use technologies that support data access and storage patterns](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_data_a3.html) | 접근 빈도·지연·내구성 요구에 맞는 저장 기술과 계층을 선택합니다. | 콘텐츠는 S3 STANDARD, 관계형 데이터는 PostgreSQL을 사용합니다. [4.3 데이터 보존](#43-보존-정책과-현재-데이터의-필요성을-함께-판단해야-합니다) | **확인 불가** | 데이터별 접근 빈도와 보존·지연 요구를 비교할 자료가 부족합니다. |
| [SUS04-BP03 Use policies to manage the lifecycle of your datasets](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_data_a4.html) | 데이터 수명 주기를 정하고 보존·전환·삭제를 자동화합니다. | 로그 30일·WAF 14일·사진 이전 버전 7일·RDS 백업 3일 정책이 있습니다. 지도·웹·배포 S3에는 만료 정책이 없습니다. [4.3 데이터 보존](#43-보존-정책과-현재-데이터의-필요성을-함께-판단해야-합니다) | **확인 불가** | 일부 보존은 자동화돼 있으나 데이터별 보존·폐기 요구와 배포 객체의 교체 기준이 없어 정책 범위의 적정성을 판단하기 어렵습니다. |
| [SUS04-BP04 Use elasticity and automation to expand block storage or file system](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_data_a5.html) | 저장 사용량을 감시하며 블록 저장소·파일시스템을 확장합니다. | RDS는 20~100GiB 자동 확장과 공간 경보가 있습니다. API 저장소는 각 20GiB이며 파일시스템 지표가 없습니다. [1.2 옵저빌리티 구성](#12-옵저빌리티-구성), [4.4 효율 측정](#44-시스템-로그는-있지만-업무당-자원-사용을-연결하기-어렵습니다) | **부분 충족** | DB는 사용량 감시와 확장을 지원하지만 API 저장소는 내부 사용량을 감시하지 않아 공간 부족과 확장 시점을 파악하기 어렵습니다. |
| [SUS04-BP05 Remove unneeded or redundant data](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_data_a6.html) | 불필요·중복 데이터를 식별하고 삭제·중복 제거를 자동화합니다. | 일부 데이터 만료와 인스턴스 종료 시 EBS 삭제를 사용합니다. [4.3 데이터 보존](#43-보존-정책과-현재-데이터의-필요성을-함께-판단해야-합니다) | **확인 불가** | 지도·이미지·배포 객체와 백업의 사용·재생성·복구 기준이 없어 불필요한 데이터와 제거 절차를 판단하기 어렵습니다. |
| [SUS04-BP06 Use shared file systems or storage to access common data](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_data_a7.html) | 공통 데이터를 공유 저장소에서 제공해 소비자별 복제를 줄입니다. | 웹·사진·지도는 공통 S3 오리진을 CloudFront로 제공합니다. [1.1 리소스 구성](#11-리소스-구성) | **충족** | 콘텐츠 원본을 공유 저장소에서 제공해 이용자마다 별도 저장소를 유지할 필요가 없습니다. |
| [SUS04-BP07 Minimize data movement across networks](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_data_a8.html) | 반복 전송을 줄이고 데이터 크기·형식을 접근 요구에 맞춥니다. | 프런트엔드 압축·지도 부분 읽기·캐시 응답을 사용합니다. 홈에는 원본 재검증 기록이 많습니다. [4.2 콘텐츠 전송](#42-cloudfront의-지도-부분-응답캐시-활용과-홈-재검증), [성능 효율성 4.5](04-performance-efficiency.md#45-cloudfront-캐시-결과와-콘텐츠별-응답-성능) | **확인 불가** | 지도·사진의 형식·압축 요구와 홈 갱신 조건이 없어 추가로 줄일 수 있는 전송을 판단하기 어렵습니다. |
| [SUS04-BP08 Back up data only when difficult to recreate](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_data_a9.html) | 업무 가치·재생성 비용·복구 목표에 맞춰 백업 대상을 정합니다. | RDS 자동 백업·사진 버전 관리·운영 AMI 스냅샷을 사용합니다. [4.3 데이터 보존](#43-보존-정책과-현재-데이터의-필요성을-함께-판단해야-합니다) | **확인 불가** | 데이터별 재생성 가능성과 복구 목표 자료가 없어 백업 범위의 적정성을 판단하기 어렵습니다. |

### 3.5 SUS 5 — 하드웨어와 서비스

**공식 질문:** [How do you select and use cloud hardware and services in your architecture to support your sustainability goals?](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus-05.html)

**질문 판정: 확인 불가** — 관리형 서비스를 활용합니다. 필요한 최소 용량과 인스턴스 유형의 적정성을 판단할 업무·가용성 자료가 부족합니다.

| 공식 BP·원문 | 점검 기준 | 현재 상태·근거 | 판정 | 판정 사유 |
|---|---|---|---|---|
| [SUS05-BP01 Use the minimum amount of hardware to meet your needs](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_hardware_a2.html) | 성능·가용성 요구를 만족하는 최소 규모의 자원을 사용합니다. | API 두 대·RDS Multi-AZ·NAT 두 개를 운영하며 CPU와 DB 공간에 여유가 있습니다. [4.1 수요와 자원 사용](#41-api의-낮은-cpu와-유효한-수요를-구분해야-합니다) | **확인 불가** | 업무 부하·EC2 메모리·장애 대응 용량과 서비스 수준 자료가 부족해 안전한 최소 규모를 정하기 어렵습니다. |
| [SUS05-BP02 Use instance types with the least impact](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_hardware_a3.html) | 환경 영향이 적은 인스턴스 유형을 지속적으로 비교·채택합니다. | RDS는 db.t4g.medium, API·빌드는 t3.small·x86_64입니다. [1.1 리소스 구성](#11-리소스-구성), [4.5 빌드와 배포](#45-임시-이미지-빌드와-api-교체-중-정상-처리-용량-공백) | **확인 불가** | 유형별 호환성 시험과 동일 업무의 자원 사용·정기 검토 자료가 없습니다. |
| [SUS05-BP03 Use managed services](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_hardware_a4.html) | 공유 운영과 자동 관리를 제공하는 관리형 서비스를 활용합니다. | RDS·S3·CloudFront·ALB·Image Builder가 저장·전달·빌드를 담당합니다. [1.1 리소스 구성](#11-리소스-구성) | **충족** | 관리형 서비스를 활용해 DB·콘텐츠·요청 분산·빌드 환경을 운영합니다. |
| [SUS05-BP04 Optimize your use of hardware-based compute accelerators](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_hardware_a5.html) | 가속기가 필요한 작업에 적합한 하드웨어를 사용합니다. | API와 이미지 빌드는 범용 EC2를 사용합니다. [1.1 리소스 구성](#11-리소스-구성) | **해당 없음** | API 운영·이미지 빌드에는 GPU·FPGA·ML 가속기 작업이 없습니다. |

### 3.6 SUS 6 — 프로세스와 조직 문화

**공식 질문:** [How do your organizational processes support your sustainability goals?](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus-06.html)

**질문 판정: 부분 충족** — 임시 빌드·이미지 시험·자동 교체를 사용합니다. API 교체 중 정상 처리 용량을 유지하지 못했으며 목표 관리·정기 갱신·단말 시험 자료도 부족합니다.

| 공식 BP·원문 | 점검 기준 | 현재 상태·근거 | 판정 | 판정 사유 |
|---|---|---|---|---|
| [SUS06-BP01 Communicate and cascade your sustainability goals](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_dev_a1.html) | 조직 목표를 측정 가능한 업무 목표·책임·활동으로 연결합니다. | README는 부하에 따른 축소와 로그 정리를 운영 방향으로 제시합니다. [1.2 옵저빌리티 구성](#12-옵저빌리티-구성) | **확인 불가** | 수치 목표·책임자·정기 공유 기록이 없어 목표 관리 절차를 판단하기 어렵습니다. |
| [SUS06-BP02 Adopt methods that can rapidly introduce sustainability improvements](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_dev_a2.html) | 작은 개선을 시험·배포하고 효과를 지속 평가합니다. | 이미지 테스트와 자동 교체를 사용합니다. 9월 15일 교체 중 정상 API 대상이 0대인 구간이 있었습니다. [4.5 빌드와 배포](#45-임시-이미지-빌드와-api-교체-중-정상-처리-용량-공백) | **부분 충족** | 시험·배포 수단은 있지만 교체 중 정상 처리 용량을 유지하지 못했습니다. |
| [SUS06-BP03 Keep your workload up-to-date](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_dev_a3.html) | 소프트웨어·아키텍처 갱신을 정기적으로 검토·시험·적용합니다. | 이미지 생성·교체 이력이 있습니다. RDS 마이너 버전 자동 갱신은 꺼져 있고 Image Builder의 정기 파이프라인은 없습니다. [4.5 빌드와 배포](#45-임시-이미지-빌드와-api-교체-중-정상-처리-용량-공백) | **확인 불가** | 수동 갱신을 포함한 정기 검토·시험 기록이 없어 갱신 절차를 판단하기 어렵습니다. |
| [SUS06-BP04 Increase utilization of build environments](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_dev_a4.html) | 빌드·시험 환경을 필요할 때 생성하고 종료합니다. | Image Builder는 임시 t3.small을 사용하고 실패 시 종료합니다. 현재 빌드 인스턴스는 없고 산출 AMI는 운영 중입니다. [4.5 빌드와 배포](#45-임시-이미지-빌드와-api-교체-중-정상-처리-용량-공백) | **충족** | 이미지 생성·시험에 필요한 동안만 빌드 환경을 사용합니다. |
| [SUS06-BP05 Use managed device farms for testing](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_dev_a5.html) | 기기 시험 요구에 맞는 관리형 장치 시험 환경을 사용합니다. | 브라우저에서 지도와 웹 화면을 제공합니다. [4.2 콘텐츠 전송](#42-cloudfront의-지도-부분-응답캐시-활용과-홈-재검증) | **확인 불가** | 단말·브라우저 시험 계획과 관리형 시험 환경 사용 자료가 없어 적용 여부를 판단하기 어렵습니다. |

## 4. Findings and Insights(발견 사항 및 인사이트)

### 4.1 API의 낮은 CPU와 유효한 수요를 구분해야 합니다

**API CPU 사용률은 낮고 RDS에도 자원 여유가 있습니다.** CloudWatch의 API EC2·ASG `arcamap-api`·RDS `arcamap-postgres` 지표에서 나타나는 상태입니다. CPU 평균은 5분 구간의 표본 수로 가중한 값입니다.

| API 인스턴스 | CPU 관측 구간 | CPU 가중 평균 | CPU 최대 |
|---|---|---:|---:|
| 교체 전 `i-08cc1ba2a3e576955` | 9월 14일 01:50~15일 01:35 | 0.40% | 6.72% |
| 교체 전 `i-0714ee9ba1e451644` | 9월 14일 01:50~15일 01:35 | 0.43% | 11.86% |
| 현재 `i-0c1479ceb7baccd9f` | 9월 15일 01:30~21일 23:55 | 0.56% | 4.70% |
| 현재 `i-0aed6bfc82622f097` | 9월 15일 01:30~21일 23:55 | 0.64% | 15.67% |

| 대상·지표 | 관측값 | 관측 구간 |
|---|---|---|
| ASG 실행·희망 대수 | **2대** 유지 | 9월 14일 18:05~21일 23:55 |
| RDS CPU | 가중 평균 **5.23%**, 최대 **29.34%** | 9월 14일 00:40~21일 23:55 |
| RDS 가용 저장 공간 | 최솟값 **17.06GiB** | 9월 14일 00:45~21일 23:55 |
| RDS 가용 메모리 | 최솟값 **2.82GiB** | 9월 14일 00:45~21일 23:55 |
| RDS DB 연결 수 | 표본의 최댓값 **0개** | 9월 14일 00:45~21일 23:55 |

ALB `arcamap-api`의 공통 기간 CloudWatch 지표 합계는 요청 **7,616건**, 대상 2xx 응답 **440건**, 대상 4xx 응답 **6,872건**입니다. 오류 응답이 많아 전체 요청량으로 정상 업무 수요를 파악하기 어렵습니다. [ALB 지표](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-cloudwatch-metrics.html)는 로드 밸런서 자체의 헬스 체크 요청을 제외합니다.

> **응답 집계 제약**: 대상 4xx 지표 6,872건과 [접근 로그의 대상 404 6,870건](04-performance-efficiency.md#41-alb-요청량과-응답-시간의-표본-차이)은 집계 대상이 다릅니다. 두 수치 사이의 2건 차이는 원인이 미확인입니다.

현재 ASG의 최소 용량은 **2대**이며 두 가용 영역에 나뉘어 있습니다. 적정 규모를 정하려면 정상 업무의 처리량·지연과 EC2 메모리 사용량을 연결하고 한 가용 영역에 장애가 나도 필요한 요청을 처리할 수 있는지 비교해야 합니다. 이 기준이 있으면 사용률이 낮은 원인과 장애 대응에 필요한 여유를 구분해 인스턴스 유형·크기를 선택할 수 있습니다.

> **관측 범위**: ASG 대수 지표는 9월 14일 18:05부터 있어 그 이전 용량 변화는 설명하기 어렵습니다. EC2 메모리·파일시스템과 기능별 처리량 자료도 없어 안전한 최소 대수와 DB 규모를 정하기 어렵습니다.

관련 기준은 [SUS 2](#32-sus-2--수요에-맞춘-자원-공급)의 BP01·BP02, [SUS 3](#33-sus-3--소프트웨어와-아키텍처)의 BP02·BP03, [SUS 5](#35-sus-5--하드웨어와-서비스)의 BP01·BP02입니다.

### 4.2 CloudFront의 지도 부분 응답·캐시 활용과 홈 재검증

**CloudFront는 지도 데이터를 부분 응답으로 제공하고 캐시된 콘텐츠를 재사용합니다.** 공통 기간의 `E39UQTOCMBVZB3` 요청은 **14,181건**, 다운로드는 **357.5MB**입니다. S3에 저장된 CloudFront 접근 로그에도 같은 기간의 요청 14,181건이 있으며 실제 기록은 **9월 14일 01:07:08~21일 23:57:55**입니다. 상세 근거는 [성능 효율성 4.5의 콘텐츠별 응답 기록](04-performance-efficiency.md#45-cloudfront-캐시-결과와-콘텐츠별-응답-성능)에 있습니다.

응답 직전의 캐시 처리 분류는 **Hit 4,068건·Miss 744건·RefreshHit 616건**입니다. [CloudFront 로그 정의](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/standard-logs-reference.html)에서 Hit는 캐시 응답, Miss는 원본에서 가져온 응답, RefreshHit는 원본에 최신 여부를 재확인한 캐시 응답입니다. 전송 도중 연결이 종료되면 최종 분류가 바뀔 수 있습니다.

| 콘텐츠·응답 | 전송 종료 후 Hit | Miss | RefreshHit |
|---|---:|---:|---:|
| `/20260907.pmtiles`의 206 부분 응답 | 3,468건 | 188건 | 13건 |
| `/`·`/index.html`의 200 응답 | 2건 | 158건 | 474건 |

지도 객체는 **128.37GiB**이며 HTTP 206 부분 응답은 **4,401건**입니다. 필요한 범위의 데이터를 읽고 캐시를 사용하는 요청이 실제로 있습니다. 지도 응답 중 최종 Error로 남은 732건은 전송 완료 여부와 화면 표시 영향을 살펴볼 대상입니다.

홈 응답에서는 원본 재검증이 **474건** 발생했습니다. 현재 웹 파일의 기본·최대 TTL은 **300초**입니다. 홈 HTML의 갱신 조건과 버전이 붙은 정적 자산의 재사용 조건을 나누어 검토하면 불필요한 원본 재검증을 줄일 여지가 있습니다. 변경 시에는 콘텐츠 최신성·지도 부분 읽기·브라우저 호환성을 유지해야 합니다.

> **전송 효율 제약**: 객체의 갱신 이력·캐시 헤더와 오리진 전송량이 없어 재검증 원인과 줄일 수 있는 바이트를 정하기 어렵습니다. 사진 요청 기록과 대표 단말의 화면 표시·처리 자료도 없어 사진 압축 및 단말 부담을 판단하기 어렵습니다.

관련 기준은 [SUS 2](#32-sus-2--수요에-맞춘-자원-공급)의 BP04, [SUS 3](#33-sus-3--소프트웨어와-아키텍처)의 BP04·BP05, [SUS 4](#34-sus-4--데이터-관리)의 BP07입니다.

### 4.3 보존 정책과 현재 데이터의 필요성을 함께 판단해야 합니다

**로그와 사진의 이전 버전은 보존 기간을 제한하며 지도·웹·배포 파일은 서비스 제공과 배포에 사용합니다.** [S3 저장소](#11-리소스-구성)의 현재 객체 상태는 **9월 22일 15:46~15:57**, 일일 지표는 **9월 14~21일 09:00** 기준입니다.

| 데이터 | 9월 22일 객체 상태 | 공통 기간의 S3 일일 지표 |
|---|---|---|
| 지도 | **1개·128.37GiB**, 마지막 수정 9월 8일 12:57 | 9월 14~21일 모두 **1개·128.37GiB** |
| 웹 파일 | **22개·16.87MB**, 9월 15일 01:48~05:35 수정 | 9월 15~21일 모두 **22개·16.87MB** |
| 배포 아카이브 | **1개·11.6kB**, 9월 15일 00:37 수정 | 9월 15~21일 모두 **1개·11.8kB** |
| 사진 | 객체·이전 버전·삭제 마커가 없습니다. | 지표가 없습니다. |
| CloudFront 접근 로그 | **1,231개·1.88MB**, 최신 수정 9월 22일 15:54 | 9월 14일 **64개·0.06MB**에서 21일 **1,067개·1.78MB**로 증가했습니다. |

> **저장량 관측 제약**: 웹·배포 버킷의 9월 14일 지표와 사진 버킷의 기간 지표가 없습니다. 마지막 일일 자료는 9월 21일 09:00이어서 이후 저장량 변화는 파악하기 어렵습니다.

CloudFront 접근 로그와 시스템·API·빌드·DB·ALB 로그는 **30일**, WAF 로그는 **14일** 보존합니다. 사진의 이전 버전은 **7일** 후 만료합니다. CloudFront 로그 버킷은 9월 14일에 생성됐고 사진 객체는 없어 현재 기록에는 만료 삭제 효과가 나타나지 않습니다.

운영 EBS 두 개는 API에 연결돼 있고 AMI 한 개와 그 스냅샷은 API 실행 환경의 기반입니다. RDS는 **3일 자동 백업**을 사용하며 구성 확인 시점에는 9월 18~21일에 생성된 자동 스냅샷 네 개가 있습니다.

지도·웹·배포 파일에는 S3 만료 정책이 없지만 데이터별 보존·재생성·복구 요구도 자료가 부족합니다. **새 버전으로 교체할 때 이전 원본과 배포 파일을 얼마나 남길지 정하는 기준**이 필요합니다. 서비스가 사용하는 원본과 복구에 필요한 사본을 유지하면서 사용이 끝난 데이터를 정리하면 저장·재처리 자원을 줄일 수 있습니다.

관련 기준은 [SUS 2](#32-sus-2--수요에-맞춘-자원-공급)의 BP03, [SUS 4](#34-sus-4--데이터-관리)의 BP01~BP08입니다.

### 4.4 시스템 로그는 있지만 업무당 자원 사용을 연결하기 어렵습니다

**API 프로세스 기록은 `/arcamap/ec2/system`에 수집됩니다.** [Agent](../../terraform/env/was/main.tf#L45)가 journald를 보내며 전용 `/arcamap/api/application`에는 스트림이 없습니다. 공통 기간의 시스템 로그 중 메시지에 `uvicorn`이 포함된 기록은 **88,696건**이며 **9월 14일 22:34:24~21일 23:59:55**에 분포합니다.

[운영 우수성 4.3의 API 기록](01-operational-excellence.md#43-시스템-로그와-api-기록-수집)은 `arcamap-api` 또는 `uvicorn`이 포함된 **88,710건**을 다룹니다. 두 값은 문자열 조건이 다르며 프로세스 기록에는 상태 확인 요청 등도 포함됩니다. 업무 성공 건수와 처리 시간을 구분할 필드가 있어야 기능별 자원 사용을 비교할 수 있습니다.

현재 Agent에는 **EC2 메모리·파일시스템 지표 수집이 없고 CloudWatch에도 해당 지표가 없습니다.** API 저장소 내부의 사용량을 알기 어려워 공간 부족과 확장 시점을 판단할 수 없습니다. 코드·쿼리별 자원 소모 자료도 없어 낮은 CPU가 적은 업무량 때문인지 다른 자원 대기 때문인지 구분하기 어렵습니다.

기존 로그에 업무 종류·성공 여부·처리 시간을 연결하고 EC2 메모리·파일시스템을 함께 관측하면 적정 용량의 기준을 마련할 수 있습니다. 필요한 필드와 보존 기간을 정해 **추가 로그의 저장·처리 부담도 관리**해야 합니다.

관련 기준은 [SUS 3](#33-sus-3--소프트웨어와-아키텍처)의 BP03·BP05, [SUS 4](#34-sus-4--데이터-관리)의 BP04, [SUS 5](#35-sus-5--하드웨어와-서비스)의 BP01, [SUS 6](#36-sus-6--프로세스와-조직-문화)의 BP02입니다.

### 4.5 임시 이미지 빌드와 API 교체 중 정상 처리 용량 공백

**Image Builder는 필요한 동안 빌드 환경을 사용하고 ASG는 완성된 이미지로 API를 교체합니다.** 9월 15일 배포에서는 기존 두 대가 함께 제외된 뒤 새 인스턴스가 준비되는 동안 정상 API 대상이 없어졌습니다. ASG `arcamap-api`의 교체 이력과 ALB 정상 대상 지표에 나타난 사건입니다.

| 9월 15일 시각 | 배포 진행 |
|---|---|
| 00:45 | Image Builder `arcamap-api/1.1.2/1`의 이미지 생성이 시작됐습니다. |
| 01:33:46~01:33:48 | 기존 두 대가 서비스에서 제외됐고 인스턴스 교체가 시작되면서 새 두 대가 기동했습니다. |
| 01:34·01:35 | ALB 정상 대상의 1분 최솟값은 **0대**였습니다. ASG 실행 대수는 2대였습니다. |
| 01:36 | ALB 정상 대상이 **2대**로 돌아왔습니다. |
| 01:39:33 | 인스턴스 교체가 완료됐습니다. |

교체 정책은 기존 정상 인스턴스를 유지할 비율을 **0%**로 두고 있어 새 대상이 준비되기 전에도 두 대를 함께 제외할 수 있습니다. 실제 사건과 서비스 영향은 [신뢰성 4.1의 동시 교체 기록](03-reliability.md#41-api-동시-교체로-정상-대상이-없어진-구간)에 있습니다.

> **배포 영향 제약**: 정상 대상이 없었던 구간의 요청 지표는 0건이며 사용자 요청 실패 건수와 연속 중단 시간을 정할 자료가 부족합니다.

[빌드 인프라](../../terraform/modules/image-builder/main.tf#L232)는 임시 인스턴스를 사용하고 실패 시에도 종료합니다. 현재 상시 빌드 인스턴스는 없으며 산출 AMI는 API 두 대가 사용합니다. [이미지 시험](../../terraform/modules/image-builder/fastapi.tf#L95)과 자동 교체는 변경을 적용할 기반이지만 빌드별 CPU·메모리·유휴 시간 자료는 없어 작업당 효율을 비교하기 어렵습니다.

API 유형·크기·코드를 바꿀 때는 대표 업무의 자원 사용과 실패·지연을 함께 비교해야 합니다. `x86_64` 기반 AMI·패키지는 다른 아키텍처로 바꾸기 전에 호환성 시험이 필요합니다. **새 대상이 준비될 때까지 정상 처리 용량을 유지하는 배포 순서**를 마련해야 효율 개선 과정에서도 API 요청을 계속 처리할 수 있습니다.

관련 기준은 [SUS 2](#32-sus-2--수요에-맞춘-자원-공급)의 BP01·BP02, [SUS 5](#35-sus-5--하드웨어와-서비스)의 BP02, [SUS 6](#36-sus-6--프로세스와-조직-문화)의 BP02~BP04입니다.

## 5. Conclusion(결론)

ArcaMap은 **공유 S3 원본·관리형 서비스·임시 이미지 빌드·일부 데이터 만료 정책**을 사용합니다. [CloudFront 접근 기록](04-performance-efficiency.md#45-cloudfront-캐시-결과와-콘텐츠별-응답-성능)에는 지도 부분 응답 **4,401건**과 실제 캐시 사용이 나타납니다. API CPU와 DB 자원에는 여유가 있지만 적정 규모를 정할 업무 처리량·메모리·가용성 자료가 부족합니다.

우선 과제는 **업무 성공 건수와 자원 사용을 연결해 적정 용량을 판단하는 것**입니다. 콘텐츠는 홈 재검증 **474건**의 갱신 조건을 살펴보고 데이터는 새 버전 도입 시 보존·재생성·복구 기준을 정해야 합니다. 변경을 적용할 때는 API 교체 중 정상 처리 용량을 유지해야 합니다.

> **남은 자료 제약**: 리전 선정 근거, 수치 목표·책임자·검토 주기, 코드·쿼리 특성, 대표 단말 시험과 데이터 분류·복구 요구가 부족합니다. 오리진 전송량과 실제 전력·탄소 자료도 없어 전송 절감량과 환경 영향을 정량화하기 어렵습니다.
