# Reliability(신뢰성)

**🛡️ 두 가용 영역의 API·RDS와 별도 콘텐츠 제공 경로로 장애에 대비하는 구성**

ArcaMap은 웹·지도·사진을 CloudFront와 S3로 제공하고 API 요청은 ALB 뒤의 서버에서 처리합니다. API는 인스턴스 자동 교체와 확장으로, 데이터베이스는 Multi-AZ와 자동 백업으로 장애에 대비합니다. 배포 중 정상 처리 용량과 운영자 알림은 보완이 필요합니다.

**공통 집계 기간**은 KST **2026-09-14 00:00:00 이상, 2026-09-22 00:00:00 미만**입니다. **구성 확인 시점**은 KST **2026-09-22 15:43~15:54**입니다. 문서의 날짜·시각은 KST입니다.

[현재 운영 현황](#1-current-operations현재-운영-현황) · [기둥의 원칙](#2-pillar-principles기둥의-원칙에-따른-검토) · [질문·모범 사례](#3-questions-and-best-practices질문-및-모범-사례별-상세-점검) · [발견 사항](#4-findings-and-insights발견-사항-및-인사이트) · [결론](#5-conclusion결론)

## 1. Current Operations(현재 운영 현황)

### 1.1 리소스 구성

서비스 `arcamap.app`의 API·데이터베이스·콘텐츠 저장소는 **서울(ap-northeast-2)**에 있습니다. API와 데이터베이스는 **두 가용 영역(AZ)**에 분산하며 CloudFront는 전 세계 엣지에서 콘텐츠를 제공합니다.

| 구성 요소 | 역할·설정 | Terraform 정의 |
|---|---|---|
| VPC·서브넷 | `10.0.0.0/16` 안에서 퍼블릭·API·DB 서브넷을 역할별로 나눕니다. 각 역할에 /24 서브넷을 두 개씩 두고 2a·2c에 배치합니다. | [네트워크·서브넷](../../terraform/modules/network/main.tf#L1) |
| NAT Gateway | AZ마다 하나씩 배치합니다. API는 같은 AZ의 NAT를 통해 외부에 연결하고 DB는 VPC 내부에서 통신합니다. | [NAT·라우팅](../../terraform/modules/network/main.tf#L62) |
| ALB `arcamap-api` | 두 AZ에서 HTTPS 요청을 받아 API의 HTTP 8080으로 전달합니다. 교차 AZ 분산은 활성화되어 있고 세션 고정은 꺼져 있습니다. 유휴 제한은 60초, 등록 해제 지연은 300초입니다. | [ALB·리스너·대상 그룹](../../terraform/modules/alb/main.tf#L1) |
| ALB 상태 검사 | `/health`를 30초마다 검사합니다. 응답 제한은 5초이며 HTTP 200이 연속 5회이면 정상, 실패가 연속 2회이면 비정상으로 판정합니다. 현재 대상 두 대는 정상입니다. | [상태 검사](../../terraform/modules/alb/main.tf#L14) |
| Auto Scaling 그룹(ASG) `arcamap-api` | API `t3.small` 두 대를 AZ별로 한 대씩 운영하며 2~4대 범위에서 평균 CPU 50%를 목표로 확장·축소합니다. ALB 상태에 따라 비정상 인스턴스를 교체하고 초기 상태 검사 유예와 준비 시간은 각각 300초입니다. | [ASG·확장 정책](../../terraform/modules/compute/main.tf#L44) |
| 시작 템플릿·Image Builder | API 두 대는 시작 템플릿 버전 2와 이미지 `arcamap-api/1.1.2/1`을 사용합니다. 이미지 기동·연결 시험 후 인스턴스를 교체합니다. 최근 교체는 최소 정상 비율 0%이며 자동 롤백과 경보 연결이 없습니다. | [시작 템플릿·교체](../../terraform/modules/compute/main.tf#L1), [이미지·시험](../../terraform/modules/image-builder/main.tf#L195) |
| RDS `arcamap-postgres` | PostgreSQL 17.11·`db.t4g.medium`의 Multi-AZ 구성입니다. 주 인스턴스는 2c, 대기는 2a에 있습니다. 저장 공간은 20 GiB부터 최대 100 GiB까지 자동 확장합니다. 자동 백업은 3일 보존하며 매일 23:43~다음 날 00:13에 수행합니다. 암호화와 삭제 보호가 활성화되어 있습니다. | [RDS·백업](../../terraform/modules/database/main.tf#L6), [DB 구성](../../terraform/env/db/main.tf#L72) |
| CloudFront | 기본 경로는 웹 S3, `/photos/*`는 사진 S3, `/20260907.pmtiles`는 지도 S3로 연결합니다. 오리진 연결은 최대 3회 시도하며 연결 제한은 10초, 읽기 제한은 30초입니다. 대체 오리진 그룹은 없습니다. | [CloudFront](../../terraform/modules/cloudfront/main.tf#L60), [오리진 연결](../../terraform/env/web/main.tf#L39) |
| DNS·사설망 | API와 웹의 DNS 레코드를 Terraform으로 정의합니다. VPC에는 외부 사설망 연결이 없습니다. | [API DNS](../../terraform/env/was/main.tf#L158), [웹 DNS](../../terraform/env/web/main.tf#L60), [라우팅](../../terraform/modules/network/main.tf) |

S3는 콘텐츠·배포 파일·로그를 역할별로 저장합니다. 사진의 이전 버전은 보존하지만 다른 버킷에는 버전 관리가 없으며 버킷 간 복제도 구성되어 있지 않습니다.

| 저장소 역할 | 복구·보존 설정 | Terraform 정의 |
|---|---|---|
| 웹 콘텐츠 | 버전 관리·수명 주기 설정이 없습니다. | [웹 버킷](../../terraform/env/web/main.tf#L14) |
| 사진 | 버전 관리가 활성화되어 있으며 이전 버전은 7일 후 만료됩니다. | [사진 버킷](../../terraform/env/web/main.tf#L14), [이전 버전 보존](../../terraform/modules/s3-bucket/main.tf#L34) |
| 지도 | 버전 관리·수명 주기 설정이 없습니다. | [기존 지도 버킷](../../terraform/env/web/main.tf#L3) |
| API 배포 파일 | 버전 관리·수명 주기 설정이 없습니다. | [배포 버킷·산출물](../../terraform/env/was/deployment.tf#L1) |
| CloudFront 접근 로그 | 객체는 30일 후 만료됩니다. | [로그 버킷](../../terraform/env/web/main.tf#L14) |

정적 콘텐츠 요청은 **CloudFront → S3**로, API 요청은 **ALB → API → RDS**로 이어집니다. 콘텐츠와 API의 실행 경로가 나뉘어 API 인스턴스 교체가 콘텐츠 원본 제공에 직접 영향을 주지 않습니다.

### 1.2 옵저빌리티 구성

로그·지표·요청 추적으로 서비스 상태를 파악하는 **옵저빌리티**를 구성합니다. CloudWatch는 자원 부족과 오류를 감지하고 ASG는 CPU 부하에 따라 용량을 조절합니다. **서비스 경보에는 운영자 알림이 연결되어 있지 않습니다.**

| 관측 대상 | 도구·설정 | 운영 목적 |
|---|---|---|
| API 처리 용량 | `arcamap-asg-inservice·arcamap-alb-healthy-hosts`는 실행 인스턴스·정상 대상 수가 2대 미만인 상태를 감지합니다. | 실행 중인 서버 수와 요청을 받을 수 있는 서버 수를 각각 파악합니다. |
| EC2 상태·CPU | `arcamap-ec2-status-check·arcamap-ec2-cpu`는 상태 검사 실패와 CPU 80% 이상을 감지합니다. EC2 상세 모니터링은 꺼져 있습니다. | 인스턴스 이상과 지속적인 과부하를 감지합니다. |
| API 오류 | `arcamap-alb-5xx·arcamap-api-5xx`는 ALB·API의 5xx 응답이 5분에 5건 이상이면 경보를 발생시킵니다. | 요청 처리 오류를 감지합니다. 누락 데이터는 임계값을 넘지 않은 것으로 처리합니다. |
| DB 자원 | `arcamap-rds-cpu·arcamap-rds-free-memory·arcamap-rds-free-storage`는 CPU 80% 이상, 가용 메모리 512 MiB 미만, 가용 저장 공간 5 GiB 미만을 감지합니다. | DB 자원 부족에 대비합니다. |
| 자동 확장·통지 | CPU 목표 추적 경보 2개는 ASG 정책을 실행합니다. 서비스 경보 9개는 동작이 비활성화되어 있고 알림 대상도 없습니다. | 용량 조절은 자동화되어 있으나 장애 통지는 이루어지지 않습니다. |
| 사용자 기능·서비스 목표 | CloudWatch 대시보드와 정기적으로 사용자 경로를 실행하는 Synthetics Canary는 없습니다. | 외부 계측과 업무 성공률·응답 시간의 목표는 자료가 없어 확인 불가입니다. |

경보 정의는 [API 경보](../../terraform/env/was/main.tf#L59), [DB 경보](../../terraform/env/db/main.tf#L21), [알림 동작](../../terraform/modules/cloudwatch-alarm/main.tf#L15)에 있습니다. 로그 수집은 [API의 CloudWatch Agent](../../terraform/env/was/main.tf#L44)와 [DB 로그 내보내기](../../terraform/modules/database/main.tf), [콘텐츠 로그 전달](../../terraform/modules/cloudfront/main.tf)로 구성합니다.

### 1.3 텔레메트리 수집 현황

운영 중 발생한 로그·지표·이벤트·추적 기록인 **텔레메트리**를 아래 경로로 수집합니다.

| 종류·대상 | 수집 경로·위치 | 범위·상태 |
|---|---|---|
| 인프라 지표 | 서울 CloudWatch의 ALB·ASG·EC2·RDS·EC2 사용량 지표 | 공통 기간의 자원·요청 지표가 있습니다. ALB는 1분, 인스턴스별 CPU는 5분 단위입니다. |
| 시스템·API 로그 | journald → CloudWatch Agent → `/arcamap/ec2/system`의 인스턴스별 스트림 | 보존 30일이며 공통 기간의 시스템·API 기록이 있습니다. |
| API 전용 로그 | `/arcamap/api/application` | 보존 30일이며 스트림이 없습니다. |
| ALB 로그 | CloudWatch Logs `/aws/vendedlogs/elb/arcamap-api`의 접근·연결·헬스 체크 스트림 | 보존 30일이며 공통 기간의 기록이 있습니다. |
| RDS 로그 | `/aws/rds/instance/arcamap-postgres/postgresql·upgrade` | 보존 30일이며 PostgreSQL 스트림이 있습니다. |
| 이미지 시험 | Image Builder → `/aws/imagebuilder/arcamap-api` | 보존 30일이며 이미지 빌드·시험 기록이 있습니다. |
| CloudFront 접근 로그 | 버지니아 북부(us-east-1)의 `arcamap-cloudfront` 로그 전달 → [서울 S3 로그 버킷](../../terraform/env/web/main.tf#L14) | 객체 보존 30일이며 공통 기간의 접근 기록이 있습니다. |
| 서비스 이벤트 | ASG 활동·교체 이력, RDS 이벤트, CloudWatch 경보 이력 | 공통 기간의 생성·배포·백업·경보 기록이 있습니다. |
| 분산 추적 | 서울 X-Ray 서비스 그래프 | 공통 기간의 그래프 기록은 없습니다. |

## 2. [Pillar Principles(기둥의 원칙에 따른 검토)](https://docs.aws.amazon.com/wellarchitected/latest/framework/reliability.html)

AWS의 [신뢰성 정의](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel-def.html)는 **필요한 때에 의도한 기능을 정확하고 일관되게 수행하는 능력**입니다. 기반·워크로드 아키텍처·변경 관리·장애 관리에 걸쳐 서비스의 운영과 시험을 다룹니다.

| [공식 설계 원칙](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel-dp.html) | 현재 운영 | 부족하거나 확인이 필요한 사항 |
|---|---|---|
| Automatically recover from failure(장애에서 자동 복구) | ASG가 비정상 인스턴스를 교체하고 RDS Multi-AZ가 DB 장애에 대비합니다. | [운영자 알림](#42-api-초기-연결-오류와-운영자-통지-공백)과 [배포 롤백](#41-api-동시-교체로-정상-대상이-없어진-구간)이 없습니다. 업무 기능의 장애 감지는 [계측 자료](#44-로그-수집-경로와-업무-관측의-공백)가 부족해 확인 불가입니다. |
| Test recovery procedures(복구 절차 시험) | 이미지의 자동 기동·API·DB 연결을 시험합니다. | [백업 복원·장애 조치](#43-rds-자동-백업의-복원-범위와-미검증된-복구-목표)의 실행 결과와 소요 시간은 확인 불가입니다. |
| Scale horizontally to increase aggregate workload availability(수평 확장으로 전체 가용성 향상) | 두 AZ에 API·NAT를 배치하고 콘텐츠 제공 경로를 분리합니다. | [동시 교체](#41-api-동시-교체로-정상-대상이-없어진-구간)는 API 전체에 영향을 주었습니다. [한 AZ의 잔여 용량](#45-관측-부하와-장애-시-처리-용량의-차이)도 시험 자료가 필요합니다. |
| Stop guessing capacity(관측을 바탕으로 용량 결정) | CPU 목표 추적과 RDS 저장 공간 자동 확장을 사용합니다. | [최대 처리량·확장 지연·장애 시 용량](#45-관측-부하와-장애-시-처리-용량의-차이)을 판단할 부하 시험이 없습니다. |
| Manage change through automation(자동화로 변경 관리) | 이미지 생성·시작 템플릿·인스턴스 교체를 연결합니다. | [정상 용량 유지와 실패 시 복귀 조건](#41-api-동시-교체로-정상-대상이-없어진-구간)을 배포 흐름에 추가해야 합니다. |

## 3. [Questions and Best Practices(질문 및 모범 사례별 상세 점검)](https://docs.aws.amazon.com/wellarchitected/latest/framework/a-reliability.html)

### 3.1 [REL01. 서비스 할당량과 제약 관리](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel-01.html)

**공식 질문**: How do you manage Service Quotas and constraints?  
**질문 종합 판정: 확인 불가** — EC2 사용량은 수집되지만 서비스별 할당량 관리와 장애 시 용량 여유의 근거가 부족합니다.

| 공식 BP·명칭·원문 | 점검 기준 | 실제 현재 상태 | 확인 근거 | 판정 | 판정 사유 |
|---|---|---|---|---|---|
| [REL01-BP01 Aware of service quotas and constraints](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_manage_service_limits_aware_quotas_and_constraints.html) | 서비스별 할당량·고정 제약을 파악하고 운영 기준으로 관리합니다. | 서울의 표준 On-Demand 한도는 16 vCPU입니다. | [용량 근거](#45-관측-부하와-장애-시-처리-용량의-차이)·[판단 제약](#46-확보한-자료와-판단-제약) | 확인 불가 | 서비스별 할당량·고정 제약의 관리 목록과 운영 절차가 없습니다. |
| [REL01-BP02 Manage service quotas across accounts and regions](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_manage_service_limits_limits_considered.html) | 사용 계정·리전별 할당량을 일관되게 관리합니다. | API·DB·콘텐츠 저장소는 서울에 있습니다. | [용량 근거](#45-관측-부하와-장애-시-처리-용량의-차이)·[판단 제약](#46-확보한-자료와-판단-제약) | 확인 불가 | 사용 위치별 할당량을 일관되게 관리하는 절차와 복구 위치의 용량 자료가 없습니다. |
| [REL01-BP03 Accommodate fixed service quotas and constraints through architecture](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_manage_service_limits_aware_fixed_limits.html) | 변경할 수 없는 서비스 제약을 아키텍처에 반영합니다. | ASG 최대 4대·RDS 저장 상한 100 GiB가 설정되어 있습니다. | [용량 근거](#45-관측-부하와-장애-시-처리-용량의-차이)·[판단 제약](#46-확보한-자료와-판단-제약) | 확인 불가 | API 호출·연결·처리 한도 등 서비스의 고정 제약을 반영한 설계 근거가 없습니다. |
| [REL01-BP04 Monitor and manage quotas](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_manage_service_limits_monitor_manage_limits.html) | 사용량과 할당량의 간격을 관측하고 부족 전에 조치합니다. | EC2 사용량 지표는 수집되지만 CloudWatch에 할당량 경보는 없습니다. | [용량 근거](#45-관측-부하와-장애-시-처리-용량의-차이)·[판단 제약](#46-확보한-자료와-판단-제약) | 부분 충족 | 사용량 수집과 한도 접근 시 경보·조치가 연결되어 있지 않습니다. |
| [REL01-BP05 Automate quota management](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_manage_service_limits_automated_monitor_limits.html) | 할당량 감시·증가 요청 등 관리를 자동화합니다. | ASG는 CPU를 기준으로 자원을 조절합니다. | [용량 근거](#45-관측-부하와-장애-시-처리-용량의-차이)·[판단 제약](#46-확보한-자료와-판단-제약) | 확인 불가 | 할당량 감시·증가 요청의 자동화 여부를 판단할 구성 자료와 실행 기록이 부족합니다. |
| [REL01-BP06 Ensure that a sufficient gap exists between the current quotas and the maximum usage to accommodate failover](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_manage_service_limits_suff_buffer_limits.html) | 장애 자원과 대체 자원이 겹치는 최대 사용량까지 여유를 확보합니다. | 공통 기간의 표준 On-Demand 최대 사용량은 8 vCPU, 현재 한도는 16 vCPU입니다. | [용량 근거](#45-관측-부하와-장애-시-처리-용량의-차이)·[판단 제약](#46-확보한-자료와-판단-제약) | 확인 불가 | 장애 자원·대체 자원·이미지 빌드가 겹치는 시점의 필요 용량과 서비스별 여유가 확인 불가입니다. |

### 3.2 [REL02. 네트워크 토폴로지 계획](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel-02.html)

**공식 질문**: How do you plan your network topology?  
**질문 종합 판정: 확인 불가** — 두 AZ·독립 NAT·서브넷 주소 여유는 있으나 DNS의 운영 상태와 장애 대응은 확인 불가입니다.

| 공식 BP·명칭·원문 | 점검 기준 | 실제 현재 상태 | 확인 근거 | 판정 | 판정 사유 |
|---|---|---|---|---|---|
| [REL02-BP01 Use highly available network connectivity for your workload public endpoints](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_planning_network_topology_ha_conn_users.html) | 공개 엔드포인트에 고가용성 연결을 제공합니다. | ALB는 두 AZ, 콘텐츠는 CloudFront·S3를 사용합니다. | [구성](#11-리소스-구성)·[판단 제약](#46-확보한-자료와-판단-제약) | 확인 불가 | DNS 위임·레코드의 실제 운영 상태와 공개 접속 상실 시 대응 자료가 부족합니다. |
| [REL02-BP02 Provision redundant connectivity between private networks in the cloud and on-premises environments](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_planning_network_topology_ha_conn_private_networks.html) | 클라우드 사설망과 온프레미스·다른 사설망 사이 연결을 이중화합니다. | 단일 VPC에 API와 DB를 배치하며 외부 사설망 연결은 없습니다. | [구성](#11-리소스-구성)·[판단 제약](#46-확보한-자료와-판단-제약) | 해당 없음 | 이중화할 외부 사설망 연결이 없습니다. |
| [REL02-BP03 Ensure IP subnet allocation accounts for expansion and availability](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_planning_network_topology_ip_subnet_allocation.html) | 확장과 가용성을 고려해 서브넷 주소 공간을 배정합니다. | 두 AZ에 역할별 /24 서브넷 6개가 있고 여유 주소는 각각 249~250개입니다. | [구성](#11-리소스-구성)·[판단 제약](#46-확보한-자료와-판단-제약) | 충족 | API 최대 4대의 확장 범위에 주소 여유가 있으며 AZ별로 서브넷이 나뉩니다. |
| [REL02-BP04 Prefer hub-and-spoke topologies over many-to-many mesh](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_planning_network_topology_prefer_hub_and_spoke.html) | 다수의 사설망을 연결할 때 복잡한 전체 상호 연결을 피합니다. | 한 VPC에 역할별 서브넷을 둡니다. | [구성](#11-리소스-구성)·[판단 제약](#46-확보한-자료와-판단-제약) | 해당 없음 | 허브·스포크 구조가 필요한 다중 네트워크 연결이 없습니다. |
| [REL02-BP05 Enforce non-overlapping private IP address ranges in all private address spaces where they are connected](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_planning_network_topology_non_overlap_ip.html) | 연결된 사설 주소 공간이 겹치지 않도록 합니다. | 6개 /24 서브넷의 사설 주소 범위가 서로 겹치지 않습니다. | [구성](#11-리소스-구성)·[판단 제약](#46-확보한-자료와-판단-제약) | 충족 | 연결된 서브넷 사이에 주소 충돌이 없습니다. |

### 3.3 [REL03. 워크로드 서비스 구조 설계](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel-03.html)

**공식 질문**: How do you design your workload service architecture?  
**질문 종합 판정: 확인 불가** — 콘텐츠·API·DB의 역할은 나뉘지만 API 내부 업무 경계와 계약 자료가 없습니다.

| 공식 BP·명칭·원문 | 점검 기준 | 실제 현재 상태 | 확인 근거 | 판정 | 판정 사유 |
|---|---|---|---|---|---|
| [REL03-BP01 Choose how to segment your workload](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_service_architecture_monolith_soa_microservice.html) | 가용성·확장성·복잡도를 고려하여 서비스 경계를 정합니다. | 콘텐츠·API·DB의 역할을 나누고 API를 독립적으로 배포·확장합니다. | [구성](#11-리소스-구성)·[판단 제약](#46-확보한-자료와-판단-제약) | 충족 | 역할에 따라 실행·배포 경계를 나누어 API 변경의 영향을 제한합니다. |
| [REL03-BP02 Build services focused on specific business domains and functionality](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_service_architecture_business_domains.html) | 서비스 책임을 업무 도메인·기능에 맞게 집중시킵니다. | API가 장소 검색·필터 등 서비스 기능을 담당합니다. | [구성](#11-리소스-구성)·[판단 제약](#46-확보한-자료와-판단-제약) | 확인 불가 | API 내부의 업무 경계·공유 상태·책임을 판단할 설계·구현 자료가 없습니다. |
| [REL03-BP03 Provide service contracts per API](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_service_architecture_api_contracts.html) | API의 요청·응답·오류·호환성 계약을 제공합니다. | 이미지 시험은 API와 DB의 상태 확인 경로를 검사합니다. | [구성](#11-리소스-구성)·[판단 제약](#46-확보한-자료와-판단-제약) | 확인 불가 | 업무 API의 요청·응답·오류 명세와 호환성 규칙이 없습니다. |

### 3.4 [REL04. 분산 시스템의 장애 예방](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel-04.html)

**공식 질문**: How do you design interactions in a distributed system to prevent failures?  
**질문 종합 판정: 확인 불가** — 요청 경로는 구성되어 있으나 의존성 제어·멱등성·장애 시 작업량은 확인 불가입니다.

| 공식 BP·명칭·원문 | 점검 기준 | 실제 현재 상태 | 확인 근거 | 판정 | 판정 사유 |
|---|---|---|---|---|---|
| [REL04-BP01 Identify the kind of distributed systems you depend on](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_prevent_interaction_failure_identify.html) | 의존하는 분산 시스템의 동작·일관성·실패 특성을 파악합니다. | ALB→API→RDS와 CloudFront→S3로 요청을 처리합니다. | [구성](#11-리소스-구성)·[판단 제약](#46-확보한-자료와-판단-제약) | 확인 불가 | 외부 호출·동기 및 비동기 처리·데이터 일관성 요구를 설명하는 자료가 없습니다. |
| [REL04-BP02 Implement loosely coupled dependencies](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_prevent_interaction_failure_loosely_coupled_system.html) | 의존 관계를 느슨하게 하여 장애 전파를 줄입니다. | 정적 콘텐츠는 API와 별도 경로로 제공됩니다. | [구성](#11-리소스-구성)·[판단 제약](#46-확보한-자료와-판단-제약) | 확인 불가 | DB·외부 API 장애 시 호출 제한·회로 차단·캐시 등 의존성 제어 방식이 확인 불가입니다. |
| [REL04-BP03 Do constant work](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_prevent_interaction_failure_constant_work.html) | 정상·장애 상태에서 급격한 작업량 변화가 생기지 않게 합니다. | ALB는 고정 간격으로 상태를 검사합니다. | [구성](#11-리소스-구성)·[판단 제약](#46-확보한-자료와-판단-제약) | 확인 불가 | 애플리케이션의 장애 시 재시도·갱신·오류 처리량 자료가 없습니다. |
| [REL04-BP04 Make mutating operations idempotent](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_prevent_interaction_failure_idempotent.html) | 상태를 변경하는 요청을 반복해도 의도한 결과가 유지되도록 합니다. | 정적 콘텐츠는 GET·HEAD로 제공하며 업무 API의 변경 동작은 확인 불가입니다. | [구성](#11-리소스-구성)·[판단 제약](#46-확보한-자료와-판단-제약) | 확인 불가 | 상태 변경 요청을 반복할 때 중복 처리를 막는 구현·시험 자료가 없습니다. |

### 3.5 [REL05. 분산 시스템의 장애 완화](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel-05.html)

**공식 질문**: How do you design interactions in a distributed system to mitigate or withstand failures?  
**질문 종합 판정: 확인 불가** — 클라이언트·DB 연결·재시도·기능 축소의 구현과 시험 자료가 없습니다.

| 공식 BP·명칭·원문 | 점검 기준 | 실제 현재 상태 | 확인 근거 | 판정 | 판정 사유 |
|---|---|---|---|---|---|
| [REL05-BP01 Implement graceful degradation to transform applicable hard dependencies into soft dependencies](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_mitigate_interaction_failure_graceful_degradation.html) | 필수 의존성 장애가 발생해도 가능한 기능을 계속 제공합니다. | 콘텐츠와 API의 실행 경로가 분리되어 있습니다. | [구성](#11-리소스-구성)·[판단 제약](#46-확보한-자료와-판단-제약) | 확인 불가 | API·DB 장애 시 대체 표시·캐시 응답·일부 기능 유지의 구현과 시험 기록이 없습니다. |
| [REL05-BP02 Throttle requests](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_mitigate_interaction_failure_throttle_requests.html) | 요청 속도를 제한하여 처리 능력 초과를 방지합니다. | ALB가 API 인스턴스로 요청을 분산합니다. | [구성](#11-리소스-구성)·[판단 제약](#46-확보한-자료와-판단-제약) | 확인 불가 | 업무 API의 요청 속도 제한 설정이 확인 불가입니다. |
| [REL05-BP03 Control and limit retry calls](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_mitigate_interaction_failure_limit_retries.html) | 재시도 횟수·대기 간격·무작위 지연을 통제합니다. | CloudFront 오리진 연결은 최대 3회 시도합니다. | [구성](#11-리소스-구성)·[판단 제약](#46-확보한-자료와-판단-제약) | 확인 불가 | API·DB 연결의 재시도 횟수·간격·중복 호출 제어가 확인 불가입니다. |
| [REL05-BP04 Fail fast and limit queues](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_mitigate_interaction_failure_fail_fast.html) | 처리 불가능한 요청을 조기에 종료하고 대기열을 제한합니다. | ASG의 자원 상한은 설정되어 있습니다. | [구성](#11-리소스-구성)·[판단 제약](#46-확보한-자료와-판단-제약) | 확인 불가 | API 동시 요청·작업 대기열·DB 연결 대기의 한도와 과부하 처리 방식이 확인 불가입니다. |
| [REL05-BP05 Set client timeouts](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_mitigate_interaction_failure_client_timeouts.html) | 호출별 적절한 클라이언트 시간 제한을 둡니다. | CloudFront 연결 제한은 10초·읽기 제한은 30초, ALB 유휴 제한은 60초입니다. | [구성](#11-리소스-구성)·[판단 제약](#46-확보한-자료와-판단-제약) | 확인 불가 | 브라우저·API의 HTTP 및 DB 클라이언트 시간 제한은 확인 불가입니다. |
| [REL05-BP06 Make systems stateless where possible](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_mitigate_interaction_failure_stateless.html) | 가능한 상태를 외부로 분리하여 인스턴스 교체·확장을 지원합니다. | API 두 대가 RDS를 함께 사용하며 ALB 세션 고정은 꺼져 있습니다. | [구성](#11-리소스-구성)·[판단 제약](#46-확보한-자료와-판단-제약) | 확인 불가 | 인스턴스에 남는 세션·파일·임시 상태와 교체 시 처리 방식이 확인 불가입니다. |
| [REL05-BP07 Implement emergency levers](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_mitigate_interaction_failure_emergency_levers.html) | 비상 시 부하·기능을 안전하게 제한할 수단을 준비합니다. | ASG 용량과 배포 설정으로 실행 환경을 제어합니다. | [구성](#11-리소스-구성)·[판단 제약](#46-확보한-자료와-판단-제약) | 확인 불가 | 기능 중지·쓰기 차단·트래픽 제한 등 비상 조작 수단과 실행 절차가 확인 불가입니다. |

### 3.6 [REL06. 워크로드 리소스 모니터링](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel-06.html)

**공식 질문**: How do you monitor workload resources?  
**질문 종합 판정: 부분 충족** — 인프라 감시와 자원 대응은 있으나 운영자 알림·배포 롤백이 없습니다. 업무 계측의 충족 여부는 확인 불가입니다.

| 공식 BP·명칭·원문 | 점검 기준 | 실제 현재 상태 | 확인 근거 | 판정 | 판정 사유 |
|---|---|---|---|---|---|
| [REL06-BP01 Monitor all components for the workload (Generation)](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_monitor_aws_resources_monitor_resources.html) | 모든 구성 요소의 상태와 사용자 관점 동작을 관측합니다. | 인프라 지표·ALB·CloudFront 로그와 시스템 그룹의 API 기록이 있습니다. | [관측 설정](#12-옵저빌리티-구성)·[로그 범위](#44-로그-수집-경로와-업무-관측의-공백) | 확인 불가 | 업무 성공·예외·DB 의존성의 계측 범위를 판단할 로그 스키마와 외부 관측 자료가 부족합니다. |
| [REL06-BP02 Define and calculate metrics (Aggregation)](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_monitor_aws_resources_notification_aggregation.html) | 운영 지표를 정의하고 집계하여 판단에 사용합니다. | 인프라 경보에 자원·오류의 통계와 임계값이 정의되어 있습니다. | [관측 설정](#12-옵저빌리티-구성)·[로그 범위](#44-로그-수집-경로와-업무-관측의-공백) | 확인 불가 | 업무 지표의 정의·집계·목표 자료가 없어 전체 관측 지표의 적합성은 확인 불가입니다. |
| [REL06-BP03 Send notifications (Real-time processing and alarming)](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_monitor_aws_resources_notification_monitor.html) | 중요한 상태 변화가 담당자나 대응 시스템에 도달하도록 통지합니다. | 서비스 경보 9개는 생성 당시부터 동작이 비활성화되어 있고 알림 대상이 없습니다. | [관측 설정](#12-옵저빌리티-구성)·[오류·통지](#42-api-초기-연결-오류와-운영자-통지-공백)·[교체 기록](#41-api-동시-교체로-정상-대상이-없어진-구간) | 미충족 | 정상 대상 부족·5xx 경보가 발생해도 운영자에게 전달되지 않습니다. |
| [REL06-BP04 Automate responses (Real-time processing and alarming)](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_monitor_aws_resources_automate_response_monitor.html) | 관측 결과로 복구·용량 조절을 자동 실행합니다. | CPU 기반 용량 조절과 비정상 인스턴스 교체는 자동화되어 있습니다. | [관측 설정](#12-옵저빌리티-구성)·[오류·통지](#42-api-초기-연결-오류와-운영자-통지-공백)·[교체 기록](#41-api-동시-교체로-정상-대상이-없어진-구간) | 부분 충족 | 배포 중 정상 대상 부족에 따른 중단·자동 롤백이 연결되어 있지 않습니다. |
| [REL06-BP05 Analyze logs](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_monitor_aws_resources_storage_analytics.html) | 로그를 분석하여 장애 원인과 운영 상태를 이해합니다. | ALB·CloudFront·시스템·DB 로그를 저장합니다. | [관측 설정](#12-옵저빌리티-구성)·[로그 범위](#44-로그-수집-경로와-업무-관측의-공백) | 확인 불가 | 정기 분석·이상 감지·대응 절차의 운영 기록이 없습니다. |
| [REL06-BP06 Regularly review monitoring scope and metrics](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_monitor_aws_resources_review_monitoring.html) | 관측 대상·지표의 적합성을 주기적으로 검토합니다. | 자원·오류 경보와 로그 수집 구성이 있습니다. | [관측 설정](#12-옵저빌리티-구성)·[로그 범위](#44-로그-수집-경로와-업무-관측의-공백) | 확인 불가 | 관측 범위·지표의 정기 검토 주기와 변경 근거가 없습니다. |
| [REL06-BP07 Monitor end-to-end tracing of requests through your system](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_monitor_aws_resources_end_to_end.html) | 요청 전체 경로의 추적 정보로 의존성·지연·실패를 파악합니다. | 공통 기간 서울 X-Ray 서비스 그래프는 없습니다. | [관측 설정](#12-옵저빌리티-구성)·[로그 범위](#44-로그-수집-경로와-업무-관측의-공백) | 확인 불가 | 요청 전체 경로를 연결하는 애플리케이션 계측과 외부 추적의 사용 여부가 확인 불가입니다. |

### 3.7 [REL07. 수요 변화에 대한 대응](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel-07.html)

**공식 질문**: How do you design your workload to adapt to changes in demand?  
**질문 종합 판정: 확인 불가** — 자원 확장은 자동화되어 있으나 처리 한계와 확장 지연의 시험 자료가 없습니다.

| 공식 BP·명칭·원문 | 점검 기준 | 실제 현재 상태 | 확인 근거 | 판정 | 판정 사유 |
|---|---|---|---|---|---|
| [REL07-BP01 Use automation when obtaining or scaling resources](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_adapt_to_changes_autoscale_adapt.html) | 자원 확보와 확장을 자동화합니다. | API CPU 목표 추적과 RDS 저장 공간 자동 확장을 사용합니다. | [구성](#11-리소스-구성)·[용량 근거](#45-관측-부하와-장애-시-처리-용량의-차이) | 충족 | 지표에 따라 필요한 자원을 추가하는 정책이 운영 리소스에 연결되어 있습니다. |
| [REL07-BP02 Obtain resources upon detection of impairment to a workload](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_adapt_to_changes_reactive_adapt_auto.html) | 성능 저하·장애를 감지하여 대체 자원을 확보합니다. | ASG가 ALB 상태에 따라 인스턴스를 교체하며 초기 유예는 300초입니다. | [구성](#11-리소스-구성)·[용량 근거](#45-관측-부하와-장애-시-처리-용량의-차이) | 충족 | 비정상 인스턴스를 대체하는 자동 복구 경로가 구성되어 있습니다. |
| [REL07-BP03 Obtain resources upon detection that more resources are needed for a workload](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_adapt_to_changes_proactive_adapt_auto.html) | 수요 증가를 감지하여 필요한 자원을 추가합니다. | ASG는 평균 CPU 50%를 목표로 최대 4대까지 확장합니다. | [구성](#11-리소스-구성)·[용량 근거](#45-관측-부하와-장애-시-처리-용량의-차이) | 충족 | 수요 증가를 감지하는 지표와 자원 추가 동작이 연결되어 있습니다. |
| [REL07-BP04 Load test your workload](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_adapt_to_changes_load_tested_adapt.html) | 예상 부하·한계 부하·확장 동작을 시험합니다. | 공통 기간의 CPU·요청 지표가 있습니다. | [구성](#11-리소스-구성)·[용량 근거](#45-관측-부하와-장애-시-처리-용량의-차이) | 확인 불가 | 대표 업무 부하·동시 사용자·확장 지연·DB 한계의 시험 결과가 없습니다. |

### 3.8 [REL08. 변경 구현](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel-08.html)

**공식 질문**: How do you implement change?  
**질문 종합 판정: 부분 충족** — 이미지 기반 자동 배포와 기동 시험이 있지만 정상 대상 유지와 자동 롤백이 부족합니다.

| 공식 BP·명칭·원문 | 점검 기준 | 실제 현재 상태 | 확인 근거 | 판정 | 판정 사유 |
|---|---|---|---|---|---|
| [REL08-BP01 Use runbooks for standard activities such as deployment](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_tracking_change_management_planned_changemgmt.html) | 배포 등 반복 작업에 재현 가능한 런북을 사용합니다. | README에 이미지 반영·인스턴스 교체·서비스 확인 순서가 있습니다. | [운영 기준](../../README.md#4-operational-criteria-and-constraints운영-기준-및-제약)·[판단 제약](#46-확보한-자료와-판단-제약) | 확인 불가 | 실행 단계·실패 분기·롤백을 포함한 작업 절차와 사용 기록이 없습니다. |
| [REL08-BP02 Integrate functional testing as part of your deployment](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_tracking_change_management_functional_testing.html) | 배포 흐름에 기능 시험을 포함합니다. | 이미지 시험은 자동 기동·`/health`·`/health/db`를 검사하며 실패 시 중단합니다. 애플리케이션 기능 시험의 배포 연계는 미확인입니다. | [이미지 시험](../../terraform/modules/image-builder/fastapi.tf#L95)·[교체 기록](#41-api-동시-교체로-정상-대상이-없어진-구간) | 확인 불가 | 검색·필터 등 업무 기능 시험의 범위와 배포 연계 자료가 부족합니다. |
| [REL08-BP03 Integrate resiliency testing as part of your deployment](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_tracking_change_management_resiliency_testing.html) | 배포 검증에 장애 내성 시험을 포함합니다. | 이미지 시험은 정상 기동과 연결을 점검합니다. | [교체 기록](#41-api-동시-교체로-정상-대상이-없어진-구간)·[백업·복구](#43-rds-자동-백업의-복원-범위와-미검증된-복구-목표) | 확인 불가 | 배포 전후 장애 주입·AZ 전환·DB 단절 시험의 실행 기록이 없습니다. |
| [REL08-BP04 Deploy using immutable infrastructure](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_tracking_change_management_immutable_infrastructure.html) | 새 이미지로 인프라를 교체하고 새 환경 검증 후 단계적으로 전환합니다. | 동일 AMI·템플릿 버전으로 교체하면서 기존 API 두 대를 동시에 제외했습니다. | [교체 기록](#41-api-동시-교체로-정상-대상이-없어진-구간)·[백업·복구](#43-rds-자동-백업의-복원-범위와-미검증된-복구-목표) | 부분 충족 | 새 환경이 준비될 때까지 기존 정상 환경을 유지하는 단계적 전환이 부족했습니다. |
| [REL08-BP05 Deploy changes with automation](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_tracking_change_management_automated_changemgmt.html) | 배포 자동화에 안전한 단계 전환·검사·롤백을 결합합니다. | 이미지 생성·인스턴스 교체는 자동화되어 있으나 최소 정상 비율은 0%이며 자동 롤백은 꺼져 있습니다. | [교체 기록](#41-api-동시-교체로-정상-대상이-없어진-구간)·[백업·복구](#43-rds-자동-백업의-복원-범위와-미검증된-복구-목표) | 부분 충족 | 배포 중 처리 용량을 유지하거나 실패 시 되돌리는 보호가 없습니다. |

### 3.9 [REL09. 데이터 백업](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel-09.html)

**공식 질문**: How do you back up data?  
**질문 종합 판정: 확인 불가** — DB 자동 백업은 동작하지만 전체 데이터의 보호 범위와 복원 성공 기록이 부족합니다.

| 공식 BP·명칭·원문 | 점검 기준 | 실제 현재 상태 | 확인 근거 | 판정 | 판정 사유 |
|---|---|---|---|---|---|
| [REL09-BP01 Identify and back up all data that needs to be backed up, or reproduce the data from sources](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_backing_up_data_identified_backups_data.html) | 복구가 필요한 모든 데이터·구성의 백업 또는 재생성 경로를 정합니다. | RDS 자동 백업과 사진 버전 관리가 있으며 웹·지도·배포 버킷은 버전 관리가 없습니다. | [백업·복구](#43-rds-자동-백업의-복원-범위와-미검증된-복구-목표) | 확인 불가 | 전체 백업 대상과 콘텐츠 원본·재생성 절차가 없어 데이터 보호 범위는 확인 불가입니다. |
| [REL09-BP02 Secure and encrypt backups](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_backing_up_data_secured_backups_data.html) | 백업을 암호화하고 접근·변조·삭제로부터 보호합니다. | RDS 자동 스냅샷은 암호화되어 있으며 S3 기본 암호화도 사용합니다. | [백업·복구](#43-rds-자동-백업의-복원-범위와-미검증된-복구-목표) | 확인 불가 | 백업 접근 권한·삭제 통제·변조 탐지의 자료가 부족합니다. |
| [REL09-BP03 Perform data backup automatically](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_backing_up_data_automated_backups_data.html) | 필요한 백업을 수동 작업에 의존하지 않고 생성합니다. | RDS 자동 백업은 3일 보존하며 공통 기간에 시작 9회·완료 8회가 기록되었습니다. | [백업·복구](#43-rds-자동-백업의-복원-범위와-미검증된-복구-목표) | 충족 | DB 백업이 자동 생성되고 암호화된 스냅샷과 시점 복원 구간이 유지됩니다. |
| [REL09-BP04 Perform periodic recovery of the data to verify backup integrity and processes](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_backing_up_data_periodic_recovery_testing_data.html) | 백업을 주기적으로 복원해 데이터와 복구 시간·손실을 검증합니다. | 시점 복원 구간과 자동 스냅샷이 있습니다. | [백업·복구](#43-rds-자동-백업의-복원-범위와-미검증된-복구-목표) | 확인 불가 | 정기 복원의 데이터 정합성·소요 시간·손실 범위 기록이 없습니다. |

### 3.10 [REL10. 장애 격리](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel-10.html)

**공식 질문**: How do you use fault isolation to protect your workload?  
**질문 종합 판정: 부분 충족** — 두 AZ와 콘텐츠·API의 경계가 있으나 배포 중 API 전체가 함께 영향을 받았습니다.

| 공식 BP·명칭·원문 | 점검 기준 | 실제 현재 상태 | 확인 근거 | 판정 | 판정 사유 |
|---|---|---|---|---|---|
| [REL10-BP01 Deploy the workload to multiple locations](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_fault_isolation_multiaz_region_system.html) | 여러 장애 격리 위치에 워크로드를 배치합니다. | ALB·API·NAT·RDS를 두 AZ에 배치하고 콘텐츠에 S3·CloudFront를 사용합니다. | [구성](#11-리소스-구성)·[교체 기록](#41-api-동시-교체로-정상-대상이-없어진-구간) | 충족 | 단일 AZ 장애에 대비해 실행 위치를 분산합니다. |
| [REL10-BP02 Automate recovery for components constrained to a single location](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_fault_isolation_single_az_system.html) | 기술적 제약으로 단일 AZ·위치에서만 실행할 수 있는 구성 요소의 재구축을 자동화합니다. | API는 두 AZ에 복제되며 RDS는 Multi-AZ, 콘텐츠는 S3·CloudFront를 사용합니다. | [구성](#11-리소스-구성)·[교체 기록](#41-api-동시-교체로-정상-대상이-없어진-구간) | 해당 없음 | 기술적 제약으로 한 위치에서만 실행해야 하는 구성 요소가 없습니다. |
| [REL10-BP03 Use bulkhead architectures to limit scope of impact](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_fault_isolation_use_bulkhead.html) | 장애 영향이 전체 워크로드로 확산되지 않도록 경계를 둡니다. | 콘텐츠와 API는 분리되어 있으나 배포가 API 두 대를 함께 교체했습니다. | [구성](#11-리소스-구성)·[교체 기록](#41-api-동시-교체로-정상-대상이-없어진-구간) | 부분 충족 | API 배포의 영향이 전체 정상 대상에 미쳤습니다. |

### 3.11 [REL11. 구성 요소 장애 대응](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel-11.html)

**공식 질문**: How do you design your workload to withstand component failures?  
**질문 종합 판정: 부분 충족** — 자원 복구는 자동화되어 있으나 알림과 배포 중 정상 자원 유지가 부족합니다. 업무 장애 감지와 목표 달성은 확인 불가입니다.

| 공식 BP·명칭·원문 | 점검 기준 | 실제 현재 상태 | 확인 근거 | 판정 | 판정 사유 |
|---|---|---|---|---|---|
| [REL11-BP01 Monitor all components of the workload to detect failures](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_withstand_component_failures_monitoring_health.html) | 구성 요소별 장애와 사용자 기능 실패를 감지합니다. | EC2·ALB·RDS 경보와 API 기록이 있으며 ALB는 `/health`를 검사합니다. | [관측 설정](#12-옵저빌리티-구성)·[로그·업무 관측](#44-로그-수집-경로와-업무-관측의-공백) | 확인 불가 | 업무 기능과 DB 의존성의 지속적인 실패 감지를 판단할 계측 자료가 부족합니다. |
| [REL11-BP02 Fail over to healthy resources](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_withstand_component_failures_failover2good.html) | 장애 시 정상 자원으로 트래픽을 전환합니다. | ALB와 RDS Multi-AZ가 정상 자원으로 전환하지만 배포 중 ALB 정상 대상이 0대가 되었습니다. | [관측 설정](#12-옵저빌리티-구성)·[교체 기록](#41-api-동시-교체로-정상-대상이-없어진-구간)·[오류·통지](#42-api-초기-연결-오류와-운영자-통지-공백) | 부분 충족 | 교체 구간에는 요청을 넘길 정상 대상이 유지되지 않았습니다. |
| [REL11-BP03 Automate healing on all layers](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_withstand_component_failures_auto_healing_system.html) | 모든 계층의 회복 경로를 자동화합니다. | API 인스턴스 교체와 DB 장애 조치는 자동화되어 있습니다. | [관측 설정](#12-옵저빌리티-구성)·[교체 기록](#41-api-동시-교체로-정상-대상이-없어진-구간)·[오류·통지](#42-api-초기-연결-오류와-운영자-통지-공백) | 부분 충족 | 배포 중 가용성 저하를 되돌리는 자동 롤백이 없습니다. |
| [REL11-BP04 Rely on the data plane and not the control plane during recovery](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_withstand_component_failures_avoid_control_plane.html) | 장애 복구 시 제어 영역의 새 설정·자원 생성 의존을 줄입니다. | 기존 ALB 대상과 RDS 대기를 유지하며 ASG의 대체 인스턴스는 새로 생성합니다. | [구성](#11-리소스-구성)·[용량 근거](#45-관측-부하와-장애-시-처리-용량의-차이) | 확인 불가 | 자원 생성·설정 변경이 불가능할 때 기존 자원만으로 운영하는 시험 기록이 없습니다. |
| [REL11-BP05 Use static stability to prevent bimodal behavior](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_withstand_component_failures_static_stability.html) | 장애 후 새 자원 확보 없이도 감당할 수 있는 정적 안정성을 확보합니다. | AZ마다 API 한 대가 있으며 RDS 대기가 별도 AZ에 있습니다. | [구성](#11-리소스-구성)·[용량 근거](#45-관측-부하와-장애-시-처리-용량의-차이) | 확인 불가 | 한 AZ만 남았을 때의 최대 업무 부하·DB 병목·외부 의존성 시험 자료가 없습니다. |
| [REL11-BP06 Send notifications when events impact availability](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_withstand_component_failures_notifications_sent_system.html) | 가용성에 영향을 주는 사건을 운영자에게 알립니다. | 정상 대상·5xx 경보에 알림 동작이 없으며 RDS 이벤트 구독도 없습니다. | [관측 설정](#12-옵저빌리티-구성)·[교체 기록](#41-api-동시-교체로-정상-대상이-없어진-구간)·[오류·통지](#42-api-초기-연결-오류와-운영자-통지-공백) | 미충족 | 가용성에 영향을 주는 경보가 운영자 대응으로 연결되지 않습니다. |
| [REL11-BP07 Architect your product to meet availability targets and uptime service level agreements (SLAs)](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_withstand_component_failures_service_level_agreements.html) | 가용성 목표·SLA에 맞춰 구조와 운영 기준을 검증합니다. | 두 AZ 구성과 자원 경보를 사용합니다. | [판단 제약](#46-확보한-자료와-판단-제약) | 확인 불가 | 가용성 목표·서비스 수준 협약(SLA)과 측정 기준이 없어 목표 달성 여부는 확인 불가입니다. |

### 3.12 [REL12. 신뢰성 시험](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel-12.html)

**공식 질문**: How do you test reliability?  
**질문 종합 판정: 확인 불가** — 부하·장애 주입·복원 훈련과 사후 분석의 실행 기록이 없습니다.

| 공식 BP·명칭·원문 | 점검 기준 | 실제 현재 상태 | 확인 근거 | 판정 | 판정 사유 |
|---|---|---|---|---|---|
| [REL12-BP01 Use playbooks to investigate failures](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_testing_resiliency_playbook_resiliency.html) | 장애 조사 절차와 판단 분기를 플레이북으로 운영합니다. | 서비스별 로그와 이벤트 이력이 있습니다. | [판단 제약](#46-확보한-자료와-판단-제약) | 확인 불가 | 장애 원인별 조사 순서·판단 분기·조치가 담긴 대응 절차와 사용 기록이 없습니다. |
| [REL12-BP02 Perform post-incident analysis](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_testing_resiliency_rca_resiliency.html) | 사고 후 원인·대응·재발 방지를 검토합니다. | 초기 연결 오류·ASG 시작 실패·배포 중 정상 대상 감소가 기록되었습니다. | [교체 기록](#41-api-동시-교체로-정상-대상이-없어진-구간)·[오류·통지](#42-api-초기-연결-오류와-운영자-통지-공백)·[판단 제약](#46-확보한-자료와-판단-제약) | 확인 불가 | 사건의 원인·대응·재발 방지를 검토하고 공유한 기록이 없습니다. |
| [REL12-BP03 Test scalability and performance requirements](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_testing_resiliency_test_non_functional.html) | 확장성과 성능 요구를 시험으로 검증합니다. | CPU·요청·자원 지표와 확장 상한이 있습니다. | [판단 제약](#46-확보한-자료와-판단-제약) | 확인 불가 | 최대 부하·응답 시간·처리량의 합격 기준과 시험 기록이 없습니다. |
| [REL12-BP04 Test resiliency using chaos engineering](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_testing_resiliency_failure_injection_resiliency.html) | 통제된 장애 주입으로 복구 가정을 시험합니다. | 운영 이력에 초기 기동 오류와 배포 중 정상 대상 감소가 있습니다. | [판단 제약](#46-확보한-자료와-판단-제약) | 확인 불가 | 계획된 장애 주입의 시나리오·실행·복구 결과가 없습니다. |
| [REL12-BP05 Conduct game days regularly](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_testing_resiliency_game_days_resiliency.html) | 정기적인 합동 장애 대응 훈련을 실시합니다. | 정기 장애 대응 훈련의 실적은 확인 불가입니다. | [판단 제약](#46-확보한-자료와-판단-제약) | 확인 불가 | 훈련 일정·담당자 참여·복구 평가 기록이 없습니다. |

### 3.13 [REL13. 재해 복구 계획](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel-13.html)

**공식 질문**: How do you plan for disaster recovery (DR)?  
**질문 종합 판정: 확인 불가** — 복구 목표·전략·대상 환경·시험 자료가 없어 리전 재해 대응 수준을 판단할 수 없습니다.

| 공식 BP·명칭·원문 | 점검 기준 | 실제 현재 상태 | 확인 근거 | 판정 | 판정 사유 |
|---|---|---|---|---|---|
| [REL13-BP01 Define recovery objectives for downtime and data loss](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_planning_for_recovery_objective_defined_recovery.html) | 허용 가능한 중단 시간(RTO)과 데이터 손실(RPO)을 정합니다. | RDS 자동 백업을 3일 보존합니다. | [백업·복구](#43-rds-자동-백업의-복원-범위와-미검증된-복구-목표)·[판단 제약](#46-확보한-자료와-판단-제약) | 확인 불가 | 허용 복구 시간(RTO)·허용 데이터 손실(RPO)의 합의 자료가 없습니다. |
| [REL13-BP02 Use defined recovery strategies to meet the recovery objectives](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_planning_for_recovery_disaster_recovery.html) | 복구 목표에 맞는 재해 복구 전략을 선택·구현합니다. | Multi-AZ와 자동 백업으로 AZ 장애와 데이터 손상에 대비합니다. | [백업·복구](#43-rds-자동-백업의-복원-범위와-미검증된-복구-목표)·[판단 제약](#46-확보한-자료와-판단-제약) | 확인 불가 | 리전 재해의 복구 목표·전략 자료가 없어 현재 보호 방식의 적합성은 확인 불가입니다. |
| [REL13-BP03 Test disaster recovery implementation to validate the implementation](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_planning_for_recovery_dr_tested.html) | 재해 복구를 실행하여 목표 달성을 검증합니다. | 재해 복구의 실행 결과는 확인 불가입니다. | [백업·복구](#43-rds-자동-백업의-복원-범위와-미검증된-복구-목표)·[판단 제약](#46-확보한-자료와-판단-제약) | 확인 불가 | 대체 환경 기동·DNS 전환·복원 데이터와 소요 시간의 검증 기록이 없습니다. |
| [REL13-BP04 Manage configuration drift at the DR site or Region](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_planning_for_recovery_config_drift.html) | DR 위치의 인프라·데이터·설정 차이를 관리합니다. | 재해 복구 대상 환경과 구성 관리 방식은 확인 불가입니다. | [백업·복구](#43-rds-자동-백업의-복원-범위와-미검증된-복구-목표)·[판단 제약](#46-확보한-자료와-판단-제약) | 확인 불가 | 복구 환경의 설정·이미지·데이터 차이를 관리하는 기준과 운영 기록이 없습니다. |
| [REL13-BP05 Automate recovery](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_planning_for_recovery_auto_recovery.html) | 재해 발생 시 복구 절차를 자동 실행할 수 있게 합니다. | AZ 단위 자동 대응과 Terraform 정의가 있습니다. | [백업·복구](#43-rds-자동-백업의-복원-범위와-미검증된-복구-목표)·[판단 제약](#46-확보한-자료와-판단-제약) | 확인 불가 | 데이터 복원·인증정보 공급·DNS 전환·업무 검증을 연결한 복구 자동화는 확인 불가입니다. |

## 4. Findings and Insights(발견 사항 및 인사이트)

### 4.1 API 동시 교체로 정상 대상이 없어진 구간

**09-15 배포에서는 기존 API 두 대를 함께 제외하면서 정상 처리 용량이 사라졌습니다.** 서울 ASG `arcamap-api`의 교체·활동 이력과 ALB 정상 대상 수, `/aws/vendedlogs/elb/arcamap-api`의 헬스 체크 로그에 남은 사건입니다. 인스턴스 교체는 01:33:47~01:39:33에 진행되었으며 최소 정상 비율은 0%, 최대 비율은 100%였습니다. 자동 롤백과 경보 연결은 없었습니다.

| 09-15 시각 | 사건 |
|---|---|
| 01:32 | ALB 정상 대상 수의 1분 최솟값은 2대였습니다. |
| 01:33:46 | ASG가 인스턴스 교체를 위해 기존 두 대를 서비스에서 제외했습니다. |
| 01:33:48 | 새 인스턴스 두 대가 각각 2a·2c에서 기동했습니다. |
| 01:34·01:35 | ALB 정상 대상 수의 1분 최솟값은 0대, 비정상 대상 수의 최댓값은 2대였습니다. |
| 01:36 | 정상 대상 수의 1분 최솟값이 2대로 돌아왔습니다. |
| 01:38:43 | `arcamap-alb-healthy-hosts`가 ALARM으로 전환되었습니다. |
| 01:39:33·01:40:43 | 인스턴스 교체가 완료되었고 이후 경보가 OK로 돌아왔습니다. |

같은 날 01:00~02:00의 헬스 체크에는 연결 재설정 4건과 시간 초과 4건이 있었습니다. 마지막 실패는 각각 01:34:26과 01:33:56으로 새 대상의 준비 시간과 겹칩니다. 기존 두 대를 먼저 제외하는 [교체 정책](../../terraform/modules/compute/main.tf#L44)이 정상 용량 공백의 직접 원인입니다. API 내부의 어떤 초기화 단계에서 시간이 걸렸는지는 확인 불가입니다.

**새 대상이 준비될 때까지 기존 정상 용량을 유지하는 배포 순서**가 필요합니다. 준비 완료 검사와 단계별 진행 조건, 오류 발생 시 중단·롤백을 연결하면 배포 영향을 일부 인스턴스로 제한할 수 있습니다. 추가 인스턴스에 필요한 할당량·비용·DB 연결 여유를 확보하고 교체 중에도 기존 요청이 처리되는 조건을 유지해야 합니다.

> **사용자 영향 제약**: 01:33에는 대상 수 지표가 없고 실제 이용자 요청의 실패 기록도 부족해 연속 중단 시간과 업무 손실을 확정할 수 없습니다.

관련 기준은 [REL08-BP04·BP05](#38-rel08-변경-구현), [REL10-BP03](#310-rel10-장애-격리), [REL11-BP02·BP03](#311-rel11-구성-요소-장애-대응)입니다. [운영 우수성의 공통 배포 기록](01-operational-excellence.md#41-api-배포의-정상-처리-용량-공백)도 같은 사건을 다룹니다.

### 4.2 API 초기 연결 오류와 운영자 통지 공백

**09-14에는 ALB가 5xx 오류 307건을 반환했고 정상 대상이 없는 상태가 반복되었습니다.** 서울 ALB `arcamap-api`의 접근·헬스 체크 로그와 CloudWatch 지표, ASG 활동·경보 이력에 남은 초기 기동 사건입니다. 오류는 502 응답 303건과 503 응답 4건이며 모두 ALB가 생성했습니다.

| 09-14 시각 | 사건 |
|---|---|
| 01:27:45~01:48:35 | ASG 생성 전에 ALB 503 응답 4건이 발생했습니다. |
| 01:51:22·01:52:21 | ASG 시작 활동 3건이 실패했습니다. 서비스 연결 역할 사용 거부와 로드 밸런서 구성 검증 실패가 기록되었습니다. |
| 01:52:22·01:54:20 | 후속 인스턴스 시작 활동 두 건은 성공했습니다. |
| 01:52~22:41 | 정상 대상 수의 1분 최솟값이 1,250개 구간에서 연속 0대였습니다. |
| 01:55:39~22:35:19 | ALB 502 응답 303건이 발생했습니다. |
| 18:07:07·18:08:43 | API 관련 서비스 경보가 생성되었고 정상 대상 경보가 ALARM으로 전환되었습니다. |
| 19:59:28·21:25:28 | ALB 5xx 경보가 ALARM으로 전환되었습니다. |
| 22:40:20·22:42 | 최초 헬스 체크 성공 후 정상 대상 수의 1분 최솟값이 2대가 되었습니다. |
| 22:46:43 | 정상 대상 경보가 OK로 돌아왔습니다. |

헬스 체크의 주된 실패 사유는 연결 재설정이었습니다. 자원 기동 후에도 API 연결이 정상화되지 않았지만 애플리케이션 내부 원인은 확인 불가입니다. 시작 시점의 역할 오류만으로 이후의 긴 비정상 구간을 설명할 근거는 없습니다.

**서비스 경보에는 당시에도 알림 동작이 없었습니다.** [경보 생성·변경 이력](01-operational-excellence.md#42-서비스-경보의-감지와-전달)에서 DB 경보 3개는 09-14 00:56:48, API 관련 경보 6개는 18:07:07에 동작이 비활성화된 상태로 생성되었고 Alarm·OK·InsufficientData의 동작 목록도 비어 있었습니다. 공통 기간에 후속 구성 변경은 없었습니다. 정상 대상 부족과 5xx 경보가 발생해도 운영자에게 전달되지 않아 수동 대응이 필요한 장애의 인지·복구가 늦어질 수 있습니다.

정상 대상·오류 경보에 수신 담당자와 대응 절차를 연결하고 실제 알림 전달을 시험해야 합니다. API 기동·DB 연결·요청 처리 상태를 배포 완료 조건에 포함하면 인스턴스 생성 성공 후에도 남는 서비스 장애를 발견할 수 있습니다. 알림은 조치 가능한 조건을 중심으로 구성해 중복 통보를 줄여야 합니다.

> **대응 기록 제약**: 운영자가 다른 수단으로 사건을 인지했는지, 어떤 수동 조치를 했는지 기록이 없어 인지 시간과 복구 소요 시간을 산정할 수 없습니다.

관련 기준은 [REL06-BP03·BP04](#36-rel06-워크로드-리소스-모니터링), [REL11-BP06](#311-rel11-구성-요소-장애-대응), [REL12-BP02](#312-rel12-신뢰성-시험)입니다.

### 4.3 RDS 자동 백업의 복원 범위와 미검증된 복구 목표

**RDS 자동 백업은 동작하지만 복원 후 업무를 재개하는 시간과 데이터 정합성은 확인 불가입니다.** 서울 `arcamap-postgres`의 백업·스냅샷·이벤트 이력에서 공통 기간에 백업 시작 9회·완료 8회가 기록되었습니다. 마지막 시작은 09-21 23:55였고 완료는 집계 기간 밖입니다. Multi-AZ 전환은 09-14 00:46~00:54에 진행되었습니다.

| 복구 수단 | 구성 확인 시점의 상태 |
|---|---|
| RDS 자동 스냅샷 | 09-18~21 매일 23:55경 생성된 4개가 사용 가능하며 암호화되어 있습니다. |
| RDS 시점 복원 | 09-19 15:41:35~09-22 15:41:35로 복원할 수 있습니다. |
| 사진 이전 버전 | 버전 관리가 활성화되어 있으며 이전 버전을 7일간 보존합니다. |
| 웹·지도·API 배포 파일 | 버전 관리가 없으며 원본·재생성 절차는 확인 불가입니다. |

[Image Builder 시험](../../terraform/modules/image-builder/fastapi.tf#L95)은 자동 기동과 `/health·/health/db`의 정상 응답을 검사하고 실패 시 중단합니다. 백업 복원·DB 장애 조치·업무 데이터 정합성을 시험하지는 않습니다. 데이터 복구의 기준인 **허용 복구 시간(RTO)**과 **허용 데이터 손실(RPO)**을 정하고 선택한 백업으로 API·DB 기능을 복원하는 시험이 필요합니다.

복원 시험은 운영 데이터와 분리된 환경에서 수행해 데이터·API 연결·소요 시간을 확인해야 합니다. 콘텐츠는 원본 재생성 또는 이전 버전 복원 경로를 마련해야 합니다. 복제 위치와 보존 기간은 복구 목표에 맞춰 정하면 데이터 손실 위험과 보관 비용을 함께 관리할 수 있습니다.

> **복구 목표 제약**: 합의된 RTO·RPO와 복원·장애 조치 시험 결과가 없어 백업 보존 기간과 복구 방식이 업무 요구에 적합한지 판단할 수 없습니다.

관련 기준은 [REL08-BP02](#38-rel08-변경-구현), [REL09](#39-rel09-데이터-백업), [REL13](#313-rel13-재해-복구-계획)입니다.

### 4.4 로그 수집 경로와 업무 관측의 공백

**ALB·CloudFront 접근 로그와 시스템 그룹의 API 기록은 있지만 업무 기능의 성공 여부를 연결할 자료는 부족합니다.** 공통 기간의 서울 CloudWatch Logs와 CloudFront 로그용 S3에는 아래 기록이 남아 있습니다.

| 기록·위치 | 공통 기간의 주요 결과 |
|---|---|
| ALB 접근 로그: `/aws/vendedlogs/elb/arcamap-api` | 10,868건이며 기록 범위는 09-14 01:17~09-21 23:56입니다. 502·503 외에는 404 응답이 6,870건으로 가장 많았습니다. |
| ALB 연결·헬스 체크 로그: 같은 그룹 | 연결 기록은 09-14 01:11, 상태 검사 기록은 01:52부터 있습니다. 초기 연결 실패와 배포 중 정상 대상 공백이 기록되었습니다. |
| API 기록: `/arcamap/ec2/system` | [시스템 로그의 API 기록](01-operational-excellence.md#43-시스템-로그와-api-기록-수집)은 기존·현재 API 인스턴스에 남아 있습니다. |
| CloudFront 접근 로그: [S3 로그 버킷](../../terraform/env/web/main.tf#L14) | [접근 로그 14,181건](04-performance-efficiency.md#45-cloudfront-캐시-결과와-콘텐츠별-응답-성능)이 있으며 실제 기록 범위는 09-14 01:07~09-21 23:57입니다. HTTP 5xx는 없고 403 응답은 6,084건입니다. |
| X-Ray 서비스 그래프 | 공통 기간의 서울 서비스 그래프 기록은 없습니다. 외부 추적 사용 여부는 확인 불가입니다. |

[CloudWatch Agent](../../terraform/env/was/main.tf#L44)는 journald의 API 출력을 시스템 로그 그룹으로 전달합니다. 전용 그룹 `/arcamap/api/application`에는 스트림이 없지만 API 기록은 기존 수집 경로에 남아 있습니다.

ALB 404와 CloudFront 403은 탐색성 요청·잘못된 경로·권한 문제 등을 구분할 업무 문맥이 부족합니다. 요청 식별자·예외·DB 호출 정보가 연결되는지에 따라 원인 분석과 업무 성공률 측정의 범위가 달라집니다. [REL06-BP01·BP02](#36-rel06-워크로드-리소스-모니터링), [REL11-BP01](#311-rel11-구성-요소-장애-대응)은 이 자료가 부족해 **확인 불가**입니다.

기존 시스템 로그에 필요한 요청·오류 정보가 있으면 이를 ALB 기록과 연결해 사용할 수 있습니다. 부족한 필드나 업무 점검만 추가하면 불필요한 수집 경로를 늘리지 않고 원인 분석을 보완할 수 있습니다. 보존 기간과 민감정보 보호는 함께 유지해야 합니다.

> **업무 계측 제약**: 로그 스키마·업무 요청 정의·외부 계측 자료가 없어 검색·필터·DB 호출의 성공률과 종단 간 장애 감지 수준은 확인 불가입니다.

### 4.5 관측 부하와 장애 시 처리 용량의 차이

**공통 기간의 CPU 부하는 낮지만 한 AZ만 남았을 때의 처리 용량은 시험 근거가 없습니다.** 서울 API 인스턴스·ASG와 RDS `arcamap-postgres`의 CloudWatch 지표입니다.

| 대상·지표 | 공통 기간의 관측값 | 서비스 연속성 판단 |
|---|---|---|
| API 인스턴스별 CPU | 교체 전후 네 인스턴스의 5분 최대 통계 중 최고 **15.67%** | CPU 포화 징후는 없지만 장애 시 한 대가 전체 부하를 감당하는지는 확인 불가입니다. |
| ASG 평균 CPU | 5분 평균 중 최대 **1.35%** | CPU 목표 추적에 따른 확장·축소 활동은 기록되지 않았습니다. |
| ASG 실행 인스턴스 수 | 09-14 18:05~09-21 23:55의 수량 지표에서 **2대** | 실행 상태가 유지되어도 ALB 정상 대상은 배포 중 0대가 되었습니다. |
| RDS CPU | 최대 **29.34%** | 최고 부하는 생성 직후에 발생했습니다. |
| RDS 가용 메모리·저장 공간 | 최소 **2.82 GiB·17.06 GiB** | 관측 부하에서 자원 부족 징후는 없었습니다. |
| RDS 연결 수 | 관측 최댓값 **0개** | 실제 업무 요청과 DB 처리의 연결을 판단할 근거가 부족합니다. |

[인스턴스별 CPU와 수량 기록](04-performance-efficiency.md#42-낮은-컴퓨팅-부하와-확장-검증-공백)은 개별 인스턴스와 ASG 지표를 구분합니다. [RDS 지표](04-performance-efficiency.md#43-rds-자원-사용과-미확인-업무-연결)에서 연결 수가 0인 원인은 확인 불가입니다. 짧은 연결이 지표에 남지 않았거나 DB를 사용하지 않는 요청이 많았을 가능성이 있습니다.

서울의 표준 On-Demand 최대 사용량은 공통 기간에 **8 vCPU**, 구성 확인 시점의 한도는 **16 vCPU**입니다. [API 확장 상한](../../terraform/modules/compute/main.tf#L44)인 `t3.small` 4대에는 8 vCPU가 필요합니다. 그러나 장애 자원과 대체 자원, 이미지 빌드가 겹칠 때의 필요 용량은 별도 근거가 없습니다. 서브넷별 여유 주소 249~250개는 현재 확장 범위에 충분합니다.

대표 검색·필터·DB 요청으로 한 AZ의 잔여 용량과 확장 소요 시간을 시험해야 합니다. 이를 통해 장애 중 유지할 최소 용량과 추가 기동 여유를 정할 수 있습니다. 부하 시험 중에도 운영 트래픽과 DB 연결 한도를 보호해야 하며 CPU 수치만으로 최소 인스턴스 수를 줄일 근거는 부족합니다.

> **관측 범위 제약**: ALB 대상 수 지표는 09-14 00:00~01:51과 09-15 01:33에 없고 ASG 수량 지표는 09-14 18:05에 시작하며 일부 구간이 빠져 있습니다. 이 구간의 정상 처리 용량은 지표만으로 확인할 수 없습니다.

관련 기준은 [REL01-BP04·BP06](#31-rel01-서비스-할당량과-제약-관리), [REL07-BP04](#37-rel07-수요-변화에-대한-대응), [REL11-BP05](#311-rel11-구성-요소-장애-대응), [REL12-BP03](#312-rel12-신뢰성-시험)입니다.

<a id="46-확보한-자료와-판단-제약"></a>

### 4.6 업무·복구 절차의 자료 제약

서비스의 [요청 흐름](../../README.md#2-user-request-flow사용자-요청-처리-흐름)과 [운영 기준](../../README.md#4-operational-criteria-and-constraints운영-기준-및-제약)은 공개되어 있습니다. 다음 항목은 운영 자료가 부족해 설계·대응 수준을 판단할 수 없습니다.

| 판단 대상 | 필요한 자료·운영상 영향 |
|---|---|
| API 장애 내성 | API 계약·재시도·시간 제한·상태 저장·요청 제한·기능 축소 자료가 없어 의존성 장애의 전파 범위를 판단할 수 없습니다. |
| 장애 대응 절차 | 사건별 담당자 조치·원인 분석·플레이북·훈련 기록이 없어 인지·대응 시간과 절차의 반복 가능성을 평가할 수 없습니다. |
| DNS·재해 복구 | DNS 위임·레코드의 운영 상태와 복구 대상 환경·전환 절차 자료가 없어 공개 접속 복구와 리전 재해 대응 수준을 판단할 수 없습니다. |
| 서비스 목표 | 가용성 목표와 RTO·RPO의 합의 자료가 없어 관측한 오류·복원 범위가 허용 수준에 맞는지 평가할 수 없습니다. |

관련 기준은 [네트워크](#32-rel02-네트워크-토폴로지-계획)·[서비스 구조](#33-rel03-워크로드-서비스-구조-설계)·[장애 예방](#34-rel04-분산-시스템의-장애-예방)·[장애 완화](#35-rel05-분산-시스템의-장애-완화), [REL12](#312-rel12-신뢰성-시험), [REL13](#313-rel13-재해-복구-계획)입니다. 업무 계측의 범위는 [로그·요청 기록](#44-로그-수집-경로와-업무-관측의-공백), 실제 복원 범위는 [백업·복구 기록](#43-rds-자동-백업의-복원-범위와-미검증된-복구-목표)에 있습니다.

## 5. Conclusion(결론)

ArcaMap은 **두 AZ의 API·ALB·NAT, RDS Multi-AZ, 자동 확장·백업과 이미지 기반 배포**로 자원 장애에 대비합니다. 공통 기간에는 초기 ALB 5xx **307건**과 배포 중 정상 대상 **0대**가 기록되었으며 당시 서비스 경보에도 운영자 알림이 없었습니다.

우선 **배포 중 정상 용량을 유지하고 경보를 담당자 대응에 연결**해야 합니다. 기존 시스템 로그의 API 기록과 ALB·CloudFront 로그를 활용하되, 업무 성공률과 의존성 장애 감지는 계측 자료가 부족해 확인 불가입니다.

데이터 복구는 업무별 RTO·RPO와 복원 대상을 정하고 실제 복원으로 검증해야 합니다. 한 AZ의 잔여 처리 용량, 초기 장애의 내부 원인·수동 조치, DNS·재해 복구 절차는 추가 운영 근거가 필요합니다.
