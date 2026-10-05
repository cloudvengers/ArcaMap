# 백업 관리 — AWS Backup 온디맨드 백업·7일 보존과 공통 구성 분리

## 배경과 문제

### 배경

- 서비스 인프라는 미배포 상태이며, 단일 구성 운영에 맞춰 백업 관리 기준을 정합니다.
- 백업·복구와 관련된 정책이 데이터베이스, S3, EC2 Image Builder의 운영 기준에 나뉘어 있습니다. 백업을 만드는 시점, 보존기간, 관리 위치를 통일해야 합니다.
- 변경 직전 상태를 복구할 수 있고, 변경이 없으면 새 백업을 만들지 않고 불필요한 저장 비용을 줄입니다.

### 문제

- 운영 변경 직전 상태를 복구할 수 있어야 합니다. 대상별 최신 복구 지점 1개를 유지하고, 보존기간을 생성 시점부터 7일로 설정해야 합니다.
- AWS Backup의 보존기간 설정은 복구 지점의 만료를 관리합니다. 변경 직전 백업 실행과 기존 복구 지점 삭제를 담당할 주체는 별도로 정해야 합니다.
- AWS Backup의 백업 볼트(Backup vault)와 원본 서비스는 관리하는 대상이 다릅니다. S3 버전 관리·수명주기, 로그 보존, AMI·스냅샷 정리와 공통 백업 구성의 관리 위치를 구분해야 합니다.

## 검토한 대안

| 대안 | 백업 시점·보존 관리 | 운영 부담과 요구사항 적합성 |
| --- | --- | --- |
| 서비스별 백업·보존 정책 유지 | 각 서비스에서 백업과 정리를 관리 | 여러 서비스의 복구 수단과 보존 기준을 따로 관리해야 함 |
| AWS Backup 정기·연속 백업 | 지원 서비스에서 일정에 따라 백업하거나 변경분을 수집하고 보존기간으로 만료 | 백업 생성을 자동화하며, 운영 변경 직전 실행은 별도 처리가 필요함 |
| AWS Backup 온디맨드 백업 | 운영자가 변경 전에 백업하고, 보존기간에 따른 자동 삭제와 기존 복구 지점 수동 삭제를 사용 | 공통 백업 볼트에서 관리하며 백업 실행·완료 확인·최신 1개 유지는 운영자 작업이 필요함 |

## 결정과 이유

**선택: AWS Backup 온디맨드 백업의 보존기간을 7일로 설정하고, 공통 구성은 `env/backup`, 원본 서비스 설정은 각 서비스의 환경·모듈에서 관리**

- **백업 시점:** 운영자가 변경 직전에 실행할 수 있어 변경 전 상태를 확보한다는 요구에 맞습니다.
- **보존 관리:** AWS Backup의 복구 지점별 보존기간과 수동 삭제 기능으로 7일 보존·최신 1개 유지 기준을 적용할 수 있습니다.
- **구성 책임:** 공통 백업 리소스를 한 환경에서 관리하고, 원본 설정은 해당 서비스에 두어 변경과 정리의 담당 범위를 명확히 합니다.

### 백업 대상과 서비스별 범위

| 대상 | AWS Backup에서 관리할 범위 | 각 서비스에서 관리할 범위 |
| --- | --- | --- |
| Aurora DSQL | 클러스터 전체 백업·새 클러스터 복원 | 원본 클러스터, 삭제 보호, 복원 후 VPC Interface Endpoint와 API 접속 설정 |
| 운영 API EC2와 연결된 EBS | 인스턴스와 연결된 EBS의 백업·복원 | EC2·EBS, 시작 템플릿, Auto Scaling 그룹, 사용자 데이터와 운영 AMI 연결 |
| S3 웹 정적 파일·사진·지도·API 배포 파일 | 각 버킷의 객체 백업·복원 | 버킷, 객체 배포, 버전 관리, 수명주기, 접근 정책과 원본 암호화 |
| S3 CloudFront 접근 로그 | 로그 버킷의 객체 백업·복원 | 로그 전달, 원본 로그 객체의 보존기간과 수명주기 |
| EC2 Image Builder | 기존 AMI 자체는 직접 백업 대상으로 등록하지 않음 | 이미지 빌드, 배포용 AMI와 구성 스냅샷의 사용·보관·정리 |
| CloudWatch·CloudFront·ALB·VPC·NAT Gateway·VPC Interface Endpoint·IAM·Route 53·ACM 등 | 직접 백업 대상으로 등록하지 않음 | 로그 보존, 서비스 설정과 원본 리소스 관리 |

