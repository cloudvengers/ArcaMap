# 네트워크

`network` 모듈은 서울 리전에 VPC, 공개 서브넷 2개, API 사설 서브넷 1개를 구성합니다. [네트워크 환경](../../env/network/README.md)에서 사용합니다.

## VPC와 서브넷

VPC 이름은 `arcamap-vpc`이며 주소 범위는 `10.0.0.0/16`입니다. DNS 지원과 DNS 호스트 이름을 활성화합니다.

| 용도 | 가용 영역 | 주소 범위 |
|---|---|---|
| 공개 서브넷 | `ap-northeast-2a` | `10.0.1.0/24` |
| 공개 서브넷 | `ap-northeast-2c` | `10.0.2.0/24` |
| API 사설 서브넷 | `ap-northeast-2a` | `10.0.11.0/24` |

모든 서브넷의 공인 IP 자동 할당은 비활성화합니다.

## 라우팅

공개 서브넷의 기본 경로는 Internet Gateway로 연결합니다. `ap-northeast-2a`의 공개 서브넷에는 Elastic IP를 사용하는 NAT Gateway 1개를 배치합니다. API 사설 서브넷의 기본 경로는 이 NAT Gateway로 연결합니다.

## 출력

| 출력 | 내용 |
|---|---|
| `vpc_id` | VPC ID |
| `public_subnet_ids` | 가용 영역별 공개 서브넷 ID |
| `api_subnet_ids` | 가용 영역별 API 사설 서브넷 ID |

리소스는 [main.tf](main.tf)에, 출력은 [outputs.tf](outputs.tf)에 정의합니다.
