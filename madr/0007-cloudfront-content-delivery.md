# CloudFront 콘텐츠 제공 — HTML·해시 자산 캐시 분리와 사용자 정의 보안 응답 헤더 적용

## 배경과 문제

### 배경

- 현재 AWS에 서비스 인프라는 배포되어 있지 않으며, 단일 구성 운영 기반으로 재구성합니다.
- 웹·사진·지도는 S3 오리진과 CloudFront로 제공하고, API 요청은 별도 ALB로 전달합니다. 이번 CloudFront 변경은 콘텐츠 캐시와 브라우저 보안 응답 헤더를 대상으로 합니다.
- 캐시를 활용해 응답 지연·원본 조회·반복 전송을 줄이면서 웹 배포의 갱신을 보장하고, 현재 웹 기능에 맞는 브라우저 보안 정책을 적용합니다.

### 문제

- 기존 웹 캐시 정책은 HTML과 JS·CSS를 구분하지 않고 캐시 유효시간인 TTL을 최소 0초, 기본·최대 300초로 적용합니다. 내용이 바뀌면 파일명도 바뀌는 해시 자산까지 짧게 캐시합니다.
- 기존 웹 빌드의 JS·CSS·아이콘·지도 워커는 `/assets/` 아래에 해시 파일명으로 생성됩니다. HTML은 동일한 `index.html` 경로에서 새 파일명을 참조하므로 두 종류의 갱신 특성이 다릅니다.
- 현재 CloudFront 캐시 동작에는 응답 헤더 정책이 연결되어 있지 않습니다. WAF의 요청 검사와 별개로 브라우저에 적용할 HTTPS 접속·프레임 삽입·리소스 로딩 정책이 필요합니다.
- 웹은 `https://api.arcamap.app`을 호출하며 지도 폰트·스프라이트는 `https://protomaps.github.io/basemaps-assets/`에서 가져옵니다. 콘텐츠 보안 정책인 CSP가 이 경로와 동일 출처 지도 워커를 허용해야 정상 기능을 유지할 수 있습니다.

## 검토한 대안

- **기존 웹 캐시 300초와 응답 헤더 미설정 유지:** 변경량은 적지만 해시 자산의 반복 조회를 줄일 여지가 남고, 브라우저 보안 정책을 적용하지 못합니다.
- **캐시 분리와 관리형 `SecurityHeadersPolicy` 적용:** HTML과 해시 자산을 다르게 캐시하고 관리형 보안 헤더를 활용합니다. 관리 부담은 적지만 해당 정책에는 CSP가 없고, 오리진에 `X-Frame-Options`가 없을 때 `SAMEORIGIN`을 추가합니다. CSP와 `DENY`를 응답 헤더 정책에서 직접 지정하려면 사용자 정의 정책이 필요합니다. [AWS 관리형 응답 헤더 정책](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-response-headers-policies.html)
- **캐시 분리와 사용자 정의 보안 응답 헤더 적용:** 갱신 특성별 캐시와 서비스별 CSP를 함께 구성합니다. 허용 리소스 주소를 관리해야 하지만 현재 웹 기능과 보안 요구에 맞춰 값을 정할 수 있습니다.

## 결정과 이유

**선택: HTML은 CloudFront 300초 캐시·브라우저 재검증, 해시 자산은 1년 캐시, 보안 헤더는 CSP를 포함한 사용자 정의 정책으로 구성**

