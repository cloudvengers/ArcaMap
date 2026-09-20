# Web Infrastructure Tests(웹 인프라 구성 테스트)

**🧪 정적 콘텐츠 제공을 담당하는 web 루트의 Terraform 테스트 영역**

WEB 루트는 S3 오리진과 CloudFront를 연결합니다. 웹 DNS와 콘텐츠 보존 방식도 이 루트에서 설정합니다. 이 폴더에는 해당 루트의 모듈 단위 테스트 정의를 둡니다.

## 1. Test Composition(테스트 구성)

| 정의 | 구분 |
|---|---|
| `modules_unit_test.tftest.hcl` | web 루트의 모듈 단위 테스트 |

## 2. Infrastructure Context(대상 인프라 구성)

- 📦 **콘텐츠 저장** — 정적 파일·사진·로그 버킷을 구분하고 기존 지도 버킷을 사용합니다.

- ⚡ **콘텐츠 제공** — CloudFront는 S3 오리진에서 가져온 콘텐츠를 캐시합니다.

- 🔑 **접근 통제** — OAC와 버킷 정책으로 오리진 접근을 제한합니다.

- 🌐 **도메인 연결** — 웹 도메인의 DNS 레코드를 CloudFront에 연결합니다.

콘텐츠 종류에 따라 저장·보존·캐시 방식을 다르게 설정합니다. 브라우저는 CloudFront에서 콘텐츠를 받습니다.
