# 보안 그룹

`security` 모듈은 ALB, API, DSQL VPC 엔드포인트, Image Builder의 보안 그룹을 구성합니다. [네트워크 환경](../../env/network/README.md)에서 사용합니다.

## 허용 통신

| 출발지 | 목적지 | TCP 포트 | 용도 |
|---|---|---|---|
| `0.0.0.0/0` | ALB | `80`, `443` | HTTP·HTTPS 요청 수신 |
| ALB | API | `8080` | API 요청 전달 |
| API | DSQL VPC 엔드포인트 | `5432` | 데이터베이스 접속 |
| Image Builder | DSQL VPC 엔드포인트 | `5432` | 데이터베이스 접속 |
| API | `0.0.0.0/0` | `443` | 외부 HTTPS 통신 |
| Image Builder | `0.0.0.0/0` | `443` | 외부 HTTPS 통신 |

VPC 내부 통신 규칙은 상대 보안 그룹을 참조합니다. ALB에서 API로, API·Image Builder에서 DSQL VPC 엔드포인트로 연결하는 규칙은 송신과 수신에 각각 적용합니다.

## 입력과 출력

`vpc_id`에 보안 그룹을 배치할 VPC ID를 입력합니다.

| 보안 그룹 이름 | ID 출력 |
|---|---|
| `arcamap-alb` | `alb_security_group_id` |
| `arcamap-api` | `api_security_group_id` |
| `arcamap-dsql-endpoint` | `dsql_endpoint_security_group_id` |
| `arcamap-imagebuilder` | `image_builder_security_group_id` |

통신 규칙은 [main.tf](main.tf)에, 입력과 출력은 [variables.tf](variables.tf)와 [outputs.tf](outputs.tf)에 정의합니다.
