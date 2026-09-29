# API 실행 구성

**API 요청을 처리하고 AMI로 서버를 배포하는 실행 환경**

ALB가 HTTPS 요청을 받아 프라이빗 서브넷의 API 서버로 전달합니다. EC2 Image Builder가 애플리케이션을 포함한 AMI를 생성하며 Auto Scaling Group은 인스턴스 수를 조절하고 인스턴스를 교체합니다.

## 1. System Architecture(시스템 구성)

| 요청 진입 | API 포트 | 인스턴스 범위 | CPU 확장 목표 |
|:---:|:---:|:---:|:---:|
| HTTPS 443 | HTTP 8080 | 2~4대 | 50% |

- **요청 분산** — 퍼블릭 서브넷의 ALB가 두 가용 영역에 배치한 API 인스턴스로 요청을 전달합니다.

- **인증정보** — API 서비스가 시작할 때 지정된 Secrets Manager Secret에서 RDS 접속 정보를 가져옵니다.

- **역할 분리** — 운영 인스턴스와 이미지 빌드 인스턴스의 IAM 역할을 구분합니다. 이미지 빌드에 필요한 배포 객체 읽기 권한은 별도로 부여합니다.

- **운영 상태** — CloudWatch 로그와 ASG·EC2·ALB 지표 기반 경보로 상태를 파악합니다.

## 2. Request Flow(요청 처리 흐름)

1. 클라이언트가 API 도메인을 통해 ALB에 HTTPS 요청을 보냅니다.
2. ALB가 TLS 연결을 종료하고 대상 그룹의 API 서버에 HTTP 8080으로 전달합니다.
3. API 서버가 필요한 데이터를 RDS PostgreSQL에서 조회합니다.
4. API 서버의 응답이 ALB를 거쳐 클라이언트로 반환됩니다.

## 3. Deployment Flow(배포 흐름)

1. API 배포 아카이브를 배포용 S3 버킷에 저장합니다.
2. EC2 Image Builder가 API와 의존성을 포함한 이미지를 빌드하고 테스트합니다.
3. 생성된 AMI가 시작 템플릿에 반영됩니다.
4. ASG Instance Refresh가 인스턴스를 교체합니다.

## 4. Operational Criteria and Constraints(운영 기준 및 제약)

- **장애 대응** — EC2 상태 검사와 ALB 헬스 체크를 통해 비정상 인스턴스에 대응합니다.

- **용량 조절** — 평균 CPU 50%를 목표로 API 인스턴스를 2~4대 범위에서 조절합니다.

- **관리 접속** — SSH 포트 개방 없이 Session Manager를 사용합니다.

### 제약 조건

> **교체 정책**: Instance Refresh가 최소 정상 비율 100%, 최대 용량 비율 200%로 새 서버를 먼저 준비한 뒤 기존 서버를 종료하도록 구성했습니다. AWS 적용 및 무중단 검증은 아직 수행하지 않았습니다.
>
> **알림 제약**: CloudWatch 경보가 운영자에게 알림을 보내도록 설정하지는 않았습니다.

## 코드 위치

| 파일 | 역할 |
|---|---|
| [data.tf](data.tf) | 공통 네트워크·RDS·ACM 인증서 조회 |
| [main.tf](main.tf) | API EC2·Auto Scaling 모듈 연결 |
| [alb.tf](alb.tf) | ALB·API WAF 모듈 연결 |
| [dns.tf](dns.tf) | API 도메인의 ALB 별칭 레코드 |
| [image-builder.tf](image-builder.tf) | API AMI 빌드 입력 연결 |
| [deployment.tf](deployment.tf) | 배포 S3 객체와 DB 접속 정보 Secret |
| [iam.tf](iam.tf) | 운영·빌드 EC2 역할과 권한 |
| [monitoring.tf](monitoring.tf) | Agent·로그 그룹·서비스 경보 |
| [tests/dependencies_unit_test.tftest.hcl](tests/dependencies_unit_test.tftest.hcl) | AWS 호출 없이 배포 의존성을 검사하는 모의 테스트 |
