# Performance Efficiency(성능 효율성)

**⚡ CloudFront 캐시와 CPU 기반 자동 확장으로 콘텐츠 전달과 API 처리 용량을 조절합니다.**

ArcaMap은 웹·지도·사진을 S3와 CloudFront로 제공하고, ALB가 두 가용 영역의 API 서버에 요청을 분산합니다. API 서버는 필요한 데이터를 RDS PostgreSQL에서 가져옵니다.

**공통 집계 기간은 2026-09-14 00:00 이상~2026-09-22 00:00 미만**, 구성 확인 시점은 **2026-09-22 15:46~15:52**입니다. 날짜와 시각은 모두 KST입니다.

[현재 운영 현황](#1-current-operations현재-운영-현황) · [기둥의 원칙](#2-pillar-principles기둥의-원칙에-따른-검토) · [질문 및 모범 사례](#3-questions-and-best-practices질문-및-모범-사례별-상세-점검) · [발견 사항 및 인사이트](#4-findings-and-insights발견-사항-및-인사이트) · [결론](#5-conclusion결론)

## 1. Current Operations(현재 운영 현황)

### 1.1 리소스 구성

API·DB와 S3 원본은 서울 리전에서 운영합니다. CloudFront는 전 세계 엣지에서 콘텐츠를 제공하며, 배포 지표는 버지니아 북부 리전에서 제공합니다.

| 구성 요소 | 현재 설정과 연결 관계 | Terraform 정의 |
|---|---|---|
| 네트워크 | ALB는 퍼블릭 서브넷, API와 DB는 서로 다른 프라이빗 서브넷을 사용합니다. 두 API 서브넷은 각각 NAT Gateway를 통해 외부로 연결됩니다. | [VPC·서브넷·라우팅](../../terraform/modules/network/main.tf#L1) |
| ALB | `arcamap-api`는 서울의 두 가용 영역 `ap-northeast-2a`·`ap-northeast-2c`에 요청을 분산합니다. HTTP 80은 HTTPS 443으로 전환하고, TLS 종료 후 HTTP 8080으로 API에 전달합니다. | [ALB·리스너](../../terraform/modules/alb/main.tf#L1) |
| API 대상 그룹 | 두 API 대상은 모두 정상입니다. 요청을 순환 분산하며 연결 해제 대기 시간은 300초입니다. `/health`를 30초 간격으로 검사하고, 정상 전환에는 연속 5회 성공이 필요합니다. | [대상 그룹](../../terraform/modules/alb/main.tf#L14) |
| EC2·EBS | API 인스턴스 두 대는 각각 `t3.small`·x86_64·2 vCPU·2 GiB입니다. CPU 버스트 모드는 `unlimited`이며 루트 볼륨은 gp3 20 GiB·3,000 IOPS·125 MiB/s입니다. | [시작 템플릿](../../terraform/modules/compute/main.tf#L1), [API 환경](../../terraform/env/was/main.tf#L197) |
| Auto Scaling | `arcamap-api`는 최소 2대·최대 4대·현재 목표 2대입니다. 평균 CPU 50%를 목표로 확장·축소하며 준비 시간과 헬스 체크 유예는 각각 300초입니다. | [ASG](../../terraform/modules/compute/main.tf#L44), [CPU 정책](../../terraform/modules/compute/main.tf#L81) |
| RDS | `arcamap-postgres`는 PostgreSQL 17.11·`db.t4g.medium`·Multi-AZ입니다. gp3 20 GiB·3,000 IOPS·125 MiB/s와 저장 공간 자동 확장 상한 100 GiB를 사용합니다. 대기 인스턴스는 장애 조치를 맡으며 읽기 복제본은 없습니다. | [DB 정의](../../terraform/modules/database/main.tf#L6), [DB 환경](../../terraform/env/db/main.tf#L72) |
| CloudFront·S3 | `arcamap.app`의 웹·지도·사진 원본을 S3에 나누어 저장합니다. CloudFront는 OAC로 원본에 접근하며 HTTP/2·HTTP/3·IPv6와 `PriceClass_200`을 사용합니다. | [CloudFront 배포](../../terraform/modules/cloudfront/main.tf#L60), [원본 연결](../../terraform/env/web/main.tf#L38) |
| 콘텐츠별 캐시 | `arcamap-frontend`는 기본·최대 TTL 300초와 gzip·Brotli 압축을 사용합니다. 지도 파일 `/20260907.pmtiles`와 `/photos/*`의 `arcamap-media`는 기본·최대 TTL 86,400초이며 압축하지 않습니다. 두 정책은 최소 TTL이 0초이며 쿠키·일반 헤더·쿼리 문자열을 캐시 키에서 제외합니다. | [정적 파일 정책](../../terraform/modules/cloudfront/main.tf#L12), [미디어 정책](../../terraform/modules/cloudfront/main.tf#L36) |

TTL은 캐시 객체의 유효 기간입니다. 웹과 미디어의 캐시 정책을 나누어 콘텐츠별 갱신 주기를 조절합니다.

### 1.2 옵저빌리티 구성

CloudWatch는 자원 사용량과 요청 오류를 감지하고 CPU 부하에 따라 API 수량을 조절합니다. [운영 기준](../../README.md#4-operational-criteria-and-constraints운영-기준-및-제약)의 배포 확인 항목은 서비스 등록·헬스 체크·API 응답·DB 연결이며, 지연·동시 사용자·업무 처리량의 합격 기준은 명시되어 있지 않습니다.

| 관측 대상 | 수집·경보 설정 | Terraform 정의 |
|---|---|---|
| 컴퓨팅 용량 | CPU 목표 추적 경보 2개가 자동 확장 정책을 실행합니다. EC2 CPU는 기본 모니터링으로 5분마다, ASG 수량은 1분마다 수집합니다. | [CPU 정책](../../terraform/modules/compute/main.tf#L81) |
| 서버·API | 상태 검사·CPU·정상 대상·5xx 경보 6개가 있습니다. 정상 대상이 2대 미만이면 경보 상태로 전환하며 응답 지연 경보는 없습니다. | [API 경보](../../terraform/env/was/main.tf#L43) |
| DB 자원 | CPU 80%, 가용 메모리 512 MiB, 가용 저장 공간 5 GiB를 기준으로 경보 3개가 있습니다. | [DB 경보](../../terraform/env/db/main.tf#L21) |
| 운영자 통지 | 사용자 정의 경보 9개는 통지 동작이 꺼져 있고 알림 대상도 없습니다. | [경보 모듈](../../terraform/modules/cloudwatch-alarm/main.tf) |
| 로그 | EC2 시스템·API·Image Builder·RDS PostgreSQL·업그레이드·ALB 로그 그룹은 30일 보존합니다. ALB 로그는 CloudWatch Logs, CloudFront 접근 로그는 S3에 저장합니다. | [Agent 설정](../../terraform/env/was/main.tf#L43), [ALB 로그](../../terraform/modules/alb/main.tf#L73), [CloudFront 로그](../../terraform/modules/cloudfront/main.tf#L152) |
| DB 내부 성능 | Performance Insights와 Enhanced Monitoring은 꺼져 있습니다. | [DB 정의](../../terraform/modules/database/main.tf#L6) |

CloudWatch 대시보드와 서울 리전의 RUM·Synthetics는 구성되어 있지 않습니다. RUM은 실제 브라우저 경험을, Synthetics는 정해진 사용자 동작을 반복 실행해 서비스 상태를 관측하는 기능입니다.

### 1.3 텔레메트리 수집 현황

| 종류 | 대상·수집 위치 | 공통 기간의 기록 범위 |
|---|---|---|
| 컴퓨팅 지표 | 서울 CloudWatch의 현재·교체 전 API 인스턴스와 ASG `arcamap-api` | CPU·네트워크·수량 지표가 있습니다. 인스턴스별 관측 기간은 [4.2 컴퓨팅 부하](#42-낮은-컴퓨팅-부하와-확장-검증-공백)에 연결됩니다. |
| ALB 지표·로그 | 서울 CloudWatch의 `arcamap-api`; 로그 그룹 `/aws/vendedlogs/elb/arcamap-api`의 `ALB_Access_Logs/`·`ALB_Connection_Logs/`·`ALB_Health_Check_Logs/` 스트림 | 요청·응답 시간·정상 대상 지표와 접근·연결·헬스 체크 기록이 있습니다. |
| DB 지표·로그 | 서울 CloudWatch의 `arcamap-postgres`; `/aws/rds/instance/arcamap-postgres/postgresql`·`upgrade` | 자원·연결·I/O 지표와 DB 로그가 있습니다. 쿼리 통계·실행 계획은 미확인입니다. |
| CloudFront 지표·로그 | 버지니아 북부 CloudWatch의 배포 `E39UQTOCMBVZB3`; S3 로그 버킷 `arcamap-cloudfront-logs-4dae951d25673eeec311354d88` | 요청·전송량·오류율과 콘텐츠별 상태·캐시 결과·응답 시간이 있습니다. |
| API·시스템 로그 | `/arcamap/ec2/system`의 인스턴스별 `/system` 스트림 | 현재·교체 전 API와 빌드 인스턴스의 API 관련 기록이 있습니다. 전용 그룹 `/arcamap/api/application`에는 스트림이 없습니다. [운영 우수성의 API 기록 범위](01-operational-excellence.md#43-시스템-로그와-api-기록-수집)에 연결됩니다. |
| 배포·경보 이벤트 | ASG `arcamap-api`의 활동·인스턴스 교체 이력, 경보 `arcamap-alb-healthy-hosts` | 초기 시작 실패·완료와 배포 중 정상 대상 감소·회복 기록이 있습니다. |

## 2. [Pillar Principles(기둥의 원칙에 따른 검토)](https://docs.aws.amazon.com/wellarchitected/latest/framework/performance-efficiency.html)

성능 효율성은 **성능 요구를 만족하도록 클라우드 자원을 효율적으로 사용하고, 수요와 기술이 바뀌어도 그 효율을 유지하는 능력**입니다. [공식 설계 원칙](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf-dp.html)에 따라 서비스 선택과 현재 운영의 관계를 살펴봅니다.

| 공식 설계 원칙 | 현재 운영과의 관계 |
|---|---|
| **Democratize advanced technologies(고급 기술의 활용 장벽 낮추기)** | RDS·S3·CloudFront·ALB·Auto Scaling이 저장·전달·분산·용량 조절을 맡습니다. 서비스 선택의 비교·실험 기록은 미확인입니다. |
| **Go global in minutes(필요한 지역에 신속하게 제공하기)** | 콘텐츠는 CloudFront 엣지에서, API·DB는 서울에서 제공합니다. 사용자 지역과 지연 요구가 없어 현재 배치의 적합성은 확인하기 어렵습니다. |
| **Use serverless architectures(서버리스 아키텍처 활용하기)** | S3·CloudFront가 정적 콘텐츠를 제공해 별도 웹 서버의 운영 부담을 줄입니다. API 실행 방식의 적합성에는 요청·연결·배포 요구와 대안 비교가 필요합니다. |
| **Experiment more often(자주 실험하기)** | 시작 템플릿과 인스턴스 교체로 실행 환경을 변경합니다. 동일 조건 벤치마크·부하 시험 기록이 없어 변경에 따른 성능 효과는 미확인입니다. |
| **Consider mechanical sympathy(워크로드와 기술 특성의 적합성 고려하기)** | 객체·관계형 저장소와 콘텐츠별 TTL을 구분합니다. [지도 캐시](#45-cloudfront-캐시-결과와-콘텐츠별-응답-성능)의 응답 차이는 관측되지만, [DB 업무 부하](#43-rds-자원-사용과-미확인-업무-연결)와 호스트 메모리·동시성 자료가 부족해 전체 용량의 적정성은 미확인입니다. |

## 3. [Questions and Best Practices(질문 및 모범 사례별 상세 점검)](https://docs.aws.amazon.com/wellarchitected/latest/framework/a-performance-efficiency.html)

### 3.1 PERF01 — 자원과 아키텍처 선택

공식 질문: [PERF 1. How do you select appropriate cloud resources and architecture for your workload?](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf-01.html)

| 공식 BP·명칭 | 점검 기준 | 실제 현재 상태 | 확인 근거 | 판정 | 판정 사유 |
|---|---|---|---|---|---|
| [PERF01-BP01 Learn about and understand available cloud services and features](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_architecture_understand_cloud_services_and_features.html) | 관련 서비스와 기능을 지속적으로 학습하고 선택에 반영합니다. | 관리형 서비스와 EC2를 함께 사용합니다. 학습·실험 기록은 미확인입니다. | [리소스 구성](#11-리소스-구성) | **확인 불가** | 학습 내용과 서비스 선택을 연결하는 운영 기록이 없습니다. |
| [PERF01-BP02 Use guidance from your cloud provider or an appropriate partner to learn about architecture patterns and best practices](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_architecture_guidance_architecture_patterns_best_practices.html) | 공급자·파트너 지침을 업무 맥락에 맞게 적용합니다. | README에 설계 원칙은 있으나 설계 당시의 지침 적용·검토 기록은 미확인입니다. | [리소스 구성](#11-리소스-구성) | **확인 불가** | 설계 당시 적용한 지침과 검토 기록이 부족합니다. |
| [PERF01-BP03 Factor cost into architectural decisions](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_architecture_factor_cost_into_architectural_decisions.html) | 비용 목표와 사용량을 성능·아키텍처 선택에 반영합니다. | 최대 4대와 가격 등급을 제한합니다. 비용 목표·대안 비교의 운영 기록은 미확인입니다. | [컴퓨팅 부하](#42-낮은-컴퓨팅-부하와-확장-검증-공백) · [콘텐츠 캐시](#45-cloudfront-캐시-결과와-콘텐츠별-응답-성능) | **확인 불가** | 비용 목표와 대안별 성능 비교 자료가 부족합니다. |
| [PERF01-BP04 Evaluate how trade-offs impact customers and architecture efficiency](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_architecture_evaluate_trade_offs.html) | 성능 개선의 신선도·비용·가용성·사용자 영향을 평가합니다. | 콘텐츠별 TTL을 적용하며, 교체 중 정상 대상이 사라졌습니다. 중단 허용 기준과 사용자 영향 평가 기록은 미확인입니다. | [리소스 구성](#11-리소스-구성) · [ALB 연결과 배포](#44-alb-초기-연결-실패와-배포-중-처리-용량-소실) · [콘텐츠 캐시](#45-cloudfront-캐시-결과와-콘텐츠별-응답-성능) | **확인 불가** | 신선도·비용·가용성 간 선택이 사용자에게 미치는 영향을 평가한 자료가 부족합니다. |
| [PERF01-BP05 Use policies and reference architectures](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_architecture_use_policies_and_reference_architectures.html) | 정책·참조 구성을 재사용하고 성능 요구 충족을 검증합니다. | Terraform 모듈과 운영 기준에 따라 구성합니다. 배포 확인 기준은 상태·응답·연결 중심입니다. | [리소스 구성](#11-리소스-구성) · [관측과 대응](#46-성능-관측-범위와-운영-대응) | **부분 충족** | 재사용 구성과 배포 확인 항목은 있으나 지연·처리량의 합격 기준이 없습니다. |
| [PERF01-BP06 Use benchmarking to drive architectural decisions](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_architecture_use_benchmarking.html) | 대표 작업을 반복 측정해 대안과 변경 전후를 비교합니다. | 운영 지표·로그는 존재하지만 동일 조건 벤치마크 결과는 미확인입니다. | [ALB 요청과 응답](#41-alb-요청량과-응답-시간의-표본-차이) · [컴퓨팅 부하](#42-낮은-컴퓨팅-부하와-확장-검증-공백) · [DB 성능](#43-rds-자원-사용과-미확인-업무-연결) | **확인 불가** | 대표 작업의 반복 측정과 대안별 비교 결과가 없습니다. |
| [PERF01-BP07 Use a data-driven approach for architectural choices](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_architecture_use_data_driven_approach.html) | 요구·측정·실험과 설계 결정을 연결합니다. | 아키텍처와 운영 지표가 존재합니다. 선택별 측정·채택 근거는 미확인입니다. | [ALB 요청과 응답](#41-alb-요청량과-응답-시간의-표본-차이) · [컴퓨팅 부하](#42-낮은-컴퓨팅-부하와-확장-검증-공백) · [콘텐츠 캐시](#45-cloudfront-캐시-결과와-콘텐츠별-응답-성능) | **확인 불가** | 서비스 선택과 측정 결과를 연결하는 의사결정 기록이 부족합니다. |

### 3.2 PERF02 — 컴퓨팅 자원 선택과 사용

공식 질문: [PERF 2. How do you select and use compute resources in your workload?](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf-02.html)

| 공식 BP·명칭 | 점검 기준 | 실제 현재 상태 | 확인 근거 | 판정 | 판정 사유 |
|---|---|---|---|---|---|
| [PERF02-BP01 Select the best compute options for your workload](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_compute_hardware_select_best_compute_options.html) | 처리·확장·지연 요구로 컴퓨팅 방식을 선택합니다. | API는 EC2, 정적 콘텐츠는 S3·CloudFront입니다. 실행 방식 비교 자료는 미확인입니다. | [리소스 구성](#11-리소스-구성) · [컴퓨팅 부하](#42-낮은-컴퓨팅-부하와-확장-검증-공백) | **확인 불가** | 대표 부하와 실행 방식별 비교 자료가 부족합니다. |
| [PERF02-BP02 Understand the available compute configuration and features](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_compute_hardware_understand_compute_configuration_features.html) | CPU·메모리·버스트·I/O·동시성 옵션을 요구에 맞게 평가합니다. | CPU 버스트·gp3·확장 정책을 사용합니다. CPU 수집은 5분, 자동 확장 경보 평가는 1분 간격입니다. | [리소스 구성](#11-리소스-구성) · [컴퓨팅 부하](#42-낮은-컴퓨팅-부하와-확장-검증-공백) | **부분 충족** | CPU 수집은 5분, 목표 추적 경보 평가는 1분으로 설정되어 평가 자료에 빈 구간이 생깁니다. |
| [PERF02-BP03 Collect compute-related metrics](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_compute_hardware_collect_compute_related_metrics.html) | CPU·메모리·I/O·네트워크와 처리 성능을 수집합니다. | CPU·크레딧·네트워크·ALB 지연은 수집하며, Agent 정의는 journald 로그만 수집합니다. | [컴퓨팅 부하](#42-낮은-컴퓨팅-부하와-확장-검증-공백) · [관측과 대응](#46-성능-관측-범위와-운영-대응) | **부분 충족** | 기본 자원 지표는 수집하지만 Agent 수집 설정에 호스트 메모리·프로세스 지표가 없습니다. |
| [PERF02-BP04 Configure and right-size compute resources](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_compute_hardware_configure_and_right_size_compute_resources.html) | 대표 부하와 성능 요구로 자원 크기를 검증합니다. | 신·구 인스턴스 CPU는 낮습니다. 메모리·동시 처리량·부하 시험은 미확인입니다. | [컴퓨팅 부하](#42-낮은-컴퓨팅-부하와-확장-검증-공백) | **확인 불가** | 메모리·동시 처리량과 성능 목표가 없어 적정 크기를 판단하기 어렵습니다. |
| [PERF02-BP05 Scale your compute resources dynamically](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_compute_hardware_scale_compute_resources_dynamically.html) | 수요에 따라 확장·축소하고 전환 중 처리 능력을 검증합니다. | CPU 50%의 2~4대 자동 조절은 활성화되어 있습니다. 교체 중 정상 대상 0이 발생했습니다. | [컴퓨팅 부하](#42-낮은-컴퓨팅-부하와-확장-검증-공백) · [ALB 연결과 배포](#44-alb-초기-연결-실패와-배포-중-처리-용량-소실) | **부분 충족** | 자동 조절은 구현됐으나 인스턴스 교체 중 정상 처리 용량이 사라졌습니다. |
| [PERF02-BP06 Use optimized hardware-based compute accelerators](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_compute_hardware_compute_accelerators.html) | 가속이 필요한 작업에 적합한 전용 하드웨어를 사용합니다. | HTTP API와 저장된 지도·사진 객체를 제공합니다. | [리소스 구성](#11-리소스-구성) | **해당 없음** | HTTP API와 저장된 지도·사진 제공에는 전용 연산 가속 요구가 없습니다. |

### 3.3 PERF03 — 데이터 저장·관리·접근

공식 질문: [PERF 3. How do you store, manage, and access data in your workload?](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf-03.html)

| 공식 BP·명칭 | 점검 기준 | 실제 현재 상태 | 확인 근거 | 판정 | 판정 사유 |
|---|---|---|---|---|---|
| [PERF03-BP01 Use a purpose-built data store that best supports your data access and storage requirements](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_data_use_purpose_built_data_store.html) | 데이터 특성·접근·지연·처리량 요구에 맞는 저장소를 선택합니다. | 객체는 S3, 관계형 데이터는 PostgreSQL로 분리합니다. 실제 DB 업무 부하는 미확인입니다. | [리소스 구성](#11-리소스-구성) · [DB 성능](#43-rds-자원-사용과-미확인-업무-연결) | **확인 불가** | 용도별 저장소는 분리했지만 실제 DB 접근 요구와 업무 부하가 미확인입니다. |
| [PERF03-BP02 Evaluate available configuration options for data store](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_data_evaluate_configuration_options_data_store.html) | 스토리지·메모리·복제·풀링·일관성 옵션을 비교합니다. | gp3·자동 용량 확장·Multi-AZ를 사용합니다. 설정 비교·풀링 검증 기록은 미확인입니다. | [리소스 구성](#11-리소스-구성) · [DB 성능](#43-rds-자원-사용과-미확인-업무-연결) | **확인 불가** | 메모리·복제·연결 관리 설정의 대안 비교 자료가 부족합니다. |
| [PERF03-BP03 Collect and record data store performance metrics](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_data_collect_record_data_store_performance_metrics.html) | 자원 지표와 쿼리·트랜잭션·잠금 성능을 함께 수집합니다. | RDS 자원·연결·I/O 지표를 수집합니다. 쿼리·트랜잭션·잠금 지표의 수집 범위는 미확인입니다. | [DB 성능](#43-rds-자원-사용과-미확인-업무-연결) · [관측과 대응](#46-성능-관측-범위와-운영-대응) | **확인 불가** | 쿼리·트랜잭션·잠금 지표의 수집 자료가 없어 DB 성능 관측 범위의 적절성을 판단하기 어렵습니다. |
| [PERF03-BP04 Implement strategies to improve query performance in data store](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_data_implement_strategies_to_improve_query_performance.html) | 실행 계획·인덱스·데이터 배치로 쿼리를 개선합니다. | pg_stat_statements 사전 로드 설정은 있습니다. 확장 생성·실행 계획·튜닝 기록은 미확인입니다. | [DB 성능](#43-rds-자원-사용과-미확인-업무-연결) | **확인 불가** | 확장 활성화·실행 계획·인덱스와 튜닝 결과가 미확인입니다. |
| [PERF03-BP05 Implement data access patterns that utilize caching](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_data_access_patterns_caching.html) | 읽기 패턴에 맞는 캐시·만료를 적용하고 적중 효과를 관측합니다. | 콘텐츠별 TTL을 적용합니다. 로그의 응답 직전 Hit 비율은 74.9%이며 지도 Hit의 첫 바이트 응답이 짧습니다. | [리소스 구성](#11-리소스-구성) · [콘텐츠 캐시](#45-cloudfront-캐시-결과와-콘텐츠별-응답-성능) | **확인 불가** | 캐시 활용과 응답 차이는 관측되지만 TTL이 콘텐츠 갱신·일관성 요구에 맞는지는 미확인입니다. |

### 3.4 PERF04 — 네트워크와 콘텐츠 전달

공식 질문: [PERF 4. How do you select and configure networking resources in your workload?](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf-04.html)

| 공식 BP·명칭 | 점검 기준 | 실제 현재 상태 | 확인 근거 | 판정 | 판정 사유 |
|---|---|---|---|---|---|
| [PERF04-BP01 Understand how networking impacts performance](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_networking_understand_how_networking_impacts_performance.html) | 경로·대역폭·지연·트래픽이 성능에 미치는 영향을 파악합니다. | API·DB의 VPC 경로와 엣지 전달을 구분하고 네트워크 지표·ALB 로그를 수집합니다. | [리소스 구성](#11-리소스-구성) · [ALB 요청과 응답](#41-alb-요청량과-응답-시간의-표본-차이) · [컴퓨팅 부하](#42-낮은-컴퓨팅-부하와-확장-검증-공백) · [관측과 대응](#46-성능-관측-범위와-운영-대응) | **확인 불가** | 사용자 지연을 네트워크와 애플리케이션 구간으로 나눌 자료와 네트워크 요구가 부족합니다. |
| [PERF04-BP02 Evaluate available networking features](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_networking_evaluate_networking_features.html) | 네트워크 기능의 효과를 시험·지표로 비교합니다. | CloudFront·ALB HTTP/2·AZ 간 분산을 적용합니다. 기능 선택과 비교 시험 기록은 미확인입니다. | [리소스 구성](#11-리소스-구성) · [콘텐츠 캐시](#45-cloudfront-캐시-결과와-콘텐츠별-응답-성능) | **확인 불가** | 기능별 비교 시험과 채택 근거가 부족합니다. |
| [PERF04-BP03 Choose appropriate dedicated connectivity or VPN for your workload](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_networking_choose_appropriate_dedicated_connectivity_or_vpn.html) | 하이브리드 연결 요구에 맞는 전용 연결·VPN을 선택합니다. | 인터넷 사용자와 AWS 내부 서비스가 통신합니다. | [리소스 구성](#11-리소스-구성) | **해당 없음** | 인터넷 사용자와 AWS 서비스 간 통신에 온프레미스 전용 연결 요구는 없습니다. |
| [PERF04-BP04 Use load balancing to distribute traffic across multiple resources](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_networking_load_balancing_distribute_traffic.html) | 로드 밸런서로 분산·TLS 종료·확장 연계를 제공하고 성능을 관측합니다. | ALB가 두 AZ의 API로 분산하고 TLS를 종료합니다. 로그·지표는 있으나 응답 지연 경보는 없습니다. | [리소스 구성](#11-리소스-구성) · [옵저빌리티 구성](#12-옵저빌리티-구성) · [ALB 요청과 응답](#41-alb-요청량과-응답-시간의-표본-차이) | **부분 충족** | 요청 분산·확장 연계는 구현했지만 응답 지연의 경보가 없습니다. |
| [PERF04-BP05 Choose network protocols to improve performance](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_networking_choose_network_protocols_improve_performance.html) | 지연·처리량·호환성 요구로 통신 프로토콜을 선택합니다. | CloudFront HTTP/2·3, ALB HTTP/2, API HTTP/1.1입니다. 요구별 비교 근거는 미확인입니다. | [리소스 구성](#11-리소스-구성) | **확인 불가** | 프로토콜별 지연·처리량·호환성 비교 자료가 부족합니다. |
| [PERF04-BP06 Choose your workload's location based on network requirements](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_networking_choose_workload_location_network_requirements.html) | 사용자·데이터 위치와 네트워크 요구로 배치를 결정합니다. | API·DB·오리진은 서울이며 CloudFront 가격 등급은 PriceClass_200입니다. | [리소스 구성](#11-리소스-구성) · [콘텐츠 캐시](#45-cloudfront-캐시-결과와-콘텐츠별-응답-성능) | **확인 불가** | 사용자 지역 분포와 지연 목표가 없어 배치의 적합성을 판단하기 어렵습니다. |
| [PERF04-BP07 Optimize network configuration based on metrics](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_networking_optimize_network_configuration_based_on_metrics.html) | 네트워크 측정을 바탕으로 설정을 최적화합니다. | 전송량·지연·접근 로그가 존재합니다. 측정에 따른 변경과 전후 검증 기록은 미확인입니다. | [ALB 요청과 응답](#41-alb-요청량과-응답-시간의-표본-차이) · [컴퓨팅 부하](#42-낮은-컴퓨팅-부하와-확장-검증-공백) · [콘텐츠 캐시](#45-cloudfront-캐시-결과와-콘텐츠별-응답-성능) | **확인 불가** | 측정에 따른 설정 변경과 전후 성능 기록이 없습니다. |

### 3.5 PERF05 — 절차와 문화

공식 질문: [PERF 5. How do your organizational practices and culture contribute to performance efficiency in your workload?](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf-05.html)

| 공식 BP·명칭 | 점검 기준 | 실제 현재 상태 | 확인 근거 | 판정 | 판정 사유 |
|---|---|---|---|---|---|
| [PERF05-BP01 Establish key performance indicators (KPIs) to measure workload health and performance](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_process_culture_establish_key_performance_indicators.html) | 업무 목표에 맞는 KPI·임계값·영향을 정의하고 공유합니다. | 자원·오류 경보는 있습니다. 검색·지도 표시·API 업무 KPI의 합의 자료는 미확인입니다. | [옵저빌리티 구성](#12-옵저빌리티-구성) · [관측과 대응](#46-성능-관측-범위와-운영-대응) | **확인 불가** | 업무 KPI와 임계값의 합의·공유 기록이 부족합니다. |
| [PERF05-BP02 Use monitoring solutions to understand the areas where performance is most critical](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_process_culture_use_monitoring_solutions.html) | 사용자부터 애플리케이션·DB까지 중요한 병목을 식별합니다. | ALB·CloudFront 요청과 시스템 그룹의 API 로그를 수집합니다. Agent는 호스트 지표 없이 journald 로그만 수집합니다. | [ALB 요청과 응답](#41-alb-요청량과-응답-시간의-표본-차이) · [DB 성능](#43-rds-자원-사용과-미확인-업무-연결) · [관측과 대응](#46-성능-관측-범위와-운영-대응) | **부분 충족** | 요청과 자원은 관측하지만 호스트 메모리·쿼리 대기를 포함한 병목 관측에 공백이 있습니다. |
| [PERF05-BP03 Define a process to improve workload performance](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_process_culture_workload_performance.html) | 기준 수립·분석·시험·적용·재평가 절차를 운영합니다. | README에는 배포 후 확인 항목이 있습니다. 성능 개선의 담당자·주기·합격 기준 기록은 미확인입니다. | [관측과 대응](#46-성능-관측-범위와-운영-대응) | **확인 불가** | 성능 개선의 담당·주기·합격 기준과 실행 기록이 미확인입니다. |
| [PERF05-BP04 Load test your workload](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_process_culture_load_test.html) | 대표·예상 초과 부하에서 전체 처리 능력과 병목을 검증합니다. | 운영 요청과 CPU 지표는 있습니다. 부하 시험 시나리오·결과는 미확인입니다. | [ALB 요청과 응답](#41-alb-요청량과-응답-시간의-표본-차이) · [컴퓨팅 부하](#42-낮은-컴퓨팅-부하와-확장-검증-공백) · [DB 성능](#43-rds-자원-사용과-미확인-업무-연결) | **확인 불가** | 대표·예상 초과 부하의 시험 시나리오와 처리 한계 자료가 없습니다. |
| [PERF05-BP05 Use automation to proactively remediate performance-related issues](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_process_culture_automation_remediate_issues.html) | 성능 저하를 자동 조치하거나 대응 가능한 운영자에게 전달합니다. | 자동 확장 동작은 활성화됐으나 사용자 정의 경보 9개는 통지하지 않고 교체 자동 롤백은 꺼져 있습니다. | [옵저빌리티 구성](#12-옵저빌리티-구성) · [ALB 연결과 배포](#44-alb-초기-연결-실패와-배포-중-처리-용량-소실) · [관측과 대응](#46-성능-관측-범위와-운영-대응) | **부분 충족** | CPU 자동 조절은 있으나 성능 저하를 운영자 통지·배포 중단·롤백으로 연결하지 않습니다. |
| [PERF05-BP06 Keep your workload and services up-to-date](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_process_culture_keep_workload_and_services_up_to_date.html) | 업데이트를 평가하고 호환성·성능 검증 후 적용합니다. | 시작 템플릿 버전 2와 인스턴스 교체 이력이 있습니다. 정기 업데이트 평가·성능 시험 기록은 미확인입니다. | [리소스 구성](#11-리소스-구성) · [ALB 연결과 배포](#44-alb-초기-연결-실패와-배포-중-처리-용량-소실) | **확인 불가** | 업데이트 평가·호환성·성능 시험과 적용 기록이 부족합니다. |
| [PERF05-BP07 Review metrics at regular intervals](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_process_culture_review_metrics.html) | 지표·기준선·경보를 주기적으로 검토하고 후속 조치를 기록합니다. | 지표와 경보 이력은 존재합니다. 정기 검토 일정과 후속 조치 기록은 미확인입니다. | [옵저빌리티 구성](#12-옵저빌리티-구성) · [관측과 대응](#46-성능-관측-범위와-운영-대응) | **확인 불가** | 정기 검토 일정과 후속 조치의 실행 기록이 미확인입니다. |

## 4. Findings and Insights(발견 사항 및 인사이트)

### 4.1 ALB 요청량과 응답 시간의 표본 차이

**ALB의 대상 응답은 짧지만, 대상 응답 로그의 약 94%가 404입니다.** 정상 업무의 처리 성능을 판단하려면 검색·시설 상세 등 실제 기능의 성공 응답과 지연을 구분해야 합니다.

공통 기간의 요청·응답 지표는 서울 CloudWatch의 ALB `arcamap-api`, 접근 로그는 `/aws/vendedlogs/elb/arcamap-api`에 있습니다. 대상 응답 시간은 ALB가 API로 요청을 전달한 뒤 응답을 받기까지의 시간입니다.

| 관측 항목 | 공통 기간의 값 |
|---|---|
| 요청 수 | **7,616건** |
| 최대 5분 요청량 | 9월 15일 13:50 구간 **1,140건**, 해당 5분 평균 **3.8건/초** |
| 대상 응답 시간 | 표본 수를 반영한 가중 평균 **5.7 ms** |
| 접근 로그의 대상 처리 시간 | 평균 **5.7 ms**, p95 **55 ms**, p99 **67 ms**, 최대 **176 ms** |
| ALB 발생 5xx | **307건** |
| 대상 연결 오류 | **303건** |

p95와 p99는 각각 요청의 95%와 99%가 그 이내에 처리된 시간입니다. 로그의 대상 처리 시간은 대상 응답이 기록된 7,310건에 대한 값입니다.

| 접근 로그 응답 | 건수 | 요청 처리 결과 |
|---|---:|---|
| 대상 404 | 6,870 | API가 요청한 자원을 제공하지 못했습니다. |
| 대상 200 | 440 | API가 정상 HTTP 응답을 반환했습니다. |
| ALB 301 | 2,375 | HTTP 요청을 HTTPS로 전환했습니다. |
| ALB 400 | 873 | ALB가 대상 응답 없이 요청을 거부했습니다. |
| ALB 502·503 | 303·4 | 대상 연결·전달에 실패했습니다. |
| ALB 464·460 | 2·1 | 프로토콜 또는 클라이언트 연결 관련 응답입니다. |
| 전체 | **10,868** | 리디렉션과 대상에 도달하지 못한 요청을 포함합니다. |

[ALB 요청 지표](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-cloudwatch-metrics.html)는 대상 선택 전 거부된 요청을 제외하므로 접근 로그와 집계 범위가 다릅니다. 지표는 9월 14일 01:50부터, 대상 응답 시간은 같은 날 22:40부터 5분 구간으로 기록되어 있습니다. 접근 로그의 기록 범위는 9월 14일 01:17:54~21일 23:56:57입니다.

> **업무 성능 판단 제약**: 대상 응답 시간에는 연결 실패의 대기가 포함되지 않고, HTTP 200도 업무 기능과 연결되어 있지 않습니다. 따라서 현재 응답 분포와 최대 요청량으로 업무별 성능 목표 달성이나 처리 한계를 판단하기 어렵습니다.

404의 원인은 요청 경로와 기능별 응답을 연결해 구분해야 합니다. 정상 업무의 성공률·처리량·지연을 함께 관측하면 오류 응답이 많은 현재 트래픽에서도 자원 크기와 확장 목표를 판단할 기준을 세울 수 있습니다. 연결 실패의 경위는 [4.4 초기 오류와 배포](#44-alb-초기-연결-실패와-배포-중-처리-용량-소실)에 연결됩니다.

관련 기준: [PERF01](#31-perf01--자원과-아키텍처-선택)의 BP06·BP07, [PERF05](#35-perf05--절차와-문화)의 BP01·BP02·BP04.

### 4.2 낮은 컴퓨팅 부하와 확장 검증 공백

**현재 API 두 대의 평균 CPU는 각각 1% 미만으로 확장 목표 50%보다 낮습니다.** 공통 기간의 서울 CloudWatch EC2 지표이며, 평균은 관측 표본 수인 `SampleCount`를 반영한 가중 평균입니다. 최대는 개별 관측값의 최댓값입니다.

| API 인스턴스 | CPU 관측 범위 | CPU 평균 | CPU 최대 |
|---|---|---:|---:|
| 현재 `i-0c1479ceb7baccd9f` | 9월 15일 01:30~21일 23:55 | 0.56% | 4.70% |
| 현재 `i-0aed6bfc82622f097` | 9월 15일 01:30~21일 23:55 | 0.64% | 15.67% |
| 교체 전 `i-0714ee9ba1e451644` | 9월 14일 01:50~15일 01:35 | 0.43% | 11.86% |
| 교체 전 `i-08cc1ba2a3e576955` | 9월 14일 01:50~15일 01:35 | 0.40% | 6.72% |

표의 시각은 5분 관측 구간의 시작입니다. 현재 인스턴스 두 대는 9월 15일 01:33:48에 시작됐습니다. 인스턴스 구성은 [API 시작 템플릿](../../terraform/modules/compute/main.tf#L1)에 연결됩니다.

ASG `arcamap-api`의 가동 수와 목표 수량은 9월 14일 18:05~21일 23:55의 5분 관측에서 모두 **2대**였습니다. 공통 기간의 ASG 활동은 최초 생성과 배포에 따른 교체였으며, CPU 목표 추적에 따른 수량 변경 기록은 없었습니다.

자동 확장 경보는 **1분마다 평가하지만 CPU는 5분마다 수집**합니다. 경보 평가 자료에는 CPU 값 사이에 빈 구간이 있습니다. 이 간격과 새 인스턴스의 준비 시간이 부하 증가에 대한 대응 속도를 늦출 수 있으므로, 확장 시 지연·오류와 준비 시간을 함께 시험해야 합니다.

> **용량 판단 제약**: 리소스 생성 초기의 지표와 호스트 메모리·동시 처리량·대표 부하 시험 자료가 부족합니다. 현재 크기를 줄여도 되는지, 최대 4대로 피크 수요를 감당할 수 있는지는 미확인입니다.

대표 업무의 성능 목표와 메모리·동시성 관측을 마련하면 현재 사용률을 자원 크기 결정에 활용할 수 있습니다. 크기와 확장 정책을 조정할 때는 두 가용 영역에서 필요한 정상 처리 용량을 유지해야 합니다.

관련 기준: [PERF02](#32-perf02--컴퓨팅-자원-선택과-사용)의 BP02·BP03·BP04·BP05, [PERF05](#35-perf05--절차와-문화)의 BP04.

### 4.3 RDS 자원 사용과 미확인 업무 연결

**RDS는 자원 여유가 있지만 실제 업무 쿼리의 부하는 미확인입니다.** 공통 기간의 서울 CloudWatch `arcamap-postgres` 지표에서 CPU 평균은 **5.23%**, DB 연결 수의 관측 최댓값은 **0**입니다.

| 관측 항목 | 공통 기간의 값 |
|---|---|
| CPU | 표본 수를 반영한 가중 평균 **5.23%**, 개별 관측 최댓값 **29.34%** |
| 가용 메모리 | 최소 **2.82 GiB** |
| 가용 저장 공간 | 최소 **17.06 GiB** |
| DB 연결 수 | 관측 최댓값 **0** |
| 읽기·쓰기 IOPS | 5분 평균의 최댓값 **3.17·13.88 IOPS** |
| 읽기·쓰기 지연 | 5분 평균의 최댓값 **2.2·48.9 ms** |
| 디스크 대기열 | 최대 **0.43** |

IOPS는 초당 입출력 횟수이며 디스크 대기열은 처리 대기 중인 입출력 요청 수입니다. CPU는 9월 14일 00:40, 나머지 지표는 00:45의 5분 구간부터 9월 21일 23:55까지 기록되어 있습니다. CPU 최댓값은 DB가 생성된 9월 14일 00:45 구간에 발생했습니다.

ALB의 HTTP 200 응답과 DB 연결 수 0이 함께 관측되었습니다. DB를 사용하지 않는 요청이나 짧은 연결이 포함될 수 있어 API의 어떤 기능이 DB 부하를 만드는지 연결할 필요가 있습니다. 현재 파라미터 그룹은 쿼리 통계용 `pg_stat_statements`의 사전 로드를 설정하지만, 확장 활성화와 실행 계획·인덱스·잠금·연결 풀 상태는 미확인입니다.

> **DB 성능 판단 제약**: 대표 쿼리와 API 처리의 연결 자료가 없어 자원 크기·IOPS·읽기 처리 용량의 적정성을 판단하기 어렵습니다. 생성 직후 CPU 상승의 내부 작업 원인도 미확인입니다.

DB를 사용하는 기능의 성공률과 처리 시간에 쿼리 통계·실행 계획을 연결하면 자원 부족과 쿼리 병목을 구분할 수 있습니다. 자원 변경은 그 결과에 따라 결정하며, 현재 Multi-AZ의 장애 조치 기능을 유지해야 합니다.

관련 기준: [PERF03](#33-perf03--데이터-저장관리접근)의 BP01·BP02·BP03·BP04.

### 4.4 ALB 초기 연결 실패와 배포 중 처리 용량 소실

**초기 대상 연결 실패와 배포 중 정상 대상 소실이 API 처리 용량에 영향을 주었습니다.** 공통 기록은 운영 우수성의 [초기 API 준비 지연과 ALB 오류](01-operational-excellence.md#44-초기-api-준비-지연과-alb-오류), [API 배포의 정상 처리 용량 공백](01-operational-excellence.md#41-api-배포의-정상-처리-용량-공백)에 있습니다. 근거는 ALB `arcamap-api`의 로그·정상 대상 지표, ASG 활동과 교체 이력입니다.

| 발생 시각 | 운영 기록 |
|---|---|
| 9월 14일 01:27:45~01:48:35 | ASG 생성 전 ALB가 **503 4건**을 반환했습니다. |
| 9월 14일 01:51:22~01:52:21 | ASG의 서비스 연결 역할 인수가 거부되어 시작 활동 **3건**이 실패했습니다. 이후 두 인스턴스의 시작 활동은 01:57:27·01:59:25에 완료됐습니다. |
| 9월 14일 01:55:39~22:35:19 | 대상 상태 코드가 없는 **502 303건**과 대상 연결 오류 303건이 기록됐습니다. |
| 9월 14일 22:40:20~22:46:43 | 첫 정상 헬스 체크가 기록됐고, 정상 대상 경보가 22:46:43에 회복됐습니다. |
| 9월 15일 01:33:46~01:34:26 | 배포가 기존 두 대를 제외하고 새 두 대를 시작했습니다. 헬스 체크에는 시간 초과 4건·연결 재설정 4건이 기록됐습니다. |
| 9월 15일 01:34·01:35 | 1분 단위 정상 대상 수의 최솟값이 **0대**였습니다. 01:36부터 2대가 관측됐습니다. |
| 9월 15일 01:38:43~01:40:43 | 정상 대상 경보가 경보 상태에 머물렀습니다. 인스턴스 교체는 01:39:33에 완료됐습니다. |

서비스 연결 역할 인수 거부는 초기 세 번의 시작 실패 원인입니다. 인스턴스가 시작된 뒤에도 이어진 대상 연결 실패의 내부 원인은 미확인입니다. 이 구간은 CPU 사용률이 낮아도 API가 요청을 처리할 준비를 갖추지 못할 수 있음을 보여 줍니다.

배포의 [인스턴스 교체 정책](../../terraform/modules/compute/main.tf#L65)은 최소 정상 비율 **0%**, 최대 **100%**, 준비 시간 **300초**를 사용합니다. 당시 자동 롤백과 경보 연결은 꺼져 있었습니다. 기존 두 대가 함께 제외된 뒤 정상 대상이 사라졌으며, 같은 시간의 ASG 가동 수 2대만으로는 이러한 처리 용량 공백을 감지할 수 없었습니다. 운영상 중단을 허용하는 기준은 미확인입니다.

> **중단 영향 제약**: 9월 15일 01:33의 정상 대상 지표가 없고 이후 값은 1분 최솟값이므로 정확한 연속 중단 시간은 미확인입니다. 교체 중 사용자 실패 건수와 초기 5xx의 업무 손실도 요청별 업무 기록이 없어 산정하기 어렵습니다.

배포 중 허용할 수 있는 중단 시간과 유지할 정상 처리 용량을 먼저 정해야 합니다. 연속적인 API 제공이 필요하다면 새 대상의 준비를 확인한 뒤 기존 대상을 제외하고, 정상 대상 경보에 배포 중단·롤백을 연결해야 합니다. 이때 임시 용량과 준비 시간이 늘어날 수 있으므로 배포 상한도 함께 정해야 합니다.

관련 기준: [PERF01](#31-perf01--자원과-아키텍처-선택)의 BP04, [PERF02](#32-perf02--컴퓨팅-자원-선택과-사용)의 BP05, [PERF05](#35-perf05--절차와-문화)의 BP02·BP05.

### 4.5 CloudFront 캐시 결과와 콘텐츠별 응답 성능

**지도 캐시 Hit의 첫 바이트 응답은 Miss보다 짧습니다.** 공통 기간 CloudFront `arcamap.app`의 요청 지표와 접근 로그는 각각 **14,181건**이며, HTTP 403 응답과 전송 중 연결 종료도 포함합니다.

지표는 버지니아 북부 CloudWatch의 배포 `E39UQTOCMBVZB3`, 로그는 [CloudFront 로그 버킷](../../terraform/modules/cloudfront/main.tf#L152)에 있습니다. 접근 로그의 기간은 `date`·`time`에 기록된 응답 완료 시각을 기준으로 합니다.

| 관측 항목 | 공통 기간의 값 |
|---|---|
| 요청 수 | 지표·접근 로그 각각 **14,181건** |
| 다운로드 | **357.5 MB** |
| 최대 5분 요청량 | 9월 20일 16:35 구간 **1,096건** |
| 5xx 오류율 | 관측값 모두 **0%** |
| 지표·로그 범위 | 지표는 9월 14일 01:05~21일 23:55의 5분 구간, 로그는 9월 14일 01:07:08~21일 23:57:55입니다. |

| 로그 HTTP 상태 | 건수 | 요청 처리 결과 |
|---|---:|---|
| 200 | 996 | 객체를 반환했습니다. |
| 206 | 4,401 | 지도 파일 `/20260907.pmtiles`의 일부 범위를 반환했습니다. |
| 301 | 2,631 | HTTP 요청을 HTTPS로 전환했습니다. |
| 304 | 29 | 객체가 변경되지 않았습니다. |
| 403 | 6,084 | 접근 거부 응답이며 전체의 **42.9%**입니다. |
| 000 | 40 | 응답 전 클라이언트가 연결을 닫았습니다. |

[CloudFront 로그 필드](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/standard-logs-reference.html)의 `x-edge-response-result-type`은 응답 직전, `x-edge-result-type`은 전송 종료 후의 분류입니다. 전송 도중 클라이언트가 연결을 닫으면 정상 HTTP 응답도 최종 `Error`로 바뀔 수 있습니다. `RefreshHit`는 캐시 객체의 최신 여부를 원본에 재확인한 결과입니다.

| 캐시·처리 분류 | 응답 직전 | 전송 종료 후 |
|---|---:|---:|
| Hit | 4,068 | 3,585 |
| Miss | 744 | 490 |
| RefreshHit | 616 | 616 |
| Error | 6,122 | 6,859 |
| Redirect | 2,631 | 2,631 |

응답 직전 Hit·Miss·RefreshHit 중 **Hit 비율은 74.9%**입니다. 이 값은 접근 로그의 캐시 분류 비율입니다. 최종 Error에는 지도 206 응답 **732건**과 정적 자산 200 응답 **4건**도 포함되므로 최종 Error 수와 HTTP 실패 수는 다릅니다.

지도 206 응답의 첫 바이트 시간은 엣지 서버가 요청을 받은 뒤 응답 첫 바이트를 쓰기까지의 시간입니다. 아래 평균·p95는 공통 기간의 해당 요청에 대한 값입니다.

| 지도 206의 최종 처리 결과 | 요청 수 | 첫 바이트 평균 | 첫 바이트 p95 | 전체 응답 평균 |
|---|---:|---:|---:|---:|
| Hit | 3,468 | **8.2 ms** | 65 ms | 12.3 ms |
| Miss | 188 | **127.2 ms** | 620 ms | 200.5 ms |
| RefreshHit | 13 | **412.2 ms** | 593 ms | 414.6 ms |
| Error | 732 | 85.4 ms | 119 ms | 91.1 ms |

캐시 Hit은 원본 접근 없이 지도 데이터를 제공하며 낮은 응답 지연이 관측되었습니다. 요청 범위·엣지 위치·클라이언트 연결 조건도 서로 달라 캐시만의 개선 효과를 분리하기는 어렵습니다.

홈 경로 `/`·`/index.html`의 200 응답은 **Hit 2건·Miss 158건·RefreshHit 474건**입니다. 홈 콘텐츠에는 원본 재확인이 자주 발생했습니다. 현재 정적 파일 정책의 TTL은 최대 300초이지만, 객체별 `Cache-Control`과 갱신 이력이 없어 재확인의 원인과 만료 시간의 적정성은 미확인입니다. 사진 경로의 요청 기록이 없어 사진 캐시의 효과도 확인하기 어렵습니다.

> **콘텐츠 성능 판단 제약**: 403의 원인과 지도 전송 중단의 사용자 영향, 화면 표시 완료 시간과 콘텐츠 신선도 요구가 미확인입니다. 현재 로그만으로 사용자 경험과 갱신 적합성을 판단하기 어렵습니다.

정상 콘텐츠 경로의 403과 전송 중단을 실제 화면 동작에 연결하면 사용자 영향을 파악할 수 있습니다. 홈 HTML과 버전이 붙은 정적 자산의 갱신 조건을 나누어 TTL·캐시 키·무효화 기준을 정하면 필요한 신선도를 유지하면서 원본 재확인을 줄일 수 있습니다. 기존 로그의 캐시 분류와 응답 시간을 변경 전후 비교에 활용할 수 있습니다.

관련 기준: [PERF01](#31-perf01--자원과-아키텍처-선택)의 BP04, [PERF03](#33-perf03--데이터-저장관리접근)의 BP05, [PERF04](#34-perf04--네트워크와-콘텐츠-전달)의 BP02·BP06·BP07.

### 4.6 성능 관측 범위와 운영 대응

**요청·자원·API 로그는 수집하지만 업무별 지연과 DB 처리를 연결할 자료가 부족합니다.** API 관련 기록은 시스템 로그 그룹에 있으며, 사용자 정의 경보는 운영자에게 알림을 보내지 않습니다.

| 대상 | 현재 상태와 성능 판단 |
|---|---|
| API 로그 | `/arcamap/ec2/system`에 현재·교체 전 API와 빌드 인스턴스의 API 관련 기록이 있습니다. [운영 우수성의 API 기록](01-operational-excellence.md#43-시스템-로그와-api-기록-수집)은 수집 경로와 공통 기간의 기록 범위를 설명합니다. 업무 요청·예외·DB 호출을 연결하는 필드와 사용 범위는 미확인입니다. |
| 호스트 지표 | [CloudWatch Agent](../../terraform/env/was/main.tf#L43)는 journald 로그를 수집합니다. 메모리·프로세스 지표 수집 설정이 없어 CPU 이외의 호스트 병목을 설명하기 어렵습니다. |
| ALB·CloudFront | 접근·연결·헬스 체크와 캐시 분류·응답 시간이 기록됩니다. 초기 연결 실패와 콘텐츠별 응답 차이를 파악할 수 있습니다. |
| DB 내부 성능 | 자원·연결·I/O 지표와 PostgreSQL 로그가 있습니다. 상위 쿼리·잠금·실행 계획과 업무별 DB 지연은 미확인입니다. |
| 경보·대응 | 사용자 정의 경보 9개는 통지하지 않고 ALB 응답 지연 경보도 없습니다. 최근 교체에는 자동 롤백·경보 연결이 없어 성능 저하를 운영자 대응이나 배포 중단으로 연결하지 못합니다. |

> **사용자·운영 자료 제약**: 사용자 지역별 지연·화면 성능, 업무 KPI 합의, 벤치마크·부하 시험, 정기 지표 검토 기록이 없어 네트워크 배치의 적합성과 성능 관리 절차의 운영 수준은 미확인입니다.

대표 사용자 동작에 API 로그·응답·DB 처리를 연결하고, 필요한 호스트 지표를 보완하면 병목 위치를 구분하기 쉬워집니다. 업무별 지연·오류·처리량 목표에 맞춰 기존 경보의 통지와 대응 조건을 정해야 합니다. 로그 보존 기간은 현재 30일을 유지하면서 필요한 기록을 활용할 수 있습니다.

관련 기준: [PERF02](#32-perf02--컴퓨팅-자원-선택과-사용)의 BP03, [PERF03](#33-perf03--데이터-저장관리접근)의 BP03, [PERF05](#35-perf05--절차와-문화)의 BP01·BP02·BP05·BP07.

## 5. Conclusion(결론)

ArcaMap은 **엣지 캐시·두 가용 영역의 요청 분산·CPU 기반 자동 확장·용도별 저장소**를 운영합니다. API와 DB의 CPU 사용률은 낮고 지도 캐시 Hit의 응답 지연도 짧습니다. 다만 API 응답의 대부분이 404이며 실제 DB 업무 부하가 미확인이라 현재 자원 크기와 최대 처리 용량의 적정성은 판단하기 어렵습니다.

우선 과제는 **초기 연결 실패의 원인 파악과 배포 중 정상 대상 유지**, **업무별 성공률·지연·처리량과 DB 처리의 연결**입니다. 콘텐츠는 403·전송 중단의 사용자 영향과 홈·정적 자산·지도의 갱신 요구를 확인해야 합니다. 캐시 로그는 활용되고 있으며, 캐시 만료 시간과 네트워크 배치의 적합성에는 신선도·사용자 지연 요구가 더 필요합니다.

성능 목표와 중단 허용 조건을 정하고 기존 관측·경보를 보완하면 자원 크기·확장 정책·캐시 설정의 변경 효과를 판단할 수 있습니다. 이때 필요한 정상 처리 용량과 DB 장애 조치, 콘텐츠 신선도를 함께 유지해야 합니다.
