# AMI 관리

`image-builder` 모듈은 API용 AMI를 관리하는 EC2 Image Builder 파이프라인과 수명 주기 정책을 구성합니다. [API 환경](../../env/api/README.md)에서 사용합니다.

## 파이프라인과 인스턴스

| 항목 | 설정 |
|---|---|
| 파이프라인·레시피 이름 | `arcamap-api` |
| 레시피 버전 | `image_builder_version` |
| 기반 AMI | Canonical의 최신 Ubuntu Server 26.04, `x86_64` |
| 실행 방식 | 수동 |
| 배치 위치 | 입력한 사설 서브넷 1개 |
| 보안 그룹 | 입력한 Image Builder 전용 보안 그룹 |
| 인스턴스 유형 | `image_builder_instance_type` |
| 루트 볼륨 | 암호화한 `gp3`, 최소 20GiB, 인스턴스 종료 시 삭제 |
| 인스턴스 메타데이터 | IMDSv2 필수, 응답 홉 제한 1 |
| 실패한 작업의 인스턴스 | 종료 |

인스턴스는 입력한 IAM 인스턴스 프로파일을 사용합니다. 파이프라인의 로그는 `imagebuilder_log_group_name`으로 지정한 CloudWatch 로그 그룹에 전달합니다.

## AMI 수명 주기

수명 주기 정책은 `arcamap-api` 레시피의 AMI와 연결된 스냅샷을 관리합니다. 생성 후 7일이 지난 이미지를 삭제 대상으로 지정하고, `ArcaMapProtected=true` 태그가 있는 이미지는 보존합니다.

정책 실행 역할은 `arcamap-imagebuilder-lifecycle`입니다. 이 역할에 `EC2ImageBuilderLifecycleExecutionPolicy`를 연결합니다.

## 입력과 출력

[variables.tf](variables.tf)에 서브넷, 보안 그룹, IAM 인스턴스 프로파일, 인스턴스 유형, 볼륨 크기, 레시피 버전과 로그 그룹을 정의합니다.

`pipeline` 출력은 다음 값을 반환합니다.

| 필드 | 내용 |
|---|---|
| `arn` | 파이프라인 ARN |
| `recipe_arn` | 이미지 레시피 ARN |
| `lifecycle_policy_arn` | 수명 주기 정책 ARN |
| `build_tags` | 이미지 보호 태그와 환경 설정 해시 태그 |
| `validation_tags` | 이미지 선택에 사용하는 검증 태그 |

출력 구조는 [outputs.tf](outputs.tf)에 정의합니다.
