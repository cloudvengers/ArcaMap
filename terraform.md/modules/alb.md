# ALB·API 대상 그룹

## 주요 개념

| 용어 | 개념 | 적용 |
|---|---|---|
| 리스너 | 지정 포트로 요청을 받아 규칙에 따라 처리 | HTTP 80 전환, HTTPS 443 전달 |
| 대상 그룹 | 요청을 전달할 서버와 상태 검사 설정 | EC2 인스턴스의 HTTP 8080 |
| TLS 종료 | HTTPS 암호화 연결을 로드 밸런서에서 처리 | ALB 이후 WAS에는 HTTP 전달 |
| 등록 해제 지연 | 제거되는 대상의 기존 요청 처리 대기 | 300초 |
| 헬스 체크 | 주기적으로 응답을 확인해 전달 가능 여부 판단 | `/health` HTTP 200 |

## 현재 구성·입력

| 항목 | 값 |
|---|---|
| 모듈 / 호출 루트 | `terraform/modules/alb` / `terraform/env/was` |
| `vpc_id` | `arcamap-vpc` 조회 결과 |
| `public_subnet_ids` | 2a·2c 퍼블릭 서브넷 |
| `alb_security_group_id` | `arcamap-alb` 그룹 ID |
| `certificate_arn` | 서울 리전의 `api.arcamap.app` ACM 인증서 |
| `log_group_arn` | `/aws/vendedlogs/elb/arcamap-api` ARN |
| ALB 이름·유형 | `arcamap-api`, 공개 Application, IPv4 |
| HTTP/2 | 활성화 |
| Idle timeout / keep-alive | 60초 / 3600초 |
| TLS 정책 | `ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09` |

## 요청·상태 검사

```text
HTTP:80 → HTTP 301 → HTTPS:443
HTTPS:443 → ALB에서 TLS 종료 → 대상 그룹 → WAS HTTP:8080
```

| 대상 그룹 설정 | 값 |
|---|---|
| 대상 유형 / 프로토콜 | `instance` / HTTP·HTTP1 |
| 분산 방식 | `round_robin`, cross-zone은 ALB 설정 사용 |
| Slow start / 등록 해제 지연 | 0초 / 300초 |
| 상태 검사 | HTTP, 대상 포트 8080, `/health`, 응답 200 |
| 간격 / 제한 시간 | 30초 / 5초 |
| 정상 / 비정상 임계값 | 연속 성공 5회 / 실패 2회 |

`/health`는 API 응답을 확인합니다. DB 연결 상태는 `/health/db`로 별도 확인합니다.

## 적용·점검

실행 위치: `/root/protomaps`. WAS 배포 아카이브와 DB 비밀번호 입력 준비 후 실행.

```bash
terraform -chdir=terraform/env/was plan -out=was.tfplan
terraform -chdir=terraform/env/was apply was.tfplan

arcamap_target_group="$(terraform -chdir=terraform/env/was output -json alb | jq -r '.target_group_arn')"
aws elbv2 describe-target-health \
  --region ap-northeast-2 --target-group-arn "$arcamap_target_group"
curl -sS -I --max-time 15 http://api.arcamap.app/health
curl -sS -i --max-time 15 https://api.arcamap.app/health
```

정상 기준: HTTP는 HTTPS로 301 전환, HTTPS는 200, 등록 대상은 `healthy`.

## 로그·출력

| 로그 | 전달 소스 |
|---|---|
| 접근 | `ALB_ACCESS_LOGS` |
| 연결 | `ALB_CONNECTION_LOGS` |
| 상태 검사 | `ALB_HEALTH_CHECK_LOGS` |

세 로그는 `/aws/vendedlogs/elb/arcamap-api`에 JSON으로 전달하며, 보존 기간은 30일입니다.

| `alb` 출력 필드 | 사용 |
|---|---|
| `arn`, `arn_suffix` | ALB 식별·경보 차원 |
| `dns_name`, `zone_id` | Route 53 API 별칭 |
| `target_group_arn` | ASG 연결·대상 상태 조회 |
| `target_group_arn_suffix` | 대상 그룹 경보 차원 |

출력은 HTTPS 리스너 연결 완료에 의존합니다.
