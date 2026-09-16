# API 계약

기본 주소: `https://api.arcamap.app`

## 주요 개념

| 용어 | 의미 |
|---|---|
| 엔드포인트 | HTTP 메서드와 경로로 구분하는 기능 |
| 쿼리 매개변수 | URL의 `?` 뒤에 전달하는 검색·필터 조건 |
| 응답 계약 | 클라이언트와 서버가 공유하는 필드·자료형·오류 형식 |
| `null` | 값 없음. 숫자 0이나 빈 문자열과 구분 |
| CORS | 다른 출처의 응답을 브라우저에서 읽도록 허용하는 정책. API 인증과 별개 |

## 엔드포인트

| 메서드·경로 | 기능 | 성공 응답 |
|---|---|---|
| `GET /health` | API 응답 검사 | `{"status":"ok"}` |
| `GET /health/db` | DB 연결·`SELECT 1` 검사 | `{"status":"ok","database":"ok"}` |
| `GET /api/places` | 장소 목록·검색·필터 | `{"items":[],"total":0}` 형식 |
| `GET /api/places/{place_id}` | 장소 1건 | Place 객체 |
| `GET /api/filters` | 전체 필터 선택지 | 4종 코드 배열 |

제공 범위: 장소 조회. 등록·수정·삭제·보존목록 조회 API 없음.

## 목록·검색·필터

| 매개변수 | 조건 | 최대 길이 |
|---|---|---|
| `q` | name·address·location_info·description 중 하나에 문자열 포함, 대소문자 무시 | 256 |
| `category` | 분류 코드 일치 | 64 |
| `subcategory` | 세부 분류 코드 일치 | 64 |
| `preservation_type` | 보존 유형 배열의 원소 일치 | 64 |
| `grade` | 등급 일치 | 16 |

- 값: 매개변수별 단일 문자열, 앞뒤 공백 제거
- 미지정·빈 값: 해당 조건 없음
- 검색 필드 내부: OR, 서로 다른 매개변수: AND
- `%`, `_`, `\`: 검색어의 일반 문자
- 알 수 없는 필터 값: 결과 0건
- 정렬: `place_id` 오름차순, 페이지 분할 없음
- `total`: 반환된 `items` 길이
- 좌표 없는 장소: 목록·상세에 포함, 지도 마커에서 제외

```bash
curl -sS -G https://api.arcamap.app/api/places \
  --data-urlencode 'q=보존' \
  --data-urlencode 'grade=S+'
```

`S+`: URL 인코딩 필요. 위 명령은 `+`를 `%2B`로 전달.

## Place 응답

| 필드 | JSON 자료형 | 의미 |
|---|---|---|
| `place_id` | string | 장소 식별자 |
| `name` | string | 장소 이름 |
| `category` | string | 보존 기능 분류 |
| `domain` | string | 활동 영역 코드 |
| `subcategory` | string | 세부 분류 |
| `preservation_type` | string[] | 보존 자원·매체 유형 |
| `grade` | string 또는 null | 보존 가치 등급 |
| `latitude`, `longitude` | number 또는 null | 지구 WGS84 좌표 |
| `location_info` | string | 위치 설명 |
| `address` | string | 주소 |
| `description` | string | 보존 내용 |
| `website` | string | 출처·공식 웹 주소 원문 |

- 장소 ID: 1~128자, 정규식 `^[a-z0-9]+(_[a-z0-9]+)*$`
- 현재 CSV: 장소 50건·좌표 보유 45건, 등급 `S+`·`S`·`A+`·`A`
- 달 `moon_arch_lunar_library`: 등급 `A`, 위도·경도 모두 `null`
- 이미지 필드: 없음

## 필터 선택지

```json
{"category":[],"subcategory":[],"preservation_type":[],"grade":[]}
```

| 항목 | 규칙 |
|---|---|
| 조회 범위 | 현재 DB 전체, 선택 중인 필터와 독립 |
| 중복 | 제거 |
| 정렬 | 문자열 오름차순 |
| `preservation_type` | 배열 원소를 펼쳐 집계 |
| `grade` | NULL 제외 |

## 오류

| HTTP | 조건 | 응답 |
|---|---|---|
| 200 | 검색 결과 없음 | `{"items":[],"total":0}` |
| 404 | 형식은 유효하지만 없는 장소 ID | `{"detail":"Place not found"}` |
| 422 | 길이·ID 형식·NUL 문자 등 입력 오류 | FastAPI `detail` 배열 |
| 503 | DB 설정 누락·접속 실패·SQL 오류·시간 초과 | `{"detail":"Database unavailable"}` |

DB 오류 응답: 접속 정보·비밀번호·SQL 오류 원문 제외.

## 브라우저 접근

| 항목 | 정책 |
|---|---|
| 허용 출처 | `https://arcamap.app` |
| 허용 메서드 | GET |
| 사전 요청 | CORSMiddleware의 OPTIONS 처리 |
| CORS 자격 증명 | 미허용 |
| 다른 출처 | 응답 공유 허용 헤더 없음 |

## 확인

```bash
curl -sS -i https://api.arcamap.app/health/db
curl -sS https://api.arcamap.app/api/places | jq '{total, items: (.items | length)}'
curl -sS https://api.arcamap.app/api/places/moon_arch_lunar_library \
  | jq '{place_id, grade, latitude, longitude}'
curl -sS https://api.arcamap.app/api/filters | jq
```

판정: DB 상태 정상, `total`과 배열 길이 일치, 달의 등급 A·좌표 null, 4종 필터 배열.
