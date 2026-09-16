# CloudWatch 로그 그룹

## 주요 개념

| 용어 | 개념 | 적용 |
|---|---|---|
| 로그 그룹 | 보존 기간·접근 권한을 공유하는 로그 저장 단위 | 서비스별 6개 |
| 로그 스트림 | 같은 출처에서 순서대로 기록되는 이벤트 묶음 | EC2별 `{instance_id}/system` |
| 수집 설정 | 로그를 읽어 그룹으로 보내는 구성 | Agent·ALB 전달·RDS 내보내기 |
| 보존 기간 | 로그 이벤트를 유지할 기간 | 30일 |

## 현재 구성·입력

| 항목 | 값 |
|---|---|
| 모듈 | `terraform/modules/cloudwatch-log-group` |
| 호출 루트 | was 4개, db 2개 |
| `name` | 로그 그룹 전체 이름 |
| 이름 조건 | 1~512자 영숫자·`/._#-`, `aws/` 접두사 불가 |
| `log_retention_days` | 30일, 지원하는 양의 보존 일수 입력 |
| 로그 클래스 | `STANDARD` |

## 그룹·수집 경로

| 루트·키 | 로그 그룹 | 수집 |
|---|---|---|
| was·`ec2_system` | `/arcamap/ec2/system` | Agent의 journald, priority `info` |
| was·`api` | `/arcamap/api/application` | 그룹 생성, 별도 API 파일 수집 설정 없음 |
| was·`alb` | `/aws/vendedlogs/elb/arcamap-api` | 접근·연결·상태 검사 JSON 전달 |
| was·`imagebuilder` | `/aws/imagebuilder/arcamap-api` | 이미지 생성 로그 |
| db·`rds_postgresql` | `/aws/rds/instance/arcamap-postgres/postgresql` | RDS PostgreSQL 로그 내보내기 |
| db·`rds_upgrade` | `/aws/rds/instance/arcamap-postgres/upgrade` | RDS 업그레이드 로그 내보내기 |

API 프로세스의 표준 출력·오류는 `journalctl -u arcamap-api`로 조회합니다. CloudFront 접근 로그는 S3에 저장하며 이 모듈의 로그 그룹을 사용하지 않습니다.

## 적용·연결

| 작업 | 처리 |
|---|---|
| 보존 기간 변경 | 해당 루트의 `log_retention_days` 수정 후 plan·apply |
| WAS 연결 | 그룹 이름·ARN을 Agent·ALB·Image Builder에 전달 |
| RDS 연결 | DB 로그 그룹 생성 완료 후 RDS 생성 |
| 자원 소유권 | 해당 루트가 자신의 로그 그룹만 관리 |

## 로그 조회

```bash
aws logs describe-log-groups --region ap-northeast-2 \
  --log-group-name-prefix /arcamap/ \
  --query 'logGroups[].{Name:logGroupName,Retention:retentionInDays,Class:logGroupClass}'
aws logs tail /arcamap/ec2/system \
  --region ap-northeast-2 --since 15m --format short
aws logs tail /aws/vendedlogs/elb/arcamap-api \
  --region ap-northeast-2 --since 15m --format short
```

SSM으로 접속한 WAS EC2:

```bash
sudo journalctl -u arcamap-api -n 50 --no-pager
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a status
```

## 출력·정상 기준

| 항목 | 내용·기준 |
|---|---|
| `log_group.name` | 수집·조회에 사용할 그룹 이름 |
| `log_group.arn` | 전달 대상·IAM 권한 범위 |
| 보존·클래스 | 30일·`STANDARD` |
| Agent | `running`, 시스템 그룹에 해당 인스턴스의 최근 이벤트 |
| API 전용 그룹 | 그룹 존재만으로 API 로그 수집 완료를 판단하지 않음 |
