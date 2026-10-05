# 네트워크 환경

`network` 환경은 서울 리전의 VPC, 서브넷, 라우팅, 보안 그룹과 SNS 알림 토픽을 구성합니다. [network 모듈](../../modules/network/README.md)과 [security 모듈](../../modules/security/README.md)을 사용합니다.

## 네트워크 배치

VPC 이름은 `arcamap-vpc`이며 주소 범위는 `10.0.0.0/16`입니다. DNS 지원과 DNS 호스트 이름을 활성화합니다.

| 용도 | 가용 영역 | 주소 범위 | 기본 경로 |
|---|---|---|---|
| 공개 서브넷 | `ap-northeast-2a` | `10.0.1.0/24` | Internet Gateway |
| 공개 서브넷 | `ap-northeast-2c` | `10.0.2.0/24` | Internet Gateway |
| API 사설 서브넷 | `ap-northeast-2a` | `10.0.11.0/24` | 같은 가용 영역의 NAT Gateway |

NAT Gateway는 `ap-northeast-2a`의 공개 서브넷에 1개를 배치합니다. 모든 서브넷의 공인 IP 자동 할당은 비활성화합니다.

## 보안 그룹

| 보안 그룹 | 허용 통신 |
|---|---|
| `arcamap-alb` | 외부에서 TCP `80`, `443` 수신. API로 TCP `8080` 송신 |
| `arcamap-api` | ALB에서 TCP `8080` 수신. DSQL 엔드포인트로 TCP `5432`, 외부로 TCP `443` 송신 |
| `arcamap-dsql-endpoint` | API·Image Builder에서 TCP `5432` 수신 |
| `arcamap-imagebuilder` | DSQL 엔드포인트로 TCP `5432`, 외부로 TCP `443` 송신 |

## 경보 알림

SNS 토픽 이름은 `arcamap-operations`입니다. 같은 계정의 서울 리전에 있는 `arcamap-*` CloudWatch 경보가 이 토픽에 알림을 게시할 수 있습니다.

`notification_email`에 수신 주소를 입력합니다. 이메일 구독은 수신자의 확인을 거쳐 활성화합니다.

## 출력

[outputs.tf](outputs.tf)는 VPC ID, 가용 영역별 공개·사설 서브넷 ID, 보안 그룹 ID 4개와 SNS 토픽 ARN을 반환합니다. 다른 환경은 이름과 태그로 네트워크 리소스를 조회합니다.

모듈과 SNS 구성은 [main.tf](main.tf)에, 수신 주소 입력은 [variables.tf](variables.tf)에 정의합니다.
