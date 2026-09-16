# CloudFront WAF·요청 로그

## 주요 개념

| 용어 | 개념 | 적용 |
|---|---|---|
| Web ACL | 웹 요청을 검사하는 WAF 규칙 묶음 | CloudFront 배포에 연결 |
| 관리형 규칙 그룹 | AWS가 제공·관리하는 검사 규칙 | 평판·일반 공격·잘못된 입력·DDoS 검사 |
| Count | 일치 결과를 집계하는 동작 | 기존 규칙 그룹 4개의 Count 설정 유지 |
| `import` | 기존 AWS 자원을 Terraform 주소에 등록 | WAF·로그 그룹·로그 설정 3개 |
| `redacted_fields` | WAF 로그에서 지정한 요청 필드의 값을 가림 | 인증·쿠키 헤더 3개 |

## 현재 구성·입력

| 항목 | 값 |
|---|---|
| 구성 파일 | `terraform/modules/cloudfront/waf.tf` |
| 가져오기 선언 | `terraform/env/web/imports.tf` |
| 호출 루트 / State | `terraform/env/web` / 루트의 `terraform.tfstate` |
| WAF 이름 | `CreatedByCloudFront-609132c8` |
| WAF ID | `e41dd9fc-b545-4b89-be77-8187f556c9e8` |
| Scope / 리전 | `CLOUDFRONT` / `us-east-1` |
| 연결 배포 / 도메인 | `E39UQTOCMBVZB3` / `arcamap.app` |
| 기본 동작 | `Allow` |
| 로그 그룹 | `aws-waf-logs-CloudFrontDistribution-E39UQTOCMBVZB3` |
| 로그 보존 / 클래스 | 14일 / `STANDARD` |
| 로그에서 가리는 헤더 | `authorization`·`cookie`·`proxy-authorization` |
| 지표 / 요청 샘플 | Web ACL과 규칙 그룹 모두 활성화 |

별도 모듈이 아닌 기존 CloudFront 모듈의 구성입니다. WAF 로그는 CloudWatch Logs에 14일 보존하며, CloudFront 접근 로그의 S3 보존 30일과 별개입니다.

## 규칙·연결

| 우선순위 | AWS 관리형 규칙 그룹 | 결과 처리 |
|---|---|---|
| 0 | `AWSManagedRulesAntiDDoSRuleSet` | Count |
| 1 | `AWSManagedRulesAmazonIpReputationList` | Count |
| 2 | `AWSManagedRulesCommonRuleSet` | Count |
| 3 | `AWSManagedRulesKnownBadInputsRuleSet` | Count |

DDoS 그룹 내부 설정: 차단 민감도 `LOW`, Challenge 사용 `ENABLED`, Challenge 민감도 `HIGH`. 기존 URI 예외 정규식도 유지합니다. 그룹 결과는 Count로 처리합니다.

```hcl
# terraform/modules/cloudfront/main.tf의 배포 리소스
web_acl_id = aws_wafv2_web_acl.site.arn
```

CloudFront의 `web_acl_id`에는 WAFv2 ARN을 지정합니다. `aws_wafv2_web_acl_association`은 이 연결에 사용하지 않습니다.

## 기존 자원 가져오기

2026-09-15에 콘솔에서 만든 자원 3개를 가져왔습니다. 아래 주소는 모두 `module.cloudfront.`로 시작합니다.

| Terraform 자원 | 가져오기 ID 형식 |
|---|---|
| `aws_wafv2_web_acl.site` | `ID/이름/CLOUDFRONT@us-east-1` |
| `aws_cloudwatch_log_group.waf` | `로그 그룹 이름@us-east-1` |
| `aws_wafv2_web_acl_logging_configuration.site` | `Web ACL ARN@us-east-1` |

기본 Provider 리전이 서울이므로 가져오기 ID에도 `@us-east-1`을 명시합니다.

기존 설정 조회 → 별도 임시 디렉터리에서 `plan -generate-config-out=generated.tf`로 코드 생성 → CloudFront 모듈에 배치 → 전체 plan 검토 → 저장한 계획 적용 순서로 진행했습니다. 가져오기는 완료됐으며 이후에는 일반 plan·apply로 관리합니다.

## 조회·검증

```bash
cd /root/protomaps
aws cloudfront get-distribution-config \
  --id E39UQTOCMBVZB3 --query 'DistributionConfig.WebACLId'
aws wafv2 get-web-acl --region us-east-1 --scope CLOUDFRONT \
  --name CreatedByCloudFront-609132c8 \
  --id e41dd9fc-b545-4b89-be77-8187f556c9e8
terraform -chdir=terraform/env/web state list
terraform -chdir=terraform/env/web validate
terraform -chdir=terraform/env/web test \
  -filter=tests/modules_unit_test.tftest.hcl
terraform -chdir=terraform/env/web plan -detailed-exitcode
```

AWS CLI 명령은 같은 설정을 확인하는 조회 예시입니다. 당시 AWS 조회는 MCP로, Terraform 검증·적용은 CLI로 수행했습니다.

## 당시 결과·정상 기준

| 검사 | 2026-09-15 결과 |
|---|---|
| 가져오기 계획·적용 | 3개 가져오기, 생성·변경·삭제 모두 0개 |
| 형식 검사 / `validate` | 통과 |
| 모의 테스트 | 6개 통과, WAF 연결·Count·로그 보존·헤더 가림 포함 |
| 적용 후 전체 plan | `No changes`, 종료 코드 0 |
| AWS 구성 비교 | CloudFront ETag·WAF LockToken 작업 전후 동일 |
| State 백업 | `terraform/env/web/terraform.tfstate.backup` |

가져오기 리전 오류는 `@us-east-1`, 모의 테스트 오류는 `override_resource` 지정으로 해결했습니다.