- HTML의 기존 CloudFront 캐시 상한을 유지하면서, 내용 변경 시 새 URL을 사용하는 해시 자산만 장기 캐시합니다. AWS는 SPA의 HTML과 불변 자산을 구분하고 불변 자산에 1년 캐시를 적용하는 방식을 안내합니다. [AWS SPA 캐시 전략](https://repost.aws/knowledge-center/cloudfront-single-page-application), [AWS 계층별 TTL과 해시 자산](https://aws.amazon.com/blogs/networking-and-content-delivery/host-single-page-applications-spa-with-tiered-ttls-on-cloudfront-and-s3/)
- 브라우저의 HTML 재검증과 CloudFront의 300초 캐시를 구분해 웹 배포 갱신과 원본 조회 감소를 함께 고려합니다. 300초는 AWS가 지정한 필수값이 아니라 이 서비스의 기존 캐시 기준을 유지한 결정입니다.
- WAF는 들어오는 요청을 검사하고, 보안 응답 헤더는 브라우저의 응답 처리와 리소스 로딩을 제한합니다. 현재 API·지도 요청을 허용하는 CSP와 기본 보안 헤더를 하나의 사용자 정의 정책으로 적용합니다. [AWS 보안 응답 헤더 설정](https://aws.amazon.com/blogs/security/implementing-http-strict-transport-security-hsts-across-aws-services/), [MDN CSP](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Content-Security-Policy)

### 콘텐츠별 캐시 값

| 대상 | CloudFront 동작·오리진 | 최소 TTL | 기본 TTL | 최대 TTL | S3 객체의 `Cache-Control` |
| --- | --- | --- | --- | --- | --- |
| HTML·기본 웹 경로 | 기본 동작 → 웹 S3 | 0초 | 300초 | 300초 | `public, max-age=0, s-maxage=300, must-revalidate` |
| 해시 자산 `/assets/*` | 추가 동작 → 웹 S3 | 0초 | 31,536,000초 | 31,536,000초 | `public, max-age=31536000, immutable` |

- `max-age=0`은 브라우저가 HTML을 재사용하기 전에 재검증하도록 하고, `s-maxage=300`은 CloudFront가 HTML을 최대 300초 캐시하도록 합니다. 해시 자산의 31,536,000초는 365일입니다. S3 객체 메타데이터와 CloudFront 최대 TTL을 함께 설정해야 같은 기준이 적용됩니다. [AWS TTL과 `max-age`·`s-maxage` 관계](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/Expiration.html)
- 모든 `/assets/*` 파일은 내용을 바꾸면 파일명도 바뀌어야 합니다. 같은 해시 경로의 내용을 덮어쓰지 않습니다. 이 규칙을 JS·CSS·아이콘·지도 워커에 동일하게 적용합니다.
- `/assets/*`에도 기존 웹 동작처럼 GET·HEAD, HTTPS 리디렉션, gzip·Brotli 압축을 적용합니다. 쿠키·일반 헤더·쿼리 문자열을 캐시 키에서 제외하는 기존 정책을 유지하며, 압축에 필요한 `Accept-Encoding` 처리는 유지합니다.
- 사진 `/photos/*`와 지도 `/20260907.pmtiles`는 기존 최소 TTL 0초·기본 및 최대 TTL 86,400초와 압축 비활성화를 유지합니다. HTML·해시 자산용 객체 메타데이터를 사진·지도에 일괄 적용하지 않습니다.
- 장소 데이터는 별도 API에서 조회합니다.

### 웹 배포 갱신

- 새 해시 자산을 먼저 업로드하고, 해당 자산을 참조하는 `index.html`을 마지막에 업로드합니다. 각 객체에 위 표의 `Cache-Control`과 올바른 `Content-Type`을 설정합니다.
- HTML 업로드 후 `/`와 `/index.html`을 무효화하고 완료 상태를 기준으로 배포 완료를 판단합니다. 해시 자산은 새 파일명으로 갱신하므로 정기 배포에서 무효화하지 않습니다. [AWS 파일 무효화와 버전 파일명](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/Invalidation.html)
- 무효화가 완료되기 전에는 캐시된 이전 HTML이 제공될 수 있습니다. 브라우저 HTML은 재검증하고 CloudFront의 정상적인 신선도 상한은 300초로 둡니다.
- 배포 중 이전 HTML이 참조하는 해시 자산을 삭제하지 않고 기존 웹 S3의 객체 보존 구성을 유지합니다. 롤백 시 이전 HTML을 복원하고 같은 HTML 경로를 무효화합니다.

### 보안 응답 헤더 값

- 사용자 정의 응답 헤더 정책 하나를 생성해 기본 웹·해시 자산·사진·지도 캐시 동작에 연결합니다. 각 보안 헤더의 `override`는 `true`로 설정해 오리진의 같은 이름 헤더보다 이 정책을 적용합니다. [AWS 헤더 덮어쓰기 동작](https://aws.amazon.com/blogs/security/implementing-http-strict-transport-security-hsts-across-aws-services/)

| 헤더 | 값·설정 | 선택 이유 |
| --- | --- | --- |
| `Strict-Transport-Security` | `max-age=31536000`, `includeSubDomains=false`, `preload=false` | 브라우저가 이 헤더를 HTTPS로 수신한 뒤 1년간 해당 호스트에 HTTPS를 사용하도록 합니다. 현재 CloudFront 웹 호스트에 적용하고 다른 하위 도메인의 정책까지 강제하지 않습니다. |
| `X-Content-Type-Options` | `nosniff` | 브라우저가 응답 파일 형식을 임의로 추측하지 않도록 합니다. |
| `X-Frame-Options` | `DENY` | 독립 웹 화면을 다른 문서의 프레임에 삽입하지 못하도록 합니다. |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | 동일 출처에는 경로·쿼리를 포함한 참조 주소를, 다른 HTTPS 출처에는 출처만 전달합니다. HTTPS에서 HTTP로 이동할 때는 참조 주소를 전달하지 않습니다. |
| `Content-Security-Policy` | 아래 정책 | 현재 API·지도 리소스를 허용하고 스크립트·워커·프레임의 로딩 범위를 제한합니다. |

- HSTS 1년과 기본 보안 헤더의 동작은 AWS 문서를 근거로 선택했습니다. 프레임 정책은 이 서비스의 독립 화면 구성에 맞춰 `DENY`로 정합니다. [AWS HSTS 설정](https://aws.amazon.com/blogs/security/implementing-http-strict-transport-security-hsts-across-aws-services/), [AWS 보안 헤더 구성 항목](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-response-headers-policies.html)
- CSP는 다음 지시문을 공백으로 연결한 하나의 헤더 값으로 적용합니다.

```text
default-src 'self';
script-src 'self';
style-src 'self';
style-src-attr 'unsafe-inline';
img-src 'self' data: blob: https://protomaps.github.io/basemaps-assets/;
font-src 'self';
connect-src 'self' https://api.arcamap.app https://protomaps.github.io/basemaps-assets/;
worker-src 'self';
object-src 'none';
base-uri 'none';
frame-src 'none';
frame-ancestors 'none';
form-action 'self';
```

- `'self'`는 문서와 동일한 출처의 스크립트·워커를 허용합니다. 현재 스크립트와 지도 워커는 해당 출처의 `/assets/` 경로에서 제공합니다. MapLibre 공식 문서는 동일 출처에 워커를 배포하면 `worker-src`에 `blob:`을 추가할 필요가 없으며, 지도 이미지에는 `data:`·`blob:`을 허용하는 구성을 안내합니다. [MapLibre 워커·CSP 지침](https://maplibre.org/maplibre-gl-js/docs/guides/v5-to-v6-migration-guide/)
- 지도 폰트는 PBF 데이터를 가져오는 요청이므로 `connect-src`에서 지도 리소스 경로를 허용합니다. 스프라이트도 해당 경로의 연결·이미지 요청을 허용합니다. CSP에서 `/`로 끝나는 허용 경로는 해당 경로 아래의 리소스에 적용됩니다. [MDN CSP 출처·경로 규칙](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Content-Security-Policy)
- 동적 지도·UI 스타일과의 호환성을 위해 요소의 인라인 스타일 속성만 `style-src-attr 'unsafe-inline'`로 허용합니다. 스타일시트는 동일 출처로 제한하며, 인라인 스크립트와 문자열 코드 실행은 허용하지 않습니다. [MDN 스타일 속성 정책](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Content-Security-Policy/style-src-attr)

### 결과

- 이점: 해시 자산의 장기 캐시로 반복 전송과 원본 조회를 줄여 성능 효율성·비용 최적화·지속 가능성에 기여합니다.
- 이점: HTML 재검증과 제한된 무효화로 장기 캐시를 사용하는 자산의 새 버전을 배포할 수 있습니다.
- 이점: 현재 API·지도 기능을 허용하면서 HTTPS 접속, 파일 유형 처리, 프레임 삽입과 리소스 로딩에 브라우저 보안 정책을 적용합니다.
- 제약: 같은 해시 경로의 내용을 덮어쓰면 장기 캐시가 이전 내용을 계속 제공할 수 있으므로 파일명 변경 규칙을 지켜야 합니다.
- 제약: 이전 해시 자산을 보존하는 저장 비용과 HTML 무효화의 처리 시간·사용량에 따른 비용이 발생할 수 있습니다.
- 제약: CSP 허용 주소 밖의 새 외부 리소스는 차단되므로 리소스 구성 변경 시 정책을 함께 갱신해야 합니다.
- 제약: 요소의 인라인 스타일 속성을 허용하며, 이를 지정하는 `style-src-attr` 지시문은 브라우저의 CSP Level 3 지원이 필요합니다.
