# 애플리케이션 코드 검토와 변경 사항

## 1. 코드 검토 결과

[API 코드](/root/protomaps/was/main.py)에서 다음 사항을 확인했습니다.

| 검토 대상 | 확인한 내용 |
|---|---|
| API 설명 페이지 | FastAPI의 기본 설명 페이지와 OpenAPI 제공이 활성화돼 있었음 |
| `/health/db` | 요청마다 DB에 연결하며, 이미지 생성 과정의 서버 내부 점검에서 사용 |
| 긴 한글 검색어 | API가 허용하는 검색어 길이가 WAF의 요청 크기 제한에 걸릴 가능성이 있음. 실제 차단 사례는 확인되지 않음 |

## 2. 변경 계획

API 설명 페이지와 OpenAPI 제공을 비활성화합니다.

`/health/db`는 서버 내부 점검에 계속 사용합니다. [이미지 생성 검사](../../modules/image-builder/api-components.tf)는 `http://127.0.0.1:8080/health/db`로 호출합니다. 외부 접근은 ALB의 WAF에서 차단하기로 했으며, 해당 규칙은 [WAF 변경 기록](waf-additional-decisions.md)에 기록합니다.

긴 한글 검색어는 배포 후 정상 검색이 차단되는지 확인한 다음 WAF 예외 설정 여부를 결정합니다.

## 3. 변경 후

| 대상 | 변경 내용 |
|---|---|
| API 설명 페이지 | FastAPI 생성 시 `openapi_url=None` 지정 |
| API 테스트 | `/docs`, `/redoc`, `/openapi.json`, `/docs/oauth2-redirect`의 404 확인 추가 |
| `/health/db` | 서버 내부 호출과 앱의 DB 점검 코드는 유지 |
| 긴 한글 검색어 | 검색어 길이 설정은 유지. 예외 필요성은 배포 후 검증 |

[API 테스트](/root/protomaps/was/test_backend.py)를 `.venv/bin/python test_backend.py`로 실행해 설명 페이지 404와 기존 API 테스트를 통과했습니다. DB 연결을 대체한 로컬 검사이며 실제 DB 연결 성공을 확인한 것은 아닙니다.

배포 후에는 다음 사항을 확인합니다.

1. API 설명 페이지와 OpenAPI 경로가 404를 반환하는지 확인합니다.
2. 서버 내부 `/health/db` 호출로 DB 점검이 성공하는지 확인합니다.
3. 긴 한글 검색어가 정상 처리되는지 확인하고, WAF가 정상 검색을 차단하면 해당 규칙의 예외 필요성을 검토합니다.