- Aurora DSQL은 매번 전체 클러스터를 백업하며, 복원하면 새 클러스터가 생성됩니다. [Aurora DSQL 백업](https://docs.aws.amazon.com/aws-backup/latest/devguide/backup-aurora.html), [Aurora DSQL 복원](https://docs.aws.amazon.com/aws-backup/latest/devguide/restore-auroradsql.html)
- 운영 API EC2는 VPC Interface Endpoint를 통해 Aurora DSQL에 사설 연결합니다. 복원한 클러스터의 연결 서비스명에 맞춰 Endpoint·Private DNS·보안 그룹을 구성하고, API의 접속 호스트·IAM 인증·TLS 검증 설정을 반영합니다. [Aurora DSQL PrivateLink 연결](https://docs.aws.amazon.com/aurora-dsql/latest/userguide/privatelink-managing-clusters.html)
- EC2 백업에는 연결된 EBS가 포함되므로 동일 볼륨에 별도 백업을 중복 적용하지 않습니다. [EC2 복원 범위](https://docs.aws.amazon.com/aws-backup/latest/devguide/restoring-ec2.html)
- 직접 백업을 지원하지 않는 대상에는 별도 AMI 백업·로그 내보내기·설정 파일 보관용 서비스를 추가하지 않습니다. [AWS Backup 지원 대상](https://docs.aws.amazon.com/aws-backup/latest/devguide/backup-feature-availability.html)

### `env/backup`과 각 서비스의 구성 경계

| 구성 항목 | 관리 위치 | 역할과 적용 범위 |
| --- | --- | --- |
| 백업 볼트·암호화 키 | `env/backup` | 서울 리전의 공통 백업 볼트와 볼트용 AWS KMS 키 관리 |
| AWS Backup 전용 백업·복원 IAM 권한 | `env/backup` | 백업 대상과 필요한 암호화 키에 접근할 권한 관리 |
| Aurora DSQL 보호 활성화 | `env/backup` | 서울 리전의 AWS Backup Service opt-in 설정 관리. [DSQL 백업 조건](https://docs.aws.amazon.com/aws-backup/latest/devguide/backup-aurora.html) |
| Aurora DSQL 원본 클러스터·삭제 보호 | DB 환경·모듈 | 원본 DB와 삭제 방지 설정 관리 |
| Aurora DSQL용 VPC Interface Endpoint·API 접속 설정 | DB·API 환경과 관련 모듈 | 복원한 클러스터의 PrivateLink 연결과 API 접속 구성 |
| EC2/EBS·시작 템플릿·Auto Scaling 그룹·EC2 Image Builder | API 환경·관련 모듈 | 원본 실행 환경과 배포용 이미지 관리 |
| S3 원본 버킷·버전 관리 | 프런트엔드·API 환경의 저장소 구성과 S3 모듈 | 웹·사진·지도·로그·배포 버킷과 AWS Backup 사용에 필요한 버전 관리 설정 |
| S3 수명주기 | 해당 버킷을 관리하는 환경과 S3 모듈 | 원본의 이전 버전·삭제 마커·로그 객체·미완료 멀티파트 업로드 정리 |
| 원본 접근 정책·암호화·서비스 IAM 권한 | 각 서비스의 환경·모듈 | 서비스의 정상 동작과 원본 데이터 보호 |
| CloudWatch 로그 보존·AMI와 스냅샷 정리 | 해당 서비스를 관리하는 환경·모듈 | 원본 로그와 배포 산출물의 보존·삭제 기준 관리 |

- `env/backup`은 AWS Backup 리소스를 정의하는 Terraform 환경이며, 각 서비스가 관리하는 원본 리소스의 식별 정보를 백업·복원 권한 구성에 참조합니다.
- S3는 버전 관리를 활성화해야 하며, 백업 시 버킷에 남아 있는 이전 객체 버전도 복구 지점에 포함됩니다. 원본 객체 버전·로그·배포용 AMI의 보존기간과 정리 기준은 각 서비스에서 별도로 정합니다. [S3 백업 조건](https://docs.aws.amazon.com/aws-backup/latest/devguide/s3-backups.html)

### 온디맨드 백업과 7일 보존

- **실행 조건:** 운영자가 수행하는 배포·DB 스키마 변경·설정 변경·원본 리소스 삭제 전에 해당 대상을 백업합니다. 서비스 이용 중 발생하는 DB 쓰기·사진 업로드·로그 생성은 개별 백업 실행 조건에서 제외합니다.
- **운영 방식:** 정기·연속 백업 계획과 별도 백업·정리 자동화는 구성하지 않습니다.
- 운영자가 운영 변경 대상의 온디맨드 백업을 AWS Backup에서 직접 실행하고, 매번 `Lifecycle.DeleteAfterDays=7`을 지정합니다. Aurora DSQL 삭제 전 백업에도 같은 기간을 적용합니다. [온디맨드 백업 설정](https://docs.aws.amazon.com/aws-backup/latest/APIReference/API_StartBackupJob.html)
- 새 백업이 완료된 것을 확인한 뒤 운영 변경을 진행합니다. 백업에 실패하면 운영 변경을 중단하고 기존 복구 지점을 유지합니다.
- 새 백업 완료 후 같은 대상의 기존 복구 지점을 운영자가 삭제해 최신 1개를 유지합니다. [복구 지점 삭제](https://docs.aws.amazon.com/aws-backup/latest/APIReference/API_DeleteRecoveryPoint.html)
- 복구 지점은 생성 후 7일에 만료되며, AWS Backup은 만료 후 8시간 이내에 삭제 작업을 분산 처리합니다. 권한 문제 등으로 삭제되지 않으면 `EXPIRED` 상태로 남을 수 있으므로, 운영자가 삭제 실패 원인을 해소하고 정리합니다. [보존기간 기준](https://docs.aws.amazon.com/aws-backup/latest/APIReference/API_Lifecycle.html), [백업 삭제](https://docs.aws.amazon.com/aws-backup/latest/devguide/deleting-backups.html)
- 콜드 스토리지 전환은 사용하지 않으며, 보존기간이 남은 기존 복구 지점을 삭제할 수 있는 백업 볼트 정책을 사용합니다. 보존기간 전 삭제를 막는 AWS Backup Vault Lock은 적용하지 않습니다. [AWS 보존기간 조건](https://docs.aws.amazon.com/aws-backup/latest/APIReference/API_Lifecycle.html), [AWS Backup Vault Lock 삭제 제한](https://docs.aws.amazon.com/aws-backup/latest/devguide/vault-lock.html)

### 결과

- 이점: 지원 대상의 백업·복원을 한곳에서 관리하고, 백업 누적을 제한할 수 있습니다.
- 이점: 공통 백업 구성과 원본 서비스 설정의 변경·정리 책임이 명확해집니다.
- 제약: 백업 실행, 완료 확인, 기존 복구 지점 삭제는 운영자가 수행해야 합니다. 누락하면 변경 전 백업 또는 최신 1개 유지 기준을 충족하지 못합니다.
- 제약: 복구 범위는 백업에 포함된 상태까지이며, 이후의 DB 쓰기·사진 업로드·로그 생성분은 다음 백업 전까지 보호되지 않습니다. 운영 변경이 없는 동안 마지막 복구 지점까지 만료·삭제되면 사용 가능한 백업이 없을 수 있습니다.
- 제약: 백업 저장·복원 비용과 S3 원본 버전·배포용 스냅샷 등의 저장 비용은 각각 발생합니다.
