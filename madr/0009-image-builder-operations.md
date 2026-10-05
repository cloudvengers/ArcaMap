# EC2 Image Builder 운영 — 빌드 보안그룹 분리·생성일 기준 AMI 7일 자동 정리

## 배경과 문제

### 배경

- 고가용성 인프라를 성능 효율성·지속 가능성·비용 최적화·보안을 고려한 단일 구성 운영 기반으로 재구성합니다.
- API는 프라이빗 서브넷에서 ASG 최소 1대·최대 2대로 운영합니다. Image Builder는 임시 EC2에서 API용 AMI를 빌드·테스트하며, 완성된 AMI를 시작 템플릿과 ASG Instance Refresh에 연결합니다.
- AMI는 EC2 인스턴스를 생성하는 데 사용하는 이미지입니다. 배포용 AMI와 구성 스냅샷은 Image Builder의 이미지 생성일 기준으로 7일이 지나면 자동 정리하며, 운영·교체·롤백에 필요한 이미지는 보호합니다.
- 변경 직전 운영 EC2와 연결된 EBS의 백업은 AWS Backup에서 7일 보존합니다. 기존 배포용 AMI와 스냅샷의 정리는 Image Builder에서 별도로 관리합니다.

### 문제

- 빌드 EC2가 운영 API 보안그룹을 공유하여 ALB에서 들어오는 TCP 8080 접근도 허용됩니다. 빌드·테스트에 필요한 통신을 별도로 제한해야 합니다.
- 현재 구성에는 배포용 AMI와 연결 스냅샷의 정리 기준이 없습니다. 운영·교체·롤백에 필요한 이미지를 보호하면서 사용이 끝난 이미지의 저장 비용을 제한해야 합니다.
- Image Builder의 `DeleteImage`는 빌드 기록에 해당하는 이미지 리소스를 삭제하며, 생성된 EC2 AMI는 삭제하지 않습니다. 보존·정리는 실제 AMI와 연결 스냅샷을 대상으로 구성해야 합니다. [AWS Image Builder 이미지 삭제 동작](https://docs.aws.amazon.com/imagebuilder/latest/APIReference/API_DeleteImage.html)

## 검토한 대안

| 대상 | 대안 | 이점 | 제약 |
| --- | --- | --- | --- |
| 빌드 접근 통제 | 운영 API 보안그룹 공유 | 별도 보안그룹 관리가 필요하지 않음 | 빌드 EC2에도 ALB의 TCP 8080 접근이 허용됨 |
| 빌드 접근 통제 | 빌드 전용 보안그룹 분리 | 빌드·테스트에 필요한 통신만 허용 | DSQL Endpoint의 허용 대상에 빌드 보안그룹을 추가해야 함 |
| 배포용 AMI 관리 | 보존·정리 정책 없이 유지 | 이전 이미지에 기간 제한 없이 접근 가능 | 불필요한 AMI와 스냅샷이 남을 수 있음 |
| 배포용 AMI 관리 | Image Builder 수명주기로 생성일 기준 7일 자동 정리 | 기본 기능으로 사용이 끝난 AMI와 스냅샷을 정리 | 운영·교체·롤백 이미지의 삭제 제외 태그를 관리해야 함 |

## 결정과 이유

**선택: 빌드 전용 보안그룹 분리와 Image Builder 수명주기를 통한 생성일 기준 AMI 7일 자동 정리**

### 빌드 전용 보안그룹

- 운영 API와 분리된 Image Builder 전용 보안그룹을 생성하고 빌드·테스트 EC2에 연결합니다.
- 인바운드 규칙은 두지 않습니다. API 시작·응답 검사는 테스트 EC2 자신에게 접속하는 루프백 주소 `127.0.0.1`로 수행합니다.
- 아웃바운드는 외부 빌드 의존성·AWS 서비스 접근용 TCP 443과 DSQL Endpoint 보안그룹 대상 TCP 5432를 허용합니다.
- DSQL Endpoint의 TCP 5432 인바운드 허용 대상에 빌드 보안그룹을 추가합니다. 운영 API 보안그룹의 접속 허용도 유지합니다.
- 빌드 EC2는 운영 가용 영역의 기존 API 프라이빗 서브넷에 배치하고, 외부 HTTPS 통신에는 NAT Gateway 1개를 사용합니다.
- 빌드에 필요하지 않은 인바운드 접근을 제거하여 통신 범위를 제한합니다. [AWS Image Builder 보안 지침](https://docs.aws.amazon.com/imagebuilder/latest/userguide/security-best-practices.html)

### 생성일 기준 AMI 자동 정리

- API용 Image Builder 이미지에 수명주기 정책을 적용합니다. 삭제 규칙은 `DELETE`, 기간 필터는 `AGE`, 단위는 `DAYS`, 값은 `7`로 설정하고 출력 AMI와 연결 스냅샷도 삭제 대상에 포함합니다. [AWS 이미지 수명주기 규칙](https://docs.aws.amazon.com/imagebuilder/latest/userguide/image-lifecycle-rules.html)
- 7일은 빌드 완료 시 설정되는 Image Builder 이미지 리소스의 생성 시점부터 계산합니다. 운영 업데이트 시점에 기산점을 다시 설정하지 않습니다. 생성 후 7일이 지난 이미지는 삭제 제외 조건이 해제되면 다음 정책 실행에서 정리 대상이 됩니다.
- 운영 ASG가 사용하는 AMI와 진행 중인 교체·롤백에 필요한 AMI는 해당 Image Builder 이미지 리소스에 보호 태그를 설정하고 `exclusionRules.tagMap`으로 제외합니다. 이 제외 규칙은 이미지 리소스와 출력 AMI·스냅샷을 함께 보호합니다. [AWS 이미지 보호 태그](https://docs.aws.amazon.com/imagebuilder/latest/userguide/image-lifecycle-rules.html)
- 배포 구성에서 사용·복구 참조 관계에 맞춰 보호 태그를 관리합니다. 새 운영 이미지와 교체·롤백에 필요한 이미지를 먼저 보호하고, 교체가 끝나 운영·복구에 더 이상 필요하지 않은 이미지의 보호를 해제합니다. Image Builder는 ASG·시작 템플릿의 의존성을 자동으로 판단하지 않습니다. [AWS 이미지 수명주기 관리 지침](https://docs.aws.amazon.com/imagebuilder/latest/userguide/manage-image-lifecycles.html)
- Image Builder 이미지 리소스는 수명주기 정책이 정리할 때까지 유지합니다. 배포 구성이 새 이미지로 바뀌어도 기존 이미지 리소스를 먼저 삭제하지 않도록 관리합니다.
- 정리 범위는 이 서비스의 Image Builder 배포 이미지와 구성 스냅샷입니다. AWS Backup이 관리하는 AMI·스냅샷은 해당 복구 지점의 보존·삭제 정책으로 관리합니다. 다른 AMI에서도 사용하는 스냅샷은 삭제 대상에서 제외합니다. [AWS AMI·스냅샷 삭제 조건](https://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_DeregisterImage.html)
- Image Builder 수명주기 정책은 하루 한 번 자동 실행됩니다. 생성 후 7일이 지나면 다음 실행에서 정리하며, 보호 중인 이미지는 7일이 지나도 유지합니다. [AWS 정책 실행 주기](https://docs.aws.amazon.com/imagebuilder/latest/userguide/manage-image-lifecycles.html)

### 빌드 적용 범위

- AMI 빌드 단계에 OS 보안 업데이트 기능을 추가하지 않습니다. [AWS Image Builder 패치 관리](https://docs.aws.amazon.com/imagebuilder/latest/userguide/security-patch-management.html)

### 결과

- 이점: 빌드 EC2의 통신을 운영 API와 분리하고 불필요한 인바운드 접근을 제거합니다.
- 이점: Image Builder 기본 수명주기 기능으로 생성 후 7일이 지난 미사용 AMI와 스냅샷을 자동 정리하여 저장 비용과 수동 정리 부담을 줄입니다.
- 제약: 빌드 보안그룹과 DSQL Endpoint의 허용 규칙을 함께 관리해야 합니다.
- 제약: 배포 구성에서 운영·교체·롤백 이미지의 보호 태그를 정확히 관리해야 합니다. 보호를 해제한 이미지가 생성 후 7일을 넘었다면 다음 정책 실행에서 삭제될 수 있습니다.
- 제약: 보존 중인 배포 AMI를 구성하는 EBS 스냅샷의 저장 비용을 부담합니다. AMI와 스냅샷이 정리된 뒤에는 해당 배포 이미지로 인스턴스를 생성할 수 없습니다.
