# CloudFront·오리진 접근·WAF

## 주요 개념

| 용어 | 개념 | 적용 |
|---|---|---|
| 캐시 동작 | 요청 경로별 오리진·캐시·메서드 설정 | 기본·사진·지도 경로 분리 |
| 캐시 키 | 같은 캐시 객체로 취급할 요청의 기준 | 쿠키·쿼리 문자열·추가 헤더 제외 |
| OAC | CloudFront의 S3 요청 서명 | SigV4, 항상 서명 |
| Range GET | 객체의 일부 바이트만 요청 | PMTiles 지도 타일 읽기 |
| SNI | TLS 연결에서 도메인에 맞는 인증서 선택 | `sni-only` |
| WAF 연결 | 배포의 요청 검사 Web ACL 지정 | `web_acl_id`에 WAFv2 ARN 참조 |

## 현재 구성·입력

| 항목 | 값 |
|---|---|
| 모듈 / 호출 루트 | `terraform/modules/cloudfront` / `terraform/env/web` |
| `account_id` | 서비스 계정 `565725315772` |
| `frontend_domain_name` | `arcamap.app` |
| `certificate_arn` | `us-east-1`의 웹 ACM 인증서 |
| `frontend_cache_ttl_seconds` | 300초 |
| `media_cache_ttl_seconds` | 86400초 |
| `cloudfront_price_class` | `PriceClass_200` |
| `origin_buckets` | `static`, `photos`, `maps`의 ID·ARN·리전 도메인 |
| `logs_bucket` | 로그 버킷 ID·ARN |
| 기본 객체 | `index.html` |
| HTTP / IPv6 | HTTP/2·HTTP/3 / 활성화 |
| TLS 정책 | `TLSv1.2_2025`, `sni-only` |
| 오리진 연결 | 최대 3회, 제한 시간 10초 |
| 지역 제한 | 없음 |
| 적용 대기 | `wait_for_deployment=true` |
| WAF | `CreatedByCloudFront-609132c8`, `CLOUDFRONT`, `us-east-1` |
| WAF 규칙 결과 | AWS 관리형 규칙 그룹 4개 모두 Count |

## 요청 경로·캐시

| 경로 | 오리진 | 최소 / 기본 / 최대 TTL | 압축 |
|---|---|---|---|
| 기본 | 정적 S3 | 0 / 300 / 300초 | gzip·Brotli |
| `/photos/*` | 사진 S3 | 0 / 86400 / 86400초 | 비활성화 |
| `/20260907.pmtiles` | 기존 지도 S3 | 0 / 86400 / 86400초 | 비활성화 |

- 모든 동작: GET·HEAD 허용, HTTP→HTTPS 전환
- 캐시 정책: 쿠키·쿼리 문자열·추가 헤더 제외, 웹은 압축 협상을 위한 Accept-Encoding 사용
- 지도 객체: `protomaps-565725315772-ap-northeast-2-an/20260907.pmtiles`
- API: 브라우저가 `https://api.arcamap.app`의 ALB로 직접 요청

## 버킷 정책·로그

| 대상 | 허용 주체 | 범위 |
|---|---|---|
| 정적·사진 객체 | `cloudfront.amazonaws.com` | 해당 배포 ARN, 버킷 내 객체 읽기 |
| 지도 객체 | `cloudfront.amazonaws.com` | 해당 배포 ARN, `20260907.pmtiles` 읽기만 허용 |
| 로그 객체 쓰기 | `delivery.logs.amazonaws.com` | 서비스 계정·로그 전달 소스 ARN·`AWSLogs/565725315772/CloudFront/*` |

오리진·로그 버킷 정책은 이 모듈에서 관리합니다. 기존 지도 버킷의 생성·버전·수명 주기는 관리하지 않습니다.

CloudFront 접근 로그: `us-east-1`의 전달 소스·대상·연결 → S3 JSON, 객체 보존 30일. 로그 전달 연결은 버킷 정책 적용 완료에 의존합니다.

WAF 요청 로그: `us-east-1`의 CloudWatch Logs에 14일 보존, `authorization`·`cookie`·`proxy-authorization` 헤더 값 가림.

## 적용·캐시 갱신

```bash
cd /root/protomaps
terraform -chdir=terraform/env/web plan -out=web.tfplan
terraform -chdir=terraform/env/web apply web.tfplan
terraform -chdir=terraform/env/web output cloudfront
```

웹 자산·HTML 업로드 후:

```bash
arcamap_distribution_id="$(terraform -chdir=terraform/env/web output -json cloudfront | jq -r '.id')"
aws cloudfront create-invalidation \
  --distribution-id "$arcamap_distribution_id" --paths '/' '/index.html'
```

## 출력·정상 기준

| `cloudfront` 출력 | 사용 |
|---|---|
| `id` / `arn` | 배포 조회·캐시 갱신 / 정책의 배포 범위 |
| `domain_name` / `hosted_zone_id` | Route 53 A·AAAA 별칭 |

```bash
curl -sS -I --max-time 15 https://arcamap.app/
curl -sS --max-time 15 --range 0-126 \
  -D - -o /dev/null https://arcamap.app/20260907.pmtiles
```

| 항목 | 정상 기준 |
|---|---|
| 웹 | HTTP 200, HTML 응답 |
| PMTiles | HTTP 206, `Content-Range: bytes 0-126/전체크기` |
| 배포 상태 | `Deployed` |
| 무효화 상태 | `Completed` |

지도 403·404 발생 시 객체 키·경로 동작·배포 ARN·객체 읽기 범위를 확인합니다. 지도 객체 키 변경 시 CloudFront 경로·S3 정책·웹 빌드 URL을 함께 변경합니다.
