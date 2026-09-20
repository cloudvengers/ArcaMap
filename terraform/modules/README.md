# Infrastructure Modules(인프라 하위 모듈)

**🧩 네트워크·컴퓨팅·스토리지·모니터링을 역할별로 구성하는 모듈**

각 모듈은 인프라에서 한 가지 역할을 맡습니다. 루트 모듈은 필요한 모듈을 조합해 서비스 환경을 만듭니다. 네트워크 경로와 접근 통제, API 실행과 요청 분산, 로그 보존과 경보 판정을 각각 구분합니다.

## 1. Module Composition(모듈 구성)

| 영역 | 모듈 | 주요 역할 |
|---|---|---|
| 네트워크 | **network** | VPC·서브넷·라우팅·IGW·NAT |
| 접근 통제 | **security** | ALB·API·DB 보안 그룹 |
| 요청 분산 | **alb** | 로드 밸런서·리스너·대상 그룹 |
| API 실행 | **compute** | 시작 템플릿·ASG |
| 이미지 생성 | **image-builder** | 이미지 빌드·테스트·AMI |
| 데이터베이스 | **database** | RDS·DB 서브넷 그룹 |
| 객체 저장 | **s3-bucket** | S3·암호화·수명 주기 |
| 콘텐츠 제공 | **cloudfront** | CloudFront·OAC·WAF |
| 로그 관리 | **cloudwatch-log-group** | 로그 그룹·보존 기간 |
| 상태 감지 | **cloudwatch-alarm** | 지표 기반 경보 |

## 2. Component Relationships(구성 요소 간 관계)

- 🌐 **통신 기반** — network는 리소스 사이의 통신 경로를 정하고 security는 허용할 통신 범위를 정합니다.

- 🚀 **API 실행 환경** — compute는 image-builder의 AMI로 API 서버를 실행하고 alb는 실행 중인 서버로 요청을 전달합니다.

- 📦 **콘텐츠 전달** — s3-bucket이 객체를 저장하고 cloudfront가 오리진 접근 통제와 캐싱을 담당합니다.

- 📈 **운영 상태** — cloudwatch-log-group은 로그의 보존 기간을 정하고 cloudwatch-alarm은 지표에 따라 상태를 판정합니다.

## 3. Design Principles(설계 원칙)

**리소스의 역할에 따라 구성 범위를 나누고** 각 루트에서 필요한 모듈을 연결합니다. 로그 그룹·경보·S3처럼 여러 관리 영역에서 사용하는 리소스는 같은 역할의 모듈을 사용합니다.
