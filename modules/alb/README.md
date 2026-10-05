# API 로드 밸런서

`alb` 모듈은 공개 ALB `arcamap-api`와 API WAF를 구성합니다. ALB는 공개 서브넷 2개에서 요청을 받고 API 인스턴스로 전달합니다. [API 환경](../../env/api/README.md)에서 사용합니다.

## 요청 전달

| 항목 | 설정 |
|---|---|
| IP 주소 유형 | IPv4 |
| HTTP 리스너 | `80`, HTTPS `443`으로 `301` 리다이렉트 |
| HTTPS 리스너 | `443`, 입력한 ACM 인증서 사용 |
| TLS 정책 | `ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09` |
| 대상 그룹 | 인스턴스, HTTP `8080`, HTTP/1 |
| 분산 방식 | 라운드 로빈 |
| 대상 등록 해제 지연 | 300초 |
| 유휴 제한 시간 | 60초 |
| 클라이언트 연결 유지 시간 | 3,600초 |
| HTTP/2 | 활성화 |

상태 검사는 HTTP `/health`의 응답 코드 `200`을 확인합니다. 검사 간격은 30초, 제한 시간은 5초입니다. 정상 판정에는 연속 성공 5회, 비정상 판정에는 연속 실패 2회를 사용합니다.

## WAF

WAF 범위는 `REGIONAL`이며 기본 동작은 허용입니다. 다음 순서로 규칙을 적용합니다.

| 우선순위 | 규칙 | 동작 |
|---|---|---|
| 0 | `/health/db`, `/health/db/` 경로 | 차단 |
| 1 | `AWSManagedRulesAmazonIpReputationList` | 관리형 규칙 적용, `AWSManagedIPDDoSList`는 차단 |
| 2 | `AWSManagedRulesCommonRuleSet` | 관리형 규칙 적용 |
| 3 | `AWSManagedRulesKnownBadInputsRuleSet` | 관리형 규칙 적용 |

경로 차단 규칙은 URL 디코딩과 경로 정규화를 거친 값을 검사합니다. WAF 지표 수집은 활성화하고 요청 샘플 저장은 비활성화합니다.

## 로그

ALB 접근·연결·상태 검사 로그는 `log_group_arn`으로 지정한 CloudWatch 로그 그룹에 JSON 형식으로 전달합니다.

WAF 로그 그룹은 `aws-waf-logs-arcamap-api`이며 보존 기간은 14일입니다. `authorization`, `cookie`, `proxy-authorization` 헤더는 로그에서 가립니다.

## 입력과 출력

| 입력 | 내용 |
|---|---|
| `vpc_id` | 대상 그룹의 VPC ID |
| `public_subnet_ids` | 공개 서브넷 ID 2개 |
| `alb_security_group_id` | ALB 보안 그룹 ID |
| `certificate_arn` | 서울 리전 ACM 인증서 ARN |
| `log_group_arn` | ALB 로그 그룹 ARN |

`alb` 출력은 ALB의 ARN, ARN 접미사, DNS 이름, 호스팅 영역 ID와 대상 그룹의 ARN·ARN 접미사를 반환합니다. 입력과 출력의 구조는 [variables.tf](variables.tf)와 [outputs.tf](outputs.tf)에 정의합니다.
