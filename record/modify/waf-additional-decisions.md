# WAF 적용 범위 확대와 규칙·비용 조정

## 1. 운영 기록에 따른 개선

### 1.1 원인

운영 당시 CloudFront WAF의 관리형 규칙 그룹 4개는 모두 Count로 설정돼 있었습니다. 공격으로 판단한 요청도 차단하지 않고 기록만 남기는 상태였습니다. API 요청을 받는 ALB에는 WAF가 연결돼 있지 않았습니다.

7일 WAF 사용료 6.06달러 중 Anti-DDoS 기능 유지료는 4.18달러로, 전체의 68.90%를 차지했습니다.

### 1.2 변경 계획

추가 비용이 발생하는 Anti-DDoS 관리형 규칙 그룹을 제거합니다. 나머지 관리형 규칙 그룹 3개는 차단하도록 변경하고, API ALB에도 적용합니다.

웹 ACL은 보호 대상에 적용할 WAF 규칙을 담는 설정입니다. 기존 CloudFront 웹 ACL을 수정하고, API ALB용 웹 ACL을 서울 리전에 추가합니다.

| 적용할 AWS 관리형 규칙 그룹 | 검사 대상 |
|---|---|
| Amazon IP 신뢰도 목록 | 악성 활동과 관련된 IP |
| 핵심 규칙 세트(CRS) | 일반적인 웹 공격과 잘못된 요청 |
| 알려진 잘못된 입력 | 악용 사례가 알려진 요청 패턴 |

요청량 제한에는 속도 기반 규칙을 사용합니다. 정해진 시간 동안 요청 수가 기준을 넘으면 제한하는 규칙입니다. 제한값은 배포 후 요청 IP별 5분 정상 요청량과 경로별 처리 부담을 확인해 정합니다.

### 1.3 변경 후

[CloudFront WAF](../../modules/cloudfront/waf.tf)와 [API ALB WAF](../../modules/alb/waf.tf)를 다음과 같이 수정했습니다.

| 설정 | 변경 전 | 변경 후 |
|---|---|---|
| CloudFront Anti-DDoS 규칙 그룹 | `AWSManagedRulesAntiDDoSRuleSet` 사용 | 제거 |
| CloudFront의 유지할 관리형 규칙 그룹 3개 | 그룹 전체 Count | 그룹 전체 Count 해제: `override_action`을 `none`으로 변경 |
| API ALB 보호 | WAF 없음 | 서울 리전에 API 웹 ACL을 추가하고 ALB에 연결 |
| API 관리형 규칙 | 없음 | `AWSManagedRulesAmazonIpReputationList`, `AWSManagedRulesCommonRuleSet`, `AWSManagedRulesKnownBadInputsRuleSet` 추가 |
| 기본 동작 | CloudFront는 Allow | 양쪽 모두 차단 대상이 아닌 요청은 허용 |
| API WAF 로그 | 없음 | `aws-waf-logs-arcamap-api`에 허용·차단 요청 기록, 14일 보존 |
| API WAF 지표 | 없음 | CloudWatch 지표 수집 활성화 |
| 속도 기반 규칙 | 없음 | 배포 후 정상 요청량을 측정하고 제한값을 검증한 뒤 추가 |

