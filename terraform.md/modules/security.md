# 보안 그룹

## 주요 개념

| 용어 | 개념 | 적용 |
|---|---|---|
| 인바운드 | 자원으로 들어오는 연결의 허용 규칙 | ALB 80·443, API 8080, DB 5432 |
| 아웃바운드 | 자원에서 시작하는 연결의 허용 규칙 | ALB→API, API→DB·외부 HTTPS |
| 보안 그룹 참조 | 상대 자원의 그룹을 통신 허용 대상으로 지정 | 인스턴스 교체 시 개별 IP 관리 생략 |
| Stateful | 허용된 연결의 응답을 자동 허용 | 응답용 역방향 규칙 불필요 |

## 현재 구성

| 항목 | 값 |
|---|---|
| 모듈 / 호출 루트 | `terraform/modules/security` / `terraform/env/app` |
| 입력 | `vpc_id`, network 모듈의 VPC ID |
| 그룹 | `arcamap-alb`, `arcamap-api`, `arcamap-database` |
| 규칙 관리 | 그룹과 별도의 ingress·egress 자원 |
| 관리 접속 | SSM, SSH 인바운드 규칙 없음 |

## 허용 규칙

| 규칙 | 그룹 | 방향 | 상대 | 포트 |
|---|---|---|---|---|
| `alb_http` | ALB | 인바운드 | `0.0.0.0/0` | TCP 80 |
| `alb_https` | ALB | 인바운드 | `0.0.0.0/0` | TCP 443 |
| `alb_api` | ALB | 아웃바운드 | API 그룹 | TCP 8080 |
| `api_alb` | API | 인바운드 | ALB 그룹 | TCP 8080 |
| `api_database` | API | 아웃바운드 | DB 그룹 | TCP 5432 |
| `api_https` | API | 아웃바운드 | `0.0.0.0/0` | TCP 443 |
| `database_api` | DB | 인바운드 | API 그룹 | TCP 5432 |

```text
인터넷 → ALB:80·443 → API:8080 → RDS:5432
API → 외부 HTTPS:443
```

DB의 별도 아웃바운드 규칙은 없습니다. API가 시작한 DB 연결의 응답은 stateful 동작으로 허용됩니다. 외부 HTTPS 연결에는 API 서브넷의 NAT 경로도 필요합니다.

## 적용·점검

```bash
cd /root/protomaps
terraform -chdir=terraform/env/app plan -out=app.tfplan
terraform -chdir=terraform/env/app apply app.tfplan

arcamap_vpc_id="$(terraform -chdir=terraform/env/app output -raw vpc_id)"
aws ec2 describe-security-groups \
  --region ap-northeast-2 --filters "Name=vpc-id,Values=$arcamap_vpc_id" \
  --query 'SecurityGroups[].{Name:GroupName,Ingress:IpPermissions,Egress:IpPermissionsEgress}'
```

정상 기준: 세 그룹의 규칙이 위 표와 일치, API·DB의 인터넷 직접 수신 없음.

## 출력·연결

| 출력 | 연결 자원 | 출력 선행 조건 |
|---|---|---|
| `alb_security_group_id` | ALB | HTTP·HTTPS 수신, API 송신 규칙 |
| `api_security_group_id` | ASG·Image Builder EC2 | ALB 수신, DB·HTTPS 송신 규칙 |
| `database_security_group_id` | RDS | API 수신 규칙 |

db·was는 app 적용 완료 후 같은 VPC의 보안 그룹 이름으로 조회합니다. 동일 규칙은 app에서만 관리합니다.
