# Application Network Tests(공통 네트워크 구성 테스트)

**🧪 공통 네트워크와 보안 그룹을 담당하는 app 루트의 Terraform 테스트 영역**

app은 네트워크와 보안 그룹 모듈을 연결해 API·DB가 함께 사용할 기반을 만듭니다. 이 폴더에는 해당 루트의 모듈 단위 테스트 정의를 둡니다.

## 1. Test Composition(테스트 구성)

| 정의 | 구분 |
|---|---|
| `modules_unit_test.tftest.hcl` | app 루트의 모듈 단위 테스트 |

## 2. Infrastructure Context(대상 인프라 구성)

- 🌐 **네트워크 기반** — VPC·서브넷·라우팅으로 리소스를 배치할 위치와 통신 경로를 정합니다.

- 🔑 **접근 통제** — ALB·API·DB 보안 그룹으로 계층 간 통신을 제한합니다.

네트워크와 보안 그룹은 같은 VPC 안에서 연결됩니다. db·was는 이 인프라를 함께 사용합니다.
