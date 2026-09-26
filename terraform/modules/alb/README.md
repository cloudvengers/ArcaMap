# Application Load Balancer(API 요청 분산)

**HTTPS 요청을 받아 API 서버로 전달하는 공개 진입점**

퍼블릭 서브넷의 Application Load Balancer가 클라이언트 연결을 받아 대상 그룹의 API 인스턴스로 요청을 나누어 보냅니다. ALB는 외부 HTTPS 연결을 종료한 뒤 내부 API 서버에 HTTP로 요청을 전달합니다.

## 1. Request Architecture(요청 전달 구성)

| 구성 요소 | 역할 |
|---|---|
| 로드 밸런서 | 두 가용 영역의 API 서버로 요청 분산 |
| 리스너 | 클라이언트 요청 수신과 전달 동작 |
| 대상 그룹 | API 인스턴스 연결과 헬스 체크 |
| ACM 인증서 | 클라이언트와 ALB 사이의 TLS 연결 |

## 2. Request Flow(요청 처리 흐름)

1. 클라이언트가 HTTPS 443으로 API 요청을 보냅니다.
2. ALB가 TLS 연결을 종료합니다.
3. 대상 그룹의 API 서버에 HTTP 8080으로 요청을 전달합니다.
4. API 응답을 클라이언트에 HTTPS로 반환합니다.

## 3. Availability and Access Control(가용성과 접근 통제)

- **상태 감지** — 대상 그룹의 헬스 체크로 API 인스턴스의 응답 상태를 파악합니다.

- **가용 영역 분산** — 두 가용 영역에 배치된 API 서버로 요청을 전달합니다.

- **통신 제한** — ALB와 API 보안 그룹 사이에는 필요한 포트만 허용해 서버가 직접 노출되는 범위를 줄입니다.
