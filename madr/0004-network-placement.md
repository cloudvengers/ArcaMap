# 네트워크 배치 — 프라이빗 EC2 기본 1대·NAT 1개·퍼블릭 ALB

## 배경과 문제

### 배경

- 현재 AWS에는 서비스 인프라가 배포되어 있지 않으며, 기존 고가용성 구성을 단일 구성 운영 기반으로 재구성합니다. 성능 효율성·지속 가능성·비용 최적화·보안을 기준으로 네트워크 배치를 정합니다.
- 기존 인프라 코드는 서울 리전의 두 가용 영역에 퍼블릭·API·DB 서브넷과 NAT Gateway 2개를 구성하고, API EC2를 최소 2대 운영하도록 정의되어 있습니다.
- API EC2는 프라이빗 서브넷에서 기본 1대, 부하 증가 시 최대 2대로 운영합니다. DB는 Aurora DSQL을 사용하고 VPC Interface Endpoint로 사설 접속하며, 외부 통신용 NAT는 유지합니다.

### 문제

- 1차 운영의 7일 비용 기록에서 NAT Gateway 2개의 유지 시간 합계는 336시간, 유지료는 19.82달러였습니다. 처리료는 0.09달러였습니다. 단일 EC2 운영에 맞춰 NAT 수량과 상시 유지 비용을 줄일 필요가 있습니다.
- 인터넷 요청을 받는 ALB는 서로 다른 가용 영역의 퍼블릭 서브넷 2개를 사용합니다. API EC2의 운영 대수를 줄이면서 ALB에 필요한 서브넷 구성을 유지해야 합니다. [ALB 가용 영역·서브넷 조건](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/application-load-balancers.html)
- DSQL은 사용자 VPC의 DB 서브넷에 배치하는 데이터베이스가 아닙니다. VPC Interface Endpoint는 선택한 서브넷에 사설 IP를 가진 네트워크 인터페이스를 생성하므로, EC2와 같은 프라이빗 서브넷을 사용할 수 있습니다. DB 접속 경로와 접근 통제를 구성하되 Endpoint만을 위한 별도 서브넷이 필요한지 판단해야 합니다. [DSQL PrivateLink 연결](https://docs.aws.amazon.com/aurora-dsql/latest/userguide/privatelink-managing-clusters.html)

## 검토한 대안

- 두 대안 모두 API EC2 기본 1대·최대 2대, 외부 통신용 NAT Gateway 1개, 서로 다른 가용 영역의 퍼블릭 서브넷 2개에 연결한 ALB를 전제로 합니다.

| 대안 | 프라이빗 서브넷 구성 | DB 접근 통제 | 관리 범위 |
|---|---|---|---|
| EC2와 Endpoint를 같은 프라이빗 서브넷에 배치 | 같은 가용 영역의 서브넷 1개를 함께 사용 | Endpoint 보안 그룹·IAM 인증·TLS 검증 | 기존 API 서브넷을 사용하고 Endpoint 보안 그룹을 별도로 관리 |
| Endpoint용 프라이빗 서브넷을 별도로 구성 | 같은 가용 영역에 EC2용·Endpoint용 서브넷을 각각 구성 | Endpoint 보안 그룹·IAM 인증·TLS 검증 | Endpoint용 서브넷과 라우팅 테이블 연결을 추가로 관리 |

## 결정과 이유

**선택: EC2와 DSQL Endpoint를 같은 프라이빗 서브넷에 배치하고, 같은 가용 영역의 퍼블릭 NAT Gateway 1개와 두 가용 영역의 퍼블릭 ALB 사용**

- **운영 가용 영역:** API EC2를 배치하는 가용 영역입니다. ASG는 이 영역의 프라이빗 서브넷을 사용하며, 부하 증가로 증설되는 인스턴스도 같은 서브넷에 배치합니다.
- **NAT 방식:** 단일 가용 영역 방식(Zonal)의 퍼블릭 NAT Gateway를 사용합니다. 운영 가용 영역의 퍼블릭 서브넷에 배치하고 EIP를 연결합니다. [AWS NAT 구성 지침](https://repost.aws/knowledge-center/nat-gateway-vpc-private-subnet)

| 가용 영역 | 서브넷 | 배치할 구성요소 | 통신 경로 |
|---|---|---|---|
| 운영 가용 영역 | 퍼블릭 | ALB 연결·퍼블릭 NAT Gateway 1개와 EIP | 인터넷 게이트웨이 연결 |
| 다른 가용 영역 | 퍼블릭 | 같은 ALB 연결 | 인터넷 게이트웨이 연결 |
| 운영 가용 영역 | 프라이빗 | API EC2 기본 1대·최대 2대, 임시 Image Builder EC2, DSQL Interface Endpoint | EC2 외부 통신은 NAT, DB 통신은 Endpoint 사용 |

- **성능 효율성:** EC2와 Endpoint를 같은 가용 영역에 배치합니다. DB 통신은 `EC2 → Endpoint 사설 IP → PrivateLink → DSQL` 경로를 사용하고 NAT를 경유하지 않습니다.
- **지속 가능성·비용 최적화:** API EC2의 기본 운영 대수를 1대로 줄이고 NAT Gateway는 1개를 유지합니다. 기본 운영과 부하 증가 시 증설에 필요한 외부 통신 경로를 유지하면서 중복 NAT의 상시 자원과 유지 비용을 줄입니다.
- **보안:** API·빌드 EC2에는 공인 IP를 부여하지 않고, API 요청은 ALB를 통해 받습니다. Endpoint에는 별도 보안 그룹을 연결하고 운영 API 보안 그룹과 Image Builder 전용 보안 그룹에서 오는 TCP 5432를 허용합니다. DSQL IAM 인증과 TLS 검증을 적용합니다.
- **구성 관리:** EC2와 Endpoint가 같은 서브넷을 사용해도 각각 별도의 사설 IP와 보안 그룹을 갖습니다. Endpoint용 서브넷을 추가하지 않고 필요한 DB 접근 통제를 구성합니다.
- **ALB의 역할 유지:** ALB는 퍼블릭 서브넷 2개에서 HTTPS 요청 수신·TLS 종료·API 대상 상태 검사를 담당하고, API EC2는 한 가용 영역의 프라이빗 서브넷에서 운영합니다.
- **가용 영역 간 부하 분산:** ALB 대상 그룹의 가용 영역 간 부하 분산을 기본 활성 상태로 유지해 두 영역의 ALB 노드가 운영 가용 영역의 API로 요청을 전달하도록 합니다. [AWS 대상 그룹 부하 분산](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/edit-target-group-attributes.html)

### 결과

- **이점:** NAT Gateway를 2개에서 1개로 줄여 상시 유지 비용을 줄이고, 프라이빗 EC2의 외부 통신을 유지합니다.
- **이점:** Endpoint용 서브넷을 추가하지 않고 EC2와 DSQL의 사설 연결을 구성합니다. DB 통신과 외부 통신은 각각 Endpoint와 NAT를 사용합니다.
- **제약:** API EC2·NAT·Endpoint가 한 가용 영역에 있으므로 해당 가용 영역에 장애가 발생하면 API 서비스와 외부·DB 접속이 영향을 받습니다. ALB가 두 가용 영역에 있어도 API 처리 용량은 한 가용 영역에 있습니다.
- **제약:** NAT Gateway의 유지료·처리료와 EIP 비용, Endpoint의 유지료·처리료가 발생합니다.
- **제약:** Endpoint 보안 그룹·Private DNS·DSQL IAM 인증·TLS 검증을 함께 구성해야 합니다.
