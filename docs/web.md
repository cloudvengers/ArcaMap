# WEB 배포

## 주요 개념

| 용어 | 개념 | 적용 |
|---|---|---|
| 정적 빌드 | 브라우저가 실행할 HTML·CSS·JavaScript 생성 | Vite → `web/dist/` |
| 오리진 | CloudFront가 원본 객체를 가져오는 대상 | 정적·사진·지도 S3 |
| OAC | CloudFront의 S3 요청을 서명하는 접근 제어 | 배포 ARN으로 S3 읽기 제한 |
| 캐시 TTL | 캐시 객체를 유지하는 시간 | 웹 최대 300초, 지도·사진 최대 86400초 |
| 무효화 | 지정 경로의 기존 CloudFront 캐시 제거 | 배포 후 `/`·`/index.html` |
| Range GET | 객체 전체 중 지정한 바이트 구간만 요청 | PMTiles 지도 타일 읽기 |
| CORS | 브라우저의 다른 출처 응답 읽기를 허용하는 규칙 | 웹 → 별도 API 도메인 |

## 요청 경로

| 요청 | 대상 | 설정 |
|---|---|---|
| `https://arcamap.app/` | CloudFront → 정적 S3 | 기본 객체 `index.html` |
| `/20260907.pmtiles` | CloudFront → 기존 지도 S3 | 단일 객체 읽기, 압축 비활성화 |
| `/photos/*` | CloudFront → 사진 S3 | 경로 구성, 현재 앱에서 사진 CSV 미사용 |
| `https://api.arcamap.app/api/*` | ALB → WAS | CloudFront를 경유하지 않는 API 요청 |
| 글꼴·스프라이트 | `protomaps.github.io/basemaps-assets/` | 외부 자산 요청 |
| MapLibre worker | 정적 S3의 `/assets/` | 빌드에서 별도 worker 파일 생성 |

| CloudFront 설정 | 값 |
|---|---|
| 허용 메서드 | GET·HEAD |
| HTTP 요청 | HTTPS로 리다이렉트 |
| 웹 캐시 | 최소 0초, 기본·최대 300초, gzip·Brotli 사용 |
| 지도·사진 캐시 | 최소 0초, 기본·최대 86400초, 압축 비활성화 |
| 캐시 키 | 쿠키·쿼리 문자열·추가 헤더 미포함 |
| S3 접근 | Block Public Access, BucketOwnerEnforced, SSE-S3 |
| 지도 권한 | 해당 CloudFront 배포의 `20260907.pmtiles` 읽기만 허용 |
| 인증서·DNS | us-east-1 ACM, Route 53 A·AAAA 별칭 |

## 빌드 입력

| 환경 변수 | 운영 값 | 반영 시점 |
|---|---|---|
| `VITE_API_BASE_URL` | `https://api.arcamap.app` | 빌드 시 |
| `VITE_PMTILES_URL` | `https://arcamap.app/20260907.pmtiles` | 빌드 시 |

- `VITE_*`: 브라우저 번들에 포함되는 공개 설정
- URL 변경: 재빌드·재배포 필요
- Vite 개발 프록시: 정적 배포에 미포함
- 운영 지도: 고정 CloudFront URL 사용

## 배포 절차

작업 위치: `/root/protomaps`

### 1. CloudFront·S3 적용

전제: 기존 지도 버킷·웹 인증서·DNS 역할 준비, `terraform/env/web/terraform.tfvars` 입력.

```bash
terraform -chdir=terraform/env/web init -lockfile=readonly
terraform -chdir=terraform/env/web plan -out=web.tfplan
terraform -chdir=terraform/env/web apply web.tfplan
terraform -chdir=terraform/env/web output
```

### 2. 운영용 빌드

```bash
npm --prefix web ci
VITE_API_BASE_URL=https://api.arcamap.app \
VITE_PMTILES_URL=https://arcamap.app/20260907.pmtiles \
  npm --prefix web run build

```

판정: 빌드 성공, HTML·CSS·JS·worker 파일 생성, 두 운영 URL 반영.

### 3. S3 업로드

```bash
arcamap_static_bucket="$(terraform -chdir=terraform/env/web output -json s3_buckets | jq -r '.static')"

aws s3 sync web/dist/ "s3://$arcamap_static_bucket/" \
  --region ap-northeast-2 --exclude index.html
aws s3 cp web/dist/index.html "s3://$arcamap_static_bucket/index.html" \
  --region ap-northeast-2 --content-type text/html --cache-control no-cache
```

- 업로드 순서: 자산 → HTML
- 기존 해시 자산: 유지; 캐시에 남은 이전 HTML의 파일 참조 보호
- 정적 버킷: 버전 관리 미설정; 이전 배포 복구에 이전 `dist/` 필요

### 4. HTML 캐시 갱신

```bash
arcamap_distribution_id="$(terraform -chdir=terraform/env/web output -json cloudfront | jq -r '.id')"
aws cloudfront create-invalidation \
  --distribution-id "$arcamap_distribution_id" \
  --paths '/' '/index.html'
```

판정: 반환된 무효화 작업의 상태 `Completed`.

## 배포 확인

```bash
curl -sS -I --max-time 15 https://arcamap.app/
curl -sS --max-time 15 --range 0-126 \
  -D - -o /dev/null https://arcamap.app/20260907.pmtiles
curl -sS -i --max-time 15 \
  -H 'Origin: https://arcamap.app' https://api.arcamap.app/api/places
```

| 점검 | 정상 기준 |
|---|---|
| 웹 | HTTP 200, `Content-Type: text/html` |
| PMTiles | HTTP 206, `Content-Range: bytes 0-126/전체크기` |
| API CORS | HTTP 200, `Access-Control-Allow-Origin: https://arcamap.app` |
| 브라우저 | 지도·목록·검색·필터·상세 표시 |
| 자산 | worker·글꼴·스프라이트 요청 성공 |

## 실패 시 점검

| 증상 | 점검 대상 |
|---|---|
| 웹 403 | 정적 객체, OAC, 버킷 정책의 배포 ARN |
| 지도 403·404 | 객체 키, `/20260907.pmtiles` 캐시 동작, 해당 객체의 읽기 정책 |
| 지도 Range 실패 | 206 응답·Content-Range·중간 압축 여부 |
| 이전 화면 유지 | HTML 캐시·무효화 상태·실제 업로드 버킷 |
| worker 404 | `dist/assets/` 전체 업로드 여부 |
| API만 실패 | 빌드의 API URL·CORS·ALB·WAS 상태 |
