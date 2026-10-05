# S3 버킷

`s3-bucket` 모듈은 버전 관리와 수명 주기 규칙을 적용한 S3 버킷을 구성합니다. [API 환경](../../env/api/README.md)의 배포 파일 저장소와 [프런트엔드 환경](../../env/frontend/README.md)의 정적 파일·사진·로그 저장소에서 사용합니다.

## 보호 설정

| 항목 | 설정 |
|---|---|
| 버킷 이름 | `bucket_prefix`에 고유 접미사를 붙여 생성 |
| 퍼블릭 액세스 차단 | 4개 항목 모두 활성화 |
| 객체 소유권 | `BucketOwnerEnforced` |
| 기본 암호화 | `AES256` |
| 버전 관리 | 활성화 |
| 강제 삭제 | 비활성화 |

## 보존 기간

객체의 이전 버전은 `noncurrent_retention_days`에 지정한 기간이 지나면 만료됩니다. 기본값은 7일입니다. 현재 객체의 만료 기간은 `expiration_days`로 지정합니다.

수명 주기 규칙은 만료된 삭제 마커를 정리하고, 시작 후 7일이 지난 미완료 멀티파트 업로드를 중단합니다.

| 입력 | 내용 | 기본값 |
|---|---|---|
| `bucket_prefix` | 버킷 이름 접두사 | 필수 입력 |
| `noncurrent_retention_days` | 이전 버전 보존 기간 | 7일 |
| `expiration_days` | 현재 객체의 만료 기간 | `null`, 만료 비활성화 |

## 출력

`bucket` 객체는 버킷 이름 `id`, ARN `arn`, 리전별 도메인 이름 `bucket_regional_domain_name`을 반환합니다.

리소스는 [main.tf](main.tf)에, 입력과 출력은 [variables.tf](variables.tf)와 [outputs.tf](outputs.tf)에 정의합니다.
