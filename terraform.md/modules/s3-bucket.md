# S3 버킷

## 주요 개념

| 용어 | 개념 | 적용 |
|---|---|---|
| Block Public Access | 공개 ACL·정책을 통한 버킷 공개 차단 | 네 옵션 모두 활성화 |
| BucketOwnerEnforced | 버킷 소유자가 객체 소유권을 갖고 ACL 비활성화 | 정책·IAM으로 접근 제어 |
| SSE-S3 | S3 관리 키를 사용하는 저장 시 암호화 | `AES256` |
| 버전 관리 | 덮어쓰기·삭제 전 객체 버전을 보존 | 사진 버킷 |
| 수명 주기 | 경과 일수에 따라 객체·이전 버전 정리 | 로그 30일, 사진 이전 버전 7일 |

## 현재 구성

| 항목 | 값 |
|---|---|
| 모듈 | `terraform/modules/s3-bucket` |
| 호출 루트 | `terraform/env/web`, `terraform/env/was` |
| 이름 | 입력 접두사 + Terraform 고유 접미사 |
| 네임스페이스 | `global` |
| 공개 차단 | `block_public_acls`, `block_public_policy`, `ignore_public_acls`, `restrict_public_buckets` 모두 true |
| 소유권 / 암호화 | `BucketOwnerEnforced` / `AES256` |
| 삭제 | `force_destroy=false`, 객체가 남은 버킷 강제 비우기 없음 |

## 입력·현재 호출값

| 입력 | 조건·동작 |
|---|---|
| `bucket_prefix` | 소문자·숫자·하이픈 사용, 하이픈으로 끝나는 필수 접두사 |
| `expiration_days` | 기본 `null`, 양의 정수 입력 시 현재 객체 만료 |
| `noncurrent_retention_days` | 기본 `null`, 양의 정수 입력 시 버전 관리·이전 버전 만료·삭제 마커 정리 |

| 루트·호출 키 | 접두사 | 버전·만료 |
|---|---|---|
| web·`buckets["static"]` | `arcamap-static-` | 버전 관리·만료 규칙 없음 |
| web·`buckets["photos"]` | `arcamap-photos-` | 버전 관리, 이전 버전 7일 후 만료 |
| web·`buckets["cloudfront_logs"]` | `arcamap-cloudfront-logs-` | 현재 객체 30일 후 만료 |
| was·`deployment_bucket` | `arcamap-deploy-` | 버전 관리·만료 규칙 없음, 아카이브 SHA-256별 객체 키 |

수명 주기는 버킷당 한 자원으로 관리합니다. 사진은 버전 관리 적용 후 수명 주기를 연결하며, 만료된 삭제 마커도 정리합니다.

## 정책·소유 범위

| 대상 | 정책 관리자 | 허용 범위 |
|---|---|---|
| 정적·사진·지도 오리진 | web의 CloudFront 모듈 | 지정 배포의 객체 읽기 |
| CloudFront 로그 버킷 | web의 CloudFront 모듈 | 로그 전달 서비스의 쓰기 |
| WAS 배포 버킷 | was의 `deployment.tf`·IAM | TLS 필수, 빌드 역할의 지정 객체 읽기 |
| 기존 지도 버킷 | web에서 조회 | 버킷 생성·버전·수명 주기 변경 없음 |

## 적용·점검

설정 변경은 버킷을 호출하는 web 또는 was 루트에서 plan·apply합니다. WEB 버킷 적용 예시:

```bash
cd /root/protomaps
terraform -chdir=terraform/env/web plan -out=web.tfplan
terraform -chdir=terraform/env/web apply web.tfplan
terraform -chdir=terraform/env/web output s3_buckets

arcamap_static_bucket="$(terraform -chdir=terraform/env/web output -json s3_buckets | jq -r '.static')"
aws s3api get-public-access-block \
  --region ap-northeast-2 --bucket "$arcamap_static_bucket"
aws s3api get-bucket-encryption \
  --region ap-northeast-2 --bucket "$arcamap_static_bucket"
```

정상 기준: 공개 차단 네 옵션 true, 기본 암호화 `AES256`.

## 출력

| `bucket` 필드 | 사용 |
|---|---|
| `id` | 객체 업로드·버킷 조회 |
| `arn` | IAM·버킷 정책 |
| `bucket_regional_domain_name` | CloudFront S3 오리진 |

출력은 공개 차단·소유권·암호화 설정 완료에 의존합니다. 정적 버킷의 이전 배포 복구에는 이전 빌드 산출물이 필요합니다.