관리형 규칙의 차단 설정은 [Terraform AWS Provider의 웹 ACL 설정](https://registry.terraform.io/providers/hashicorp/aws/6.63.0/docs/resources/wafv2_web_acl)을 기준으로 반영했습니다.

코드 수정은 완료했으며 AWS에는 아직 배포하지 않았습니다. 배포 후 정상 검색·필터·상세 조회·지도 요청이 차단되는지 검사하고, 정상 요청을 차단한 규칙에 한해 예외를 조정합니다. 비용은 Anti-DDoS 제거에 따른 절감액과 API WAF·로그의 추가 비용을 함께 비교합니다.

## 2. WAF 리소스의 Terraform 구성 검토

### 2.1 원인

검토 대상은 CloudFront·ALB의 웹 ACL, 규칙, 연결, 로그 설정과 WAF 리소스의 import 선언입니다. Terraform 구성과 해당 설정의 AWS 동작을 확인했습니다.

| 검토 대상 | 확인한 내용 |
|---|---|
| 요청 샘플 | CloudFront에서 저장하도록 설정돼 있으며, 일반 로그의 인증정보 가림 설정은 샘플에 적용되지 않음 |
| DDoS 활동 IP 규칙 | Amazon IP 신뢰도 목록의 `AWSManagedIPDDoSList`는 기본 동작이 Count |
| 과거 import 선언 | 과거 웹 ACL·로그 그룹·로그 설정을 가져오는 선언 3개가 남아 있음 |
| CloudFront 로그 목적지 | 로그 그룹 ARN 뒤에 `:*`가 붙어 있음 |

### 2.2 변경 계획

요청 샘플 저장을 끄고, 인증정보를 가린 일반 로그와 CloudWatch 지표를 사용합니다. AWS는 로그의 정보 가림 설정이 요청 샘플에는 적용되지 않는다고 명시하고 있습니다. ([참고](https://docs.aws.amazon.com/waf/latest/APIReference/API_VisibilityConfig.html))

DDoS 활동 IP도 차단하도록 `AWSManagedIPDDoSList`에 Block을 지정합니다. 해당 규칙의 기본 동작은 Count이므로 별도 변경이 필요합니다. ([참고](https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-ip-rep.html))

신규 배포에 사용하지 않는 과거 import 선언은 제거하고, CloudFront 로그 목적지는 로그 그룹 ARN으로 수정합니다. ([로그 목적지 설정 참고](https://registry.terraform.io/providers/hashicorp/aws/6.63.0/docs/resources/wafv2_web_acl_logging_configuration))

### 2.3 변경 후

| 설정 | 변경 전 | 변경 후 |
|---|---|---|
| 요청 샘플 | CloudFront 웹 ACL과 관리형 규칙 그룹에서 저장 | 양쪽 웹 ACL과 모든 규칙의 `sampled_requests_enabled`를 `false`로 설정 |
| DDoS 활동 IP | Count | 양쪽 웹 ACL의 `AWSManagedIPDDoSList`에 Block 지정 |
| 과거 import 선언 | `env/web/imports.tf`에 선언 3개 존재 | 선언과 전용 파일 제거 |
| CloudFront 로그 목적지 | `${aws_cloudwatch_log_group.waf.arn}:*` | `aws_cloudwatch_log_group.waf.arn` |
| 로그의 인증정보 가림 | CloudFront에 적용 | 양쪽 모두 `authorization`, `cookie`, `proxy-authorization` 헤더 가림 |

## 3. 추가한 WAF 경로 차단 규칙

[애플리케이션 코드 검토](application-code-review.md)에 따라 API 웹 ACL에 `/health/db` 외부 접근 차단 규칙을 추가했습니다. 우선순위는 0입니다.

`/health/db` 차단 규칙은 요청 경로에 URL 디코딩과 경로 정규화를 순서대로 적용한 뒤 `^/health/db/?$`로 검사합니다. `/health/db`와 `/health/db/`가 차단 대상입니다. `/health`와 `/api/places`는 이 규칙의 차단 대상에 포함되지 않습니다. ([문자 변환 참고](https://docs.aws.amazon.com/waf/latest/developerguide/waf-rule-statement-transformation.html))

## 4. 검증 결과

### 4.1 배포 전 검증

| 검증 | 결과 |
|---|---|
| CloudFront 환경 `terraform validate` | 통과 |
| ALB 모듈 단독 `terraform validate` | Provider 6.63.0과 기존 잠금 파일을 사용해 통과 |
| API 환경 전체 `terraform validate` | 배포 설정이 참조하는 `was/.artifacts/was.tar.gz`가 없어 실패 |
| WAF 파일 2개의 `terraform fmt -check` | 통과 |
| `node record/modify/check-waf.cjs cloudfront` / `alb` | 관리형 그룹 구성, Count 해제, DDoS Block, 요청 샘플 중단, 로그 목적지·헤더 가림, API 경로·ALB 연결 참조 검사 통과 |
| `git diff --check` | 통과 |

API 환경 전체 검증은 배포 산출물을 준비한 뒤 다시 수행해야 합니다. 실제 AWS 요청 차단과 로그 수집은 아직 검증하지 않았습니다.

### 4.2 배포 후 검증

| 구분 | 확인할 사항 |
|---|---|
| 운영 기록에 따른 개선 | CloudFront와 API ALB의 웹 ACL 연결 및 관리형 규칙 차단 설정 |
| 운영 기록에 따른 개선 | 정상 검색·필터·상세 조회·지도 요청의 처리 여부 |
| 운영 기록에 따른 개선 | 요청 IP별 5분 정상 요청량과 속도 기반 규칙의 제한값 |
| 운영 기록에 따른 개선 | Anti-DDoS 제거 비용과 API WAF·로그 추가 비용 |
| WAF Terraform 구성 검토에 따른 변경 | DDoS 활동 IP 규칙의 Block 설정. 해당 IP의 요청이 없으면 차단 실적은 미확인으로 기록 |
| WAF Terraform 구성 검토에 따른 변경 | 요청 샘플 저장 중단, 로그의 인증정보 가림과 정상 수집 여부 |
| WAF Terraform 구성 검토에 따른 변경 | 과거 리소스 ID를 가져오지 않고 새 WAF·로그 리소스가 생성되는지 확인 |
| 추가한 WAF 경로 차단 규칙 | 외부 `/health/db` 차단 여부. 인코딩·끝 슬래시 변형 포함 |
