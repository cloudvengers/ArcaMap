# API 인프라

`api` 환경은 공개 ALB, API 인스턴스, Image Builder, 배포 파일 저장소와 IAM 역할을 구성합니다. API 인스턴스는 사설 서브넷에 배치하며 DSQL VPC 엔드포인트로 데이터베이스에 접속합니다.

## 요청 경로

`api.arcamap.app`의 Route 53 `A` 별칭 레코드는 ALB로 연결합니다. ALB는 HTTPS `443` 요청을 받아 API 인스턴스의 HTTP `8080`으로 전달합니다. HTTP `80` 요청은 HTTPS로 리다이렉트합니다.

ALB는 `/health`로 대상 상태를 검사합니다. API WAF는 `/health/db`와 `/health/db/` 경로를 차단하고 AWS 관리형 규칙 그룹 3개를 적용합니다. 세부 규칙은 [ALB 모듈](../../modules/alb/README.md)에 정의합니다.

## 인스턴스와 이미지

[terraform.tfvars](terraform.tfvars)의 주요 설정은 다음과 같습니다.

| 항목 | 설정 |
|---|---|
| API 배치 | `ap-northeast-2a`의 사설 서브넷 1개 |
| API 인스턴스 | `t3.small`, 암호화한 `gp3` 루트 볼륨 20GiB |
| ASG 용량 | 최소 1대, 최대 2대 |
| 자동 조정 목표 | 평균 CPU 50%, 평균 메모리 사용률 50% |
| ASG 상태 검사 | `ELB` |
| 이미지 선택 | `api_image`에 `arcamap-api/2.0.0/1`의 전체 ARN 지정 |
| Image Builder | 활성화, `t3.small`, 루트 볼륨 20GiB, 레시피 `2.0.0` |

인스턴스 교체에는 최소 정상 비율 100%, 최대 정상 비율 200%와 준비 시간 300초를 적용합니다. `arcamap-alb-healthy-hosts`, `arcamap-alb-5xx`, `arcamap-api-5xx` 경보를 감시하며 자동 롤백을 활성화합니다.

인스턴스 설정은 [compute 모듈](../../modules/compute/README.md)에, AMI 수명 주기는 [Image Builder 모듈](../../modules/image-builder/README.md)에 정의합니다.

## 연결 설정과 권한

[네트워크 환경](../network/README.md)의 VPC, 공개 서브넷 2개, API 사설 서브넷과 보안 그룹을 이름·태그로 조회합니다. [데이터베이스 환경](../database/README.md)의 클러스터·리전·호스트·포트 정보는 `database` 입력으로 전달합니다.

`certificate_arn`은 서울 리전의 ACM 인증서를 지정합니다. DNS는 `route53_zone_id`의 영역과 `route53_role_arn`의 관리 역할을 사용합니다.

| IAM 역할 | 권한 |
|---|---|
| `arcamap-api-ec2` | Session Manager, CloudWatch Agent, 대상 DSQL 클러스터의 `dsql:DbConnect` |
| `arcamap-imagebuilder-ec2` | Session Manager, CloudWatch Agent, DSQL 접속, Image Builder, 시스템 로그 조회와 배포 객체 읽기 |

배포 파일은 `arcamap-deploy-` 접두사의 S3 버킷에 저장합니다. 버킷은 퍼블릭 액세스를 차단하고 기본 암호화와 버전 관리를 사용합니다. 이전 객체 버전의 보존 기간은 7일입니다.

## 로그

| 로그 그룹 | 내용 | 보존 기간 |
|---|---|---|
| `/arcamap/ec2/system` | 인스턴스의 journald 로그 | 30일 |
| `/aws/vendedlogs/elb/arcamap-api` | ALB 접근·연결·상태 검사 로그 | 30일 |
| `/aws/imagebuilder/arcamap-api` | Image Builder 로그 | 30일 |
| `aws-waf-logs-arcamap-api` | API WAF 로그 | 14일 |

CloudWatch Agent는 메모리 사용률과 가용 메모리를 60초 간격으로 수집합니다. 메모리 지표에는 인스턴스 ID와 ASG 이름을 연결하고 ASG별 집계도 생성합니다.

## 경보

경보 이름에는 `arcamap-` 접두사를 붙입니다. 모든 경보의 `ALARM`, `OK`, `INSUFFICIENT_DATA` 상태 전환을 `arcamap-operations` SNS 토픽으로 알립니다.

| 경보 접미사 | 조건 | 평가 |
|---|---|---|
| `asg-inservice` | 실행 인스턴스 최솟값 1대 미만 | 1분 구간 3회 중 2회 |
| `ec2-status-check` | 상태 검사 실패 최댓값 1 이상 | 1분 구간 3회 중 2회 |
| `ec2-cpu` | 평균 CPU 사용률 80% 이상 | 5분 구간 3회 연속 |
| `ec2-memory` | 평균 메모리 사용률 80% 이상 | 5분 구간 3회 연속 |
| `alb-healthy-hosts` | 정상 대상 최솟값 1개 미만 | 1분 구간 3회 중 2회 |
| `alb-5xx` | ALB 5xx 응답 합계 5건 이상 | 5분 구간 1회 |
| `api-5xx` | 대상 5xx 응답 합계 5건 이상 | 5분 구간 1회 |

누락 데이터는 5xx 경보에서 `notBreaching`으로, 나머지 경보에서 `missing`으로 처리합니다. 로그와 경보는 [monitoring.tf](monitoring.tf)에 정의합니다.

## 출력

[outputs.tf](outputs.tf)는 ALB, API 주소, ASG, 시작 템플릿, 선택한 AMI, Image Builder 파이프라인과 로그 그룹 정보를 반환합니다. 배포 버킷, EC2 IAM 역할 ARN과 데이터베이스 역할 연결 정보도 반환합니다.
