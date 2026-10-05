# DSQL 연결 방식 — VPC Interface Endpoint(PrivateLink)

## 배경과 문제

### 배경

- DB의 상시 인스턴스 실행료를 줄이고 아키텍처·EC2 서버 운영 역량을 기르기 위해 RDS를 Aurora DSQL로 변경합니다.
- 기존 EC2와 RDS는 같은 VPC의 사설 IP로 연결되어 `local` 경로로 통신했습니다.
- API EC2는 프라이빗 서브넷에서 운영하고, 외부 통신용 NAT는 유지합니다.

### 문제

- DSQL은 사용자 VPC의 서브넷에 배치하지 않는 AWS 관리형 서버리스 DB이므로, EC2에서 DSQL 엔드포인트에 접속할 경로가 새로 필요합니다. [DSQL 연결 방식](https://aws.amazon.com/blogs/database/securing-amazon-aurora-dsql-access-control-best-practices/)
- 비용 한도와 통신 성능을 고려해 연결 방식을 정해야 합니다.

## 검토한 대안

| 대안 | DB 연결 경로 | 과금 항목 |
|---|---|---|
| NAT를 통한 공개 엔드포인트 연결 | 프라이빗 EC2 → NAT → DSQL 공개 엔드포인트 | NAT 유지료·DB 통신에 대한 NAT 데이터 처리료 |
| VPC Interface Endpoint를 통한 PrivateLink 연결 | 프라이빗 EC2 → Endpoint 사설 IP → PrivateLink → DSQL | 기존 NAT 유지료·Endpoint 유지료·DB 통신에 대한 Endpoint 데이터 처리료 |

- PrivateLink는 Endpoint의 사설 IP를 통해 DSQL에 연결합니다. [DSQL PrivateLink 연결 지침](https://docs.aws.amazon.com/aurora-dsql/latest/userguide/privatelink-managing-clusters.html)

### 비용 비교

- **단가 기준:** 서울 리전(`ap-northeast-2`) 온디맨드 요금입니다. [NAT Gateway 요금](https://aws.amazon.com/vpc/pricing/), [PrivateLink 요금](https://aws.amazon.com/privatelink/pricing/)
- **월 유지료 가정:** 730시간, NAT 1개, Endpoint 1개를 1개 AZ에 배치하며, NAT·Endpoint는 EC2와 같은 AZ를 사용합니다.
- **Endpoint 처리료 구간:** 해당 리전의 전체 Interface Endpoint 합산 처리량 중 월 첫 1PB에 적용되는 단가입니다.

| 과금 항목 | 시간당 유지료(USD) | GB당 처리료(USD) | 730시간 유지료 예시(USD) |
|---|---:|---:|---:|
| NAT Gateway | 0.059 | 0.059 | 43.07 |
| Interface Endpoint | 0.013 | 0.010 | 9.49 |

- **통신량 정의:** `B`는 EC2와 DSQL 사이에서 요청·응답으로 송수신한 월간 데이터 합계(GB)이며, 두 연결 방식에 같은 값을 적용합니다.
- **비교 범위:** 외부 통신용 NAT를 유지하는 조건에서 세전 NAT·Endpoint 유지료와 DB 통신에 대한 데이터 처리료를 비교합니다. 공인 IPv4·기타 외부 통신·DSQL 자체 비용은 별도입니다.

| 연결 방식 | 비교 비용(USD/월) |
|---|---|
| NAT만 사용 | `43.07 + 0.059 × B` |
| NAT 유지 + DSQL용 Endpoint | `52.56 + 0.010 × B` |

- **추가 비용:** Endpoint를 사용하는 방식의 월 추가 비용은 `9.49 − 0.049 × B`달러입니다.
- **손익분기점:** 월 DB 통신량이 약 **193.67GB**이면 처리료 절감분이 Endpoint 유지료를 상쇄합니다.

### 통신 성능

- **성능 비교 근거:** 이 서비스의 NAT·PrivateLink 연결 시간과 동일 쿼리 응답 시간의 비교 측정값은 없습니다.
- **연결 경로:** PrivateLink를 사용하면 DB 통신은 NAT를 경유하지 않고 AWS 내부 사설 경로로 전달됩니다. [DSQL 연결 경로](https://docs.aws.amazon.com/aurora-dsql/latest/userguide/privatelink-managing-clusters.html)
- **기대 효과:** AWS의 광고 워크로드 성능 지침은 사설 연결을 네트워크 홉과 지연을 줄이는 수단으로 설명합니다. 이 일반 지침은 연결 방식의 기대 효과를 판단하는 근거입니다. [AWS 사설 연결 성능 지침](https://docs.aws.amazon.com/wellarchitected/latest/video-streaming-advertising-lens/advperf05-bp01.html)

## 결정과 이유

**선택: DSQL 연결용 VPC Interface Endpoint(PrivateLink)**

- **DB 통신 분리:** EC2와 DSQL은 AWS 내부 사설 경로로 연결하고, NAT는 외부 통신에 사용합니다.
- **처리 단가:** DB 통신의 GB당 처리료가 낮은 방식을 사용합니다. Endpoint의 추가 유지료를 부담하며 사설 DB 연결을 구성합니다.
- **운영 역량:** Endpoint 보안 그룹·Private DNS·IAM 인증을 함께 설계·관리하며 서비스 연결과 접근 제어를 운영합니다.

### 결과

- **이점:** EC2에서 Endpoint까지는 VPC의 `local` 경로를 사용하고, Endpoint에서 DSQL까지는 PrivateLink로 연결합니다. [Endpoint 내부 라우팅](https://repost.aws/knowledge-center/vpc-fix-gateway-or-interface-endpoint)
- **제약:** 외부 통신용 NAT 유지료에 Endpoint 유지료가 추가됩니다. 월 730시간 기준 추가 유지료는 9.49달러이며, 적은 DB 통신량에서는 네트워크 비용이 증가합니다.
- **제약:** DSQL 클러스터별 연결 서비스명과 접속 호스트를 사용하고 Private DNS·보안 그룹·IAM 인증·TLS 검증을 구성해야 합니다. [DSQL Endpoint 구성](https://docs.aws.amazon.com/aurora-dsql/latest/userguide/privatelink-managing-clusters.html)
