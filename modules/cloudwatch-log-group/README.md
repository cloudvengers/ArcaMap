# CloudWatch 로그 그룹

`cloudwatch-log-group` 모듈은 이름과 보존 기간을 지정한 로그 그룹 1개를 구성합니다. 로그 클래스는 `STANDARD`입니다. [API 환경](../../env/api/README.md)의 시스템·ALB·Image Builder 로그에 사용합니다.

| 입력 | 내용 |
|---|---|
| `name` | 로그 그룹 이름 |
| `log_retention_days` | CloudWatch Logs에서 지원하는 보존 기간 |

두 입력은 필수입니다. `log_group` 출력은 로그 그룹의 `name`과 `arn`을 반환합니다.

리소스는 [main.tf](main.tf)에, 입력과 출력은 [variables.tf](variables.tf)와 [outputs.tf](outputs.tf)에 정의합니다.
