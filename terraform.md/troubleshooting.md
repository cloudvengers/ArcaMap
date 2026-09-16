# Terraform 배포 문제 해결

## 사례 목록

| 발생일 | 문제 | 확인 결과 |
|---|---|---|
| 2026-09-14 | RDS 포트를 0으로 조회 | 접속 포트를 `port`로 변경, 실제 plan 성공 |
| 2026-09-14 | Image Builder의 Agent 설정 파일 누락 | 원본 파일명 변경, 후속 AMI 생성 완료 |
| 2026-09-14 | ASG 역할 사용 거부·tainted | EC2 자동 복구 확인, state 정리 결과 기록 없음 |
| 2026-09-15 | WAF 가져오기 리전·모의 테스트 오류 | 가져오기 ID에 리전 명시·테스트 대상 재정의, 적용 후 `No changes` |

## RDS 포트 조회 오류

### 개념

| 항목 | 의미 |
|---|---|
| 데이터 소스 | 실제 AWS 자원의 속성 조회 |
| `port` | RDS 접속 엔드포인트의 포트 |

### 증상·원인

| 항목 | 당시 확인 내용 |
|---|---|
| 실패 위치 | WAS의 compute 입력 검증 |
| 오류 | `var.database.port is 0` |
| AWS 응답 | RDS available, `Endpoint.Port = 5432`, `DbInstancePort = 0` |
| 잘못된 참조 | `data.aws_db_instance.postgres.db_instance_port` |

### 조치

1. 접속 포트 참조를 `data.aws_db_instance.postgres.port`로 변경.
2. 포트 5432 입력 조건 유지.

### 결과

| 검사 | 당시 결과 |
|---|---|
| 실제 plan | 40개 생성·0개 변경·0개 삭제, 종료 코드 2 |
| 조회값·시작 템플릿 | `port = 5432`, 당시 `PGPORT=5432` 반영 확인 |
| apply·SQL 접속 | 해당 수정 작업에서 미실행 |

`plan -detailed-exitcode`: 0 = 변경 없음, 1 = 오류, 2 = 적용할 변경 있음.

현재 구성: WAS가 `port` 값을 읽어 Secrets Manager의 `PGPORT`에 저장.

## Image Builder Agent 설정 파일 누락

### 개념

| 항목 | 의미 |
|---|---|
| Image Builder | 소프트웨어 설치 과정을 자동화하여 AMI 생성 |
| `fetch-config` | 원본 설정을 읽어 CloudWatch Agent에 적용 |

### 증상

| 항목 | 값 |
|---|---|
| 발생 시각 | 2026-09-14 01:23:27 KST |
| 이미지 상태 | `FAILED` |
| 로그 그룹·스트림 | `/aws/imagebuilder/arcamap-api` · `1.0.0/1` |

```text
fail to fetch/remove json config: open /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json: no such file or directory
```

### 원인·조치

| 구간 | 확인 내용 |
|---|---|
| 빌드 | 기본 경로에 JSON 생성 후 `fetch-config` 실행 |
| 설정 적용 | Agent 제어 스크립트가 기본 JSON 경로 삭제 |
| Agent 재기동 | 같은 원본 경로를 다시 읽으면서 파일 없음 오류 |
| 조치 | 원본 이름을 `arcamap-cloudwatch-agent.json`으로 변경 |
| 반영 범위 | JSON 생성 경로와 Agent 공통 시작 명령 |

현재 원본 경로:

```text
/opt/aws/amazon-cloudwatch-agent/etc/arcamap-cloudwatch-agent.json
```

### 결과

| 검사 | 당시 결과 |
|---|---|
| 후속 Terraform 적용 로그 | 이미지 `Creation complete after 18m1s` |
| 다음 단계 | 시작 템플릿 생성 완료, ASG 생성 중 별도 오류 발생 |


## ASG 역할 사용 거부와 tainted

### 개념

| 용어 | 의미 |
|---|---|
| 서비스 연결 역할 | AWS 서비스가 다른 AWS 자원을 관리할 때 사용하는 IAM 역할 |
| IAM 전파 지연 | 역할·정책 변경이 서비스에 반영되기까지 발생할 수 있는 지연 |
| `tainted` | Terraform이 자원을 다음 계획의 교체 대상으로 취급하는 상태 표시 |
| `untaint` | 정상 자원의 교체 표시 해제. 실제 AWS 자원 변경 없음 |

### 증상

```text
Access denied when attempting to assume role .../AWSServiceRoleForAutoScaling.
Validating load balancer configuration failed.
```

대상: `arcamap-api` · `module.compute.aws_autoscaling_group.api[0]`

### 확인 근거

시각: 2026-09-14 KST.

