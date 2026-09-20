# API Infrastructure Tests(API 인프라 구성 테스트)

**🧪 API 실행 환경과 AMI 구성을 담당하는 was 루트의 Terraform 테스트 영역**

WAS 루트는 로드 밸런서·API 인스턴스·이미지 빌드를 연결하고 IAM·로그·경보를 구성합니다. 이 폴더에는 모듈 단위 테스트와 AMI 리전 관련 테스트 정의를 둡니다.

## 1. Test Composition(테스트 구성)

| 정의 | 구분 |
|---|---|
| `modules_unit_test.tftest.hcl` | was 루트의 모듈 단위 테스트 |
| `ami_region_unit_test.tftest.hcl` | AMI 리전 관련 단위 테스트 |

## 2. Infrastructure Context(대상 인프라 구성)

- 🌐 **요청 전달** — ALB와 대상 그룹이 API 인스턴스로 요청을 전달합니다.

- 📦 **이미지 연결** — Image Builder가 생성한 AMI를 시작 템플릿과 연결합니다.

- ⚙️ **서버 운영** — Auto Scaling Group이 API 인스턴스 수를 조절하고 인스턴스를 교체합니다.

- 🔑 **접근 권한** — 운영·빌드 역할을 나누고 각 역할에 필요한 리소스 접근 권한을 부여합니다.

이미지 생성과 API 인스턴스 운영은 **별개의 역할이며 AMI로 연결됩니다**. 인스턴스는 해당 리전에서 사용할 이미지로 생성합니다.
