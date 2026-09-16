# VPC·서브넷·라우팅

## 주요 개념

| 용어 | 개념 | 적용 |
|---|---|---|
| VPC | IP 주소와 내부 통신 경로를 구성하는 네트워크 | `10.0.0.0/16` |
| 서브넷 | 하나의 AZ에 배치하는 VPC 주소 범위 | 퍼블릭·API·DB 분리 |
| 퍼블릭 서브넷 | IGW로 향하는 직접 경로가 있는 서브넷 | ALB·NAT 배치 |
| 프라이빗 서브넷 | IGW로 향하는 직접 경로가 없는 서브넷 | WAS·RDS 배치 |
| IGW | VPC와 인터넷 사이의 통신 관문 | 퍼블릭 기본 경로 |
| NAT Gateway | 사설 IPv4 출발지 주소를 변환하는 서비스 | API 서브넷의 외부 통신 |
| 라우팅 테이블 | 목적지별 다음 경로 | 더 구체적인 주소 범위의 경로 우선 |

## 현재 구성

| 항목 | 값 |
|---|---|
| 모듈 / 호출 루트 | `terraform/modules/network` / `terraform/env/app` |
| 입력 변수 | 없음 |
| VPC 이름·CIDR | `arcamap-vpc` · `10.0.0.0/16` |
| DNS support / hostnames | 모두 활성화 |
| 테넌시 | `default` |
| 퍼블릭 IPv4 자동 할당 | 모든 서브넷에서 비활성화 |
| IGW | VPC에 1개 |
| NAT·EIP | 퍼블릭 서브넷마다 1개, AZ별 총 2개 |

| 역할 | ap-northeast-2a | ap-northeast-2c | Name 태그 |
|---|---|---|---|
| 퍼블릭 | `10.0.1.0/24` | `10.0.2.0/24` | `arcamap-public-<AZ>` |
| API | `10.0.11.0/24` | `10.0.12.0/24` | `arcamap-api-<AZ>` |
| DB | `10.0.21.0/24` | `10.0.22.0/24` | `arcamap-database-<AZ>` |

## 라우팅

| 서브넷 | 목적지 | 다음 경로 | 라우팅 테이블 |
|---|---|---|---|
| 전체 | `10.0.0.0/16` | VPC `local` | 각 테이블의 내부 경로 |
| 퍼블릭 | `0.0.0.0/0` | IGW | 공통 1개 |
| API 2a | `0.0.0.0/0` | 2a NAT | 2a 전용 |
| API 2c | `0.0.0.0/0` | 2c NAT | 2c 전용 |
| DB | 외부 기본 경로 없음 | VPC 내부 통신 | DB 공통 1개 |

```text
인터넷 → IGW → ALB:443 → WAS:8080 → RDS:5432
WAS → 같은 AZ의 NAT → IGW → 외부 HTTPS:443
WAS → VPC local → RDS:5432
```

라우팅은 전달 경로를 정하며, 보안 그룹은 통신 허용 여부를 정합니다. 퍼블릭 서브넷 배치만으로 EC2에 공인 IP가 생기지는 않습니다.

## 적용·점검

```bash
cd /root/protomaps
terraform -chdir=terraform/env/app plan -out=app.tfplan
terraform -chdir=terraform/env/app apply app.tfplan

arcamap_vpc_id="$(terraform -chdir=terraform/env/app output -raw vpc_id)"
aws ec2 describe-route-tables \
  --region ap-northeast-2 --filters "Name=vpc-id,Values=$arcamap_vpc_id" \
  --query 'RouteTables[].{ID:RouteTableId,Subnets:Associations[].SubnetId,Routes:Routes}'
```

정상 기준: 서브넷 6개 연결, 라우팅 테이블 4개, 경로 `active`, API는 같은 AZ의 NAT 사용, DB 외부 기본 경로 없음.

## 출력

| 출력 | 형태 | 연결 |
|---|---|---|
| `vpc_id` | VPC ID | app의 security 모듈 |
| `public_subnet_ids` | AZ → 서브넷 ID | app 출력 |
| `api_subnet_ids` | AZ → 서브넷 ID | app 출력 |
| `database_subnet_ids` | AZ → 서브넷 ID | app 출력 |

서브넷 출력은 라우팅 테이블 연결 완료에 의존합니다. db·was는 app 적용 후 VPC·AZ·Name 태그로 조회합니다.