| 시각 | 사건 |
|---|---|
| 01:51:18 | Auto Scaling 서비스 연결 역할 생성 |
| 01:51:19 | ASG 생성 |
| 01:51:22 | 두 AZ의 최초 인스턴스 시작에서 역할 사용 거부 |
| 01:52:22 | 자동 재시도로 2c 인스턴스 시작 |
| 01:54:20 | 자동 재시도로 2a 인스턴스 시작 |

- 역할 신뢰 정책: `autoscaling.amazonaws.com`의 AssumeRole 허용
- 관리 정책: `AutoScalingServiceRolePolicy` 연결 확인
- 후속 인스턴스: 2대 모두 `InService`·`Healthy`
- 당시 검사 유형: `EC2`; API 응답·ALB 상태 확인과 구분
- 원인 판단: 역할 생성 직후 실패와 후속 성공을 근거로 IAM 전파 지연 추정

### Terraform 영향

| 항목 | 당시 결과 |
|---|---|
| State | ASG에 `tainted` 표시 |
| 실제 plan | 8개 생성·0개 변경·1개 삭제 |
| 생성 내역 | ASG 교체분, CPU 확장 정책 1개, 경보 6개 |
| AMI·시작 템플릿 | 교체 계획 없음 |

### 진단·상태 정리

작업 위치: `/root/protomaps`.

```bash
aws iam get-role --role-name AWSServiceRoleForAutoScaling
aws autoscaling describe-scaling-activities \
  --region ap-northeast-2 --auto-scaling-group-name arcamap-api --max-items 20
aws autoscaling describe-auto-scaling-groups \
  --region ap-northeast-2 --auto-scaling-group-names arcamap-api
terraform -chdir=terraform/env/was state pull \
  | jq '.resources[] | select(.type == "aws_autoscaling_group") | .instances[] | {status, id: .attributes.id}'
```

`untaint` 적용 조건: 실제 ASG 구성·목표 인스턴스 수·상태 정상, 교체 사유가 생성 실패 표시임을 확인.

```bash
umask 077
terraform -chdir=terraform/env/was state pull > was-state-before-untaint.json
terraform -chdir=terraform/env/was untaint -lock-timeout=5s \
  'module.compute.aws_autoscaling_group.api[0]'
terraform -chdir=terraform/env/was plan
```

정상 판정: 실패 표시로 인한 ASG 교체 제거, 실제 설정 변경과 미완료 자원만 계획에 포함.

### 결과

| 범위 | 상태 |
|---|---|
| AWS 역할·ASG·활동 조회 | 완료 |
| State 조회·실제 plan | 완료 |
| EC2 자동 복구 | 확인 |
| `untaint`·후속 apply | 실행 결과 기록 없음 |

## WAF 가져오기 리전·모의 테스트 오류

### 개념

| 항목 | 의미 |
|---|---|
| 코드 생성 | `plan -generate-config-out`으로 기존 자원의 HCL 초안 생성 |
| 가져오기 | 기존 AWS 자원과 Terraform 주소를 state에서 연결 |
| `@us-east-1` | AWS Provider의 가져오기 대상 리전 지정 |
| `override_resource` | 테스트에서 특정 자원의 응답을 가상 값으로 대체 |

### 증상·원인

| 오류 | 당시 원인 |
|---|---|
| `WAFInvalidParameterException: The scope is not valid` | 기본 Provider 리전은 서울인데 CloudFront WAF 가져오기 ID에 `us-east-1`을 지정하지 않음 |
| `Cannot import resources from mock providers` | 루트의 import 대상이 모의 Provider에만 정의돼 있음 |
| 새 테스트 추가 후 `Module not installed` | 테스트에서 새로 참조한 모듈의 초기화 필요 |

### 조치

1. `env/web/imports.tf`의 WAF·로그 그룹·로그 설정 ID 끝에 `@us-east-1` 추가.
2. 루트 테스트에서 가져오기 대상 3개를 각각 `override_resource`로 지정.
3. `init -lockfile=readonly`로 테스트 모듈 초기화. Provider 버전 `6.63.0` 유지.

```hcl
import {
  to = module.cloudfront.aws_wafv2_web_acl.site
  id = "e41dd9fc-b545-4b89-be77-8187f556c9e8/CreatedByCloudFront-609132c8/CLOUDFRONT@us-east-1"
}
```

코드의 `region = "us-east-1"` 지정과 가져오기 ID의 리전 지정은 모두 유지합니다. 실제 WAF 설정을 바꾸는 조치는 수행하지 않았습니다.

### 결과

| 검사 | 당시 결과 |
|---|---|
| 코드 생성·`validate` | 통과 |
| 모의 테스트 | 6개 통과 |
| 실제 계획·적용 | WAF·로그 그룹·로그 설정 3개 가져오기, 생성·변경·삭제 0개 |
| 적용 후 전체 plan | `No changes`, 종료 코드 0 |
| AWS 설정 | CloudFront ETag·WAF LockToken 작업 전후 동일 |
