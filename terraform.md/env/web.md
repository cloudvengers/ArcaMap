# WEB 인프라 적용

## 주요 개념

| 용어 | 개념 | 적용 |
|---|---|---|
| 오리진 | CloudFront가 원본 객체를 가져오는 대상 | 정적·지도·사진 S3 |
| OAC | CloudFront의 S3 요청 서명 | 배포 ARN으로 객체 읽기 제한 |
| 캐시 TTL | 객체의 캐시 유지 시간 | 웹 300초, 지도·사진 86400초 |
| DNS 별칭 | AWS 자원으로 연결하는 Route 53 레코드 | 웹 도메인 → CloudFront |
| 무효화 | 지정 경로의 CloudFront 캐시 제거 | 웹 배포 후 HTML 갱신 |
| WAF Web ACL | 웹 요청 검사 규칙 묶음 | 기존 CloudFront WAF를 Terraform으로 관리 |
| `import` | 기존 AWS 자원을 Terraform 상태에 등록 | WAF·로그 그룹·로그 설정 3개 |

## 현재 구성·입력

| 항목 | 값 |
|---|---|
| 실행 위치 | `/root/protomaps/terraform/env/web` |
| Terraform / AWS Provider | `1.16.1` / `6.63.0` |
| 서비스 리전 / State | `ap-northeast-2` / 루트의 `terraform.tfstate` |
| 인증서·CloudFront 로그 전달·WAF 리전 | `us-east-1` |
| `frontend_domain_name` | `arcamap.app` |
| `frontend_cache_ttl_seconds` | 300초 |
| `media_cache_ttl_seconds` | 86400초 |
| `cloudfront_price_class` | `PriceClass_200` |
| `log_retention_days` | CloudFront 접근 로그 S3 보존 30일 |
| WAF 로그 보존 | CloudWatch Logs 14일, `waf.tf`에 별도 지정 |
| `photo_noncurrent_retention_days` | 7일 |
| `route53_role_arn` | `arn:aws:iam::438465145630:role/Route53` |
| `route53_zone_id` | `Z05495112R0T3ZW9NIKIZ` |

## 기존 자원·관리 범위

| 대상 | 처리 |
|---|---|
| 지도 버킷 | `protomaps-565725315772-ap-northeast-2-an` 조회 |
| 지도 객체 | 기존 `20260907.pmtiles` 사용 |
| 웹 인증서 | `us-east-1`, `arcamap.app`, `ISSUED`, 일치 인증서 조회 |
| 신규 버킷 | `static`, `photos`, `cloudfront_logs` |
| S3 정책 | CloudFront 모듈에서 오리진·로그 버킷 정책 관리 |
| 웹 DNS | DNS 계정 역할로 A·AAAA 별칭 생성, CloudFront 연결 |
| DNS 옵션 | `evaluate_target_health=false`, `allow_overwrite=false` |
| 기존 WAF | `CreatedByCloudFront-609132c8`, 규칙 그룹 4개의 Count 설정 유지 |
| WAF 로그 | 로그 그룹·로그 설정을 함께 가져와 web state에서 관리 |

app·db·was와 독립 적용. 기존 지도 버킷은 조회만 하며, 해당 버킷의 CloudFront 읽기 정책은 web state에서 관리합니다.

2026-09-15에 기존 WAF·로그 그룹·로그 설정 3개를 가져왔으며, 규칙과 로그 설정을 유지했습니다.

## 요청 경로

| 요청 | 대상 | 설정 |
|---|---|---|
| `/`·정적 자산 | 정적 S3 | 기본 객체 `index.html` |
| `/20260907.pmtiles` | 지도 S3 | 지정 객체만 읽기, 압축 비활성화 |
| `/photos/*` | 사진 S3 | 이전 객체 버전 7일 보존, 앱의 사진 CSV 미사용 |
| `https://api.arcamap.app/api/*` | 별도 ALB | 브라우저가 API 도메인으로 직접 요청 |

CloudFront: GET·HEAD 허용, HTTP→HTTPS 전환, IPv6 활성화. ALB 오리진·API 전달 동작은 없습니다.

## 적용 절차

### 1. CloudFront·S3·DNS 적용

```bash
cd /root/protomaps
terraform -chdir=terraform/env/web init -lockfile=readonly
terraform -chdir=terraform/env/web plan -out=web.tfplan
terraform -chdir=terraform/env/web apply web.tfplan
terraform -chdir=terraform/env/web output
```

### 2. 운영 빌드·업로드

```bash
npm --prefix web ci
VITE_API_BASE_URL=https://api.arcamap.app \
VITE_PMTILES_URL=https://arcamap.app/20260907.pmtiles \
  npm --prefix web run build

arcamap_static_bucket="$(terraform -chdir=terraform/env/web output -json s3_buckets | jq -r '.static')"
aws s3 sync web/dist/ "s3://$arcamap_static_bucket/" \
  --region ap-northeast-2 --exclude index.html
aws s3 cp web/dist/index.html "s3://$arcamap_static_bucket/index.html" \
  --region ap-northeast-2 --content-type text/html --cache-control no-cache
```

URL은 빌드 시 번들에 포함됩니다. 자산을 먼저 올리고 HTML을 마지막에 교체하며, 이전 HTML이 사용하는 해시 자산은 유지합니다.

### 3. HTML 캐시 갱신

```bash
arcamap_distribution_id="$(terraform -chdir=terraform/env/web output -json cloudfront | jq -r '.id')"
aws cloudfront create-invalidation \
  --distribution-id "$arcamap_distribution_id" --paths '/' '/index.html'
```

## 출력·정상 기준

| 출력 | 내용 |
|---|---|
| `cloudfront` | 배포 ID·ARN·도메인·호스팅 영역 ID |
| `frontend_url` | `https://arcamap.app` |
| `s3_buckets` | 정적·사진·로그 버킷 이름 |

```bash
curl -sS -I --max-time 15 https://arcamap.app/
curl -sS --max-time 15 --range 0-126 \
  -D - -o /dev/null https://arcamap.app/20260907.pmtiles
```

| 항목 | 정상 기준 |
|---|---|
| 웹 | HTTP 200, HTML 응답 |
| 지도 | HTTP 206, `Content-Range: bytes 0-126/전체크기` |
| 캐시 갱신 | 무효화 상태 `Completed` |
| API 연동 | API HTTP 200, CORS 허용 출처 `https://arcamap.app` |
| WAF | CloudFront의 `web_acl_id`와 관리 중인 Web ACL ARN 일치 |
| Terraform 구성 일치 | `plan -detailed-exitcode`의 종료 코드 0, `No changes` |
