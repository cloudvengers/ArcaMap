# Terraform Infrastructure(Terraform 인프라 구성)

**🏗️ ArcaMap의 네트워크·데이터 저장·API·콘텐츠 제공을 구성하는 AWS 인프라**

인프라는 관리 대상별로 루트 모듈을 나누고 각 역할은 하위 모듈로 구현합니다. 네트워크와 접근 통제는 공통 기반으로 두고 데이터베이스·API 서버·정적 콘텐츠는 따로 관리합니다.

## 1. Infrastructure Composition(인프라 구성)

| 공통 기반 | 데이터 저장 | API 처리 | 정적 콘텐츠 |
|:---:|:---:|:---:|:---:|
| **app** | **db** | **was** | **web** |

- 🌐 **공통 기반** — VPC·서브넷·라우팅으로 리소스를 배치하고 보안 그룹으로 통신 범위를 정합니다.

- 💾 **데이터 저장** — RDS PostgreSQL을 프라이빗 서브넷에 배치하고 로그·경보를 통해 데이터베이스 상태를 파악합니다.

- 🚀 **API 처리** — ALB가 요청을 API 서버로 전달합니다. 인스턴스는 AMI로 생성하고 오토 스케일링으로 수를 조절합니다.

- 📦 **정적 콘텐츠** — S3에 저장한 웹·지도·사진 콘텐츠를 CloudFront로 제공하고 OAC와 버킷 정책으로 오리진 접근을 제한합니다.

## 2. Component Relationships(구성 요소 간 관계)

### API 처리 경로

1. **ALB**가 클라이언트의 HTTPS 요청을 받습니다.
2. 대상 그룹의 **API 서버**로 요청을 전달합니다.
3. 데이터 조회가 필요한 경우 API 서버가 **RDS PostgreSQL**에 연결합니다.
4. 처리 결과가 API 서버와 ALB를 거쳐 클라이언트로 반환됩니다.

### 정적 콘텐츠 제공 경로

1. **CloudFront**에 연결된 WAF가 콘텐츠 요청을 검사합니다.
2. 유효한 캐시가 있으면 CloudFront가 바로 응답합니다.
3. 캐시 미스가 발생하면 **OAC로 서명한 요청**으로 S3 오리진의 콘텐츠를 가져옵니다.

## 3. Design Principles(설계 원칙)

| 원칙 | 구성에 반영한 방식 |
|---|---|
| **역할 분리** | 네트워크·DB·API·웹 콘텐츠의 관리 범위를 루트 모듈로 구분합니다. |
| **접근 통제** | 보안 그룹과 IAM 권한으로 통신·리소스 접근 범위를 제한합니다. |
| **가용성** | 두 가용 영역에 주요 리소스를 배치하고 장애에 대응할 기능을 갖춥니다. |
| **운영 가시성** | 로그와 지표 기반 경보로 리소스 상태를 파악합니다. |

## 4. Terraform Configuration(Terraform 구성)

```text
terraform/
├── env/                         # 관리 대상별 루트 모듈
│   ├── app/                     # 공통 네트워크·보안 그룹
│   ├── db/                      # RDS·데이터베이스 로그·경보
│   ├── was/                     # API 서버·AMI 배포·IAM·ALB
│   └── web/                     # 정적 콘텐츠·CDN·웹 DNS
└── modules/                     # 역할별 하위 모듈
    ├── network/                 # VPC·서브넷·라우팅·IGW·NAT
    ├── security/                # ALB·API·DB 보안 그룹
    ├── alb/                     # 로드 밸런서·리스너·대상 그룹
    ├── compute/                 # 시작 템플릿·ASG
    ├── database/                # RDS·DB 서브넷 그룹
    ├── image-builder/           # 이미지 빌드·테스트·AMI 생성
    ├── s3-bucket/               # S3 버킷·암호화·수명 주기
    ├── cloudfront/              # CloudFront·OAC·WAF
    ├── cloudwatch-log-group/    # 로그 그룹·보존 기간
    └── cloudwatch-alarm/        # 지표 기반 경보
```
