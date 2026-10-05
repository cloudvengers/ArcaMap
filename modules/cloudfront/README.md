# 콘텐츠 전달

`cloudfront` 모듈은 정적 파일, 사진과 지도 데이터를 S3에서 제공하는 CloudFront 배포를 구성합니다. OAC, 캐시 정책, 보안 응답 헤더, WAF와 로그 전달을 함께 관리합니다. [프런트엔드 환경](../../env/frontend/README.md)에서 사용합니다.

## 원본과 캐시

| 요청 경로 | S3 원본 | 기본·최대 TTL | 압축 |
|---|---|---|---|
| 기본 경로 | `static` | `frontend_cache_ttl_seconds` | 활성화 |
| `/assets/*` | `static` | 31,536,000초 | 활성화 |
| `/photos/*` | `photos` | `media_cache_ttl_seconds` | 비활성화 |
| `/20260907.pmtiles` | `maps` | `media_cache_ttl_seconds` | 비활성화 |

모든 캐시 정책의 최소 TTL은 0초입니다. 캐시 키에서 쿠키, 요청 헤더와 쿼리 문자열을 제외합니다. 정적 파일의 캐시 정책은 Gzip과 Brotli 인코딩을 지원합니다.

CloudFront는 `GET`, `HEAD` 요청을 허용하고 캐시합니다. HTTP 요청은 HTTPS로 리다이렉트합니다. 기본 문서는 `index.html`이며 HTTP/2, HTTP/3과 IPv6를 활성화합니다.

## S3 접근

CloudFront는 OAC의 SigV4 서명을 사용하여 원본에 접근합니다. 버킷 정책은 해당 CloudFront 배포 ARN과 AWS 계정의 읽기 요청을 허용합니다.

| 원본 | 읽기 허용 범위 |
|---|---|
| 정적 파일 | 버킷의 모든 객체 |
| 사진 | `photos/*` |
| 지도 | `20260907.pmtiles` |

원본과 로그 버킷은 AWS 서비스 주체를 제외한 요청에 HTTPS를 요구합니다.

## TLS와 응답 헤더

인증서는 `certificate_arn`으로 지정한 `us-east-1` ACM 인증서를 사용합니다. HTTPS 연결에는 SNI와 `TLSv1.2_2025` 정책을 적용합니다.

| 응답 헤더 | 설정 |
|---|---|
| HSTS | 31,536,000초, 하위 도메인·사전 등록 비활성화 |
| `X-Content-Type-Options` | `nosniff` |
| `X-Frame-Options` | `DENY` |
| `Referrer-Policy` | `strict-origin-when-cross-origin` |
| CSP의 `connect-src` | 동일 출처, `https://api.arcamap.app`, `https://protomaps.github.io/basemaps-assets/` |

## WAF와 로그

CloudFront WAF는 `us-east-1`에 `CLOUDFRONT` 범위로 구성합니다. 이름은 `CreatedByCloudFront-609132c8`이며 기본 동작은 허용입니다.

| 우선순위 | 관리형 규칙 그룹 |
|---|---|
| 1 | `AWSManagedRulesAmazonIpReputationList` |
| 2 | `AWSManagedRulesCommonRuleSet` |
| 3 | `AWSManagedRulesKnownBadInputsRuleSet` |

각 그룹의 규칙 동작을 적용하고 `AWSManagedIPDDoSList`는 차단으로 지정합니다. 지표 수집은 활성화하고 요청 샘플 저장은 비활성화합니다.

접근 로그는 JSON 형식으로 로그 버킷의 `AWSLogs/<계정 ID>/CloudFront/` 경로에 전달합니다. WAF 로그는 `aws-waf-logs-CloudFrontDistribution-<배포 ID>` 로그 그룹에 14일간 보관합니다. `authorization`, `cookie`, `proxy-authorization` 헤더는 로그에서 가립니다.

## 입력과 출력

| 입력 | 내용 |
|---|---|
| `account_id` | AWS 계정 ID |
| `frontend_domain_name`, `certificate_arn` | 웹 도메인과 ACM 인증서 ARN |
| `cloudfront_price_class` | CloudFront 가격 등급 |
| `frontend_cache_ttl_seconds`, `media_cache_ttl_seconds` | 콘텐츠별 TTL |
| `origin_buckets` | `static`, `photos`, `maps`의 버킷 이름·ARN·리전별 도메인 |
| `logs_bucket` | 접근 로그 버킷 정보 |

`cloudfront` 출력은 배포의 ID, ARN, 도메인 이름과 호스팅 영역 ID를 반환합니다. 입력과 출력의 구조는 [variables.tf](variables.tf)와 [outputs.tf](outputs.tf)에 정의합니다.
