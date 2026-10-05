# 콘텐츠 전달 환경

`frontend` 환경은 정적 파일·사진·지도·로그용 S3 버킷과 CloudFront를 관리합니다. 웹 도메인 `arcamap.app`은 CloudFront에 연결합니다.

## 경로와 캐시

| 요청 경로 | 원본 | 기본·최대 TTL |
|---|---|---|
| 기본 경로 | 정적 파일 버킷 | 300초 |
| `/assets/*` | 정적 파일 버킷 | 31,536,000초 |
| `/photos/*` | 사진 버킷 | 86,400초 |
| `/20260907.pmtiles` | 지도 버킷의 해당 객체 | 86,400초 |

모든 캐시 정책의 최소 TTL은 0초입니다. CloudFront 가격 등급은 `PriceClass_200`입니다. 입력값은 [terraform.tfvars](terraform.tfvars)에 지정합니다.

CloudFront는 OAC의 SigV4 서명으로 S3에 접근합니다. HTTP 요청은 HTTPS로 리다이렉트하며 HTTP/2, HTTP/3과 IPv6를 활성화합니다. 모든 콘텐츠 경로에 보안 응답 헤더 정책을 적용합니다.

## S3 저장소

| 구분 | 버킷 이름·접두사 | 현재 객체 만료 | 이전 버전 보존 |
|---|---|---|---|
| `static` | `arcamap-static-` 접두사 | 비활성화 | 7일 |
| `photos` | `arcamap-photos-` 접두사 | 비활성화 | 7일 |
| `maps` | `protomaps-565725315772-ap-northeast-2-an` | 비활성화 | 7일 |
| `cloudfront_logs` | `arcamap-cloudfront-logs-` 접두사 | 30일 | 7일 |

모든 버킷은 버전 관리, 퍼블릭 액세스 차단, `BucketOwnerEnforced` 소유권과 `AES256` 기본 암호화를 사용합니다. 수명 주기 규칙은 만료된 삭제 마커를 정리하고, 시작 후 7일이 지난 미완료 멀티파트 업로드를 중단합니다.

지도 버킷에는 `prevent_destroy=true`를 적용합니다. CloudFront의 지도 읽기 권한은 `20260907.pmtiles` 객체로 제한합니다. 저장소 설정은 [storage.tf](storage.tf)에 정의합니다.

## WAF와 로그

CloudFront WAF는 IP 평판, 공통 규칙과 알려진 악성 입력 규칙 그룹을 적용합니다. `AWSManagedIPDDoSList`의 동작은 차단입니다. 지표 수집은 활성화하고 요청 샘플 저장은 비활성화합니다.

접근 로그는 S3 로그 버킷에 JSON 형식으로 전달합니다. WAF 로그는 `us-east-1`의 CloudWatch 로그 그룹에 14일간 보관합니다. 세부 캐시·보안·로그 설정은 [CloudFront 모듈](../../modules/cloudfront/README.md)에 정의합니다.

## DNS와 인증서

`certificate_arn`에 웹 도메인의 `us-east-1` ACM 인증서를 지정합니다. DNS는 `route53_role_arn`의 역할을 사용하여 `route53_zone_id`의 공개 영역을 관리합니다. 이 영역의 이름은 `frontend_domain_name`과 일치해야 합니다.

웹 도메인의 `A`와 `AAAA` 별칭 레코드는 CloudFront로 연결합니다. 별칭 대상의 상태 평가와 레코드 덮어쓰기는 비활성화합니다.

## 출력

| 출력 | 내용 |
|---|---|
| `cloudfront` | 배포 ID·ARN·도메인·호스팅 영역 ID |
| `frontend_url` | HTTPS 웹 주소 |
| `s3_buckets` | `static`, `photos`, `maps`, `cloudfront_logs` 버킷 이름 |
| `s3_bucket_arns` | 4개 버킷의 ARN |

입력과 출력의 구조는 [variables.tf](variables.tf)와 [outputs.tf](outputs.tf)에 정의합니다.
