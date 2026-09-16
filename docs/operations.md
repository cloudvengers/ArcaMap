# 운영 점검

## 주요 개념

| 용어 | 개념 |
|---|---|
| 로그 | 요청·오류·서비스 동작을 시간순으로 남긴 기록 |
| 지표 | CPU·요청 수·정상 대상 수처럼 수치로 집계한 상태 |
| 경보 | 지표의 임계값·평가 기간에 따른 상태 판단 |
| M/N 평가 | 최근 N개 구간 중 M개 이상이 임계값을 위반하면 경보 |
| 헬스 체크 | 지정 요청에 대한 응답 검사. 검사에 포함된 범위만 정상 판정 |
| 자동 백업 | 보존 기간 안의 복구에 사용할 DB 백업 |
| 스냅샷 | 특정 시점의 DB 저장 상태 |

## 서비스 점검

```bash
curl -sS -I --max-time 15 https://arcamap.app/
curl -sS -i --max-time 15 https://api.arcamap.app/health
curl -sS -i --max-time 15 https://api.arcamap.app/health/db
curl -sS --max-time 15 https://api.arcamap.app/api/places \
  | jq '{total, items: (.items | length)}'
```

| 검사 | 정상 기준 | 확인 범위 |
|---|---|---|
| 웹 `/` | HTTP 200 | 정적 페이지 응답 |
| `/health` | HTTP 200, `status: ok` | API 응답 |
| `/health/db` | HTTP 200, `database: ok` | DB 연결·SQL 실행 |
| `/api/places` | HTTP 200, `total = items.length` | 장소 조회 |

데이터 기준: 장소 50건·좌표 보유 45건·보존목록 9건. 필드 수: 장소 13개·보존목록 8개.

## 로그 위치

| 대상 | 저장 위치 | 수집 |
|---|---|---|
| EC2 시스템 | `/arcamap/ec2/system` | Agent의 journald 수집, priority `info`, 스트림 `{instance_id}/system` |
| API 프로세스 | EC2의 `journalctl -u arcamap-api` | systemd 표준 출력·오류 |
| API 전용 그룹 | `/arcamap/api/application` | 그룹 생성만 정의, 별도 API 파일 수집 설정 없음 |
| ALB | `/aws/vendedlogs/elb/arcamap-api` | access·connection·health check, JSON 로그 전달 |
| Image Builder | `/aws/imagebuilder/arcamap-api` | 이미지 생성 로그 |
| RDS SQL·엔진 | `/aws/rds/instance/arcamap-postgres/postgresql` | RDS 로그 내보내기 |
| RDS 업그레이드 | `/aws/rds/instance/arcamap-postgres/upgrade` | RDS 로그 내보내기 |
| CloudFront | web 출력의 `s3_buckets.cloudfront_logs` | 표준 로그 전달, JSON |

| 보존 설정 | 값 |
|---|---|
| CloudWatch 로그 그룹 | 30일 |
| CloudFront 로그 S3 | 객체 생성 후 30일 만료 |
| CloudWatch Agent | `1.300072.0b1766` |
| Agent 원본 설정 | `/opt/aws/amazon-cloudwatch-agent/etc/arcamap-cloudwatch-agent.json` |

## 로그 조회

```bash
aws logs tail /arcamap/ec2/system \
  --region ap-northeast-2 --since 15m --format short
aws logs tail /aws/vendedlogs/elb/arcamap-api \
  --region ap-northeast-2 --since 15m --format short
aws logs tail /aws/imagebuilder/arcamap-api \
  --region ap-northeast-2 --since 1h --format short
```

SSM으로 접속한 WAS EC2:

```bash
systemctl is-active arcamap-api amazon-cloudwatch-agent
sudo journalctl -u arcamap-api -n 100 --no-pager
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a status
```

판정: 두 서비스 active, Agent running, 해당 인스턴스의 최근 로그 수신.

## 경보 설정

경보 이름 접두사: `arcamap-`

| 이름 | 지표·통계 | 임계값 | 주기 | M/N |
|---|---|---|---|---|
| `asg-inservice` | GroupInServiceInstances · Minimum | 2대 미만 | 60초 | 2/3 |
| `ec2-status-check` | StatusCheckFailed · Maximum | 1 이상 | 60초 | 2/3 |
| `ec2-cpu` | CPUUtilization · Average | 80% 이상 | 300초 | 3/3 |
| `alb-healthy-hosts` | HealthyHostCount · Minimum | 2대 미만 | 60초 | 2/3 |
| `alb-5xx` | HTTPCode_ELB_5XX_Count · Sum | 5건 이상 | 300초 | 1/1 |
| `api-5xx` | HTTPCode_Target_5XX_Count · Sum | 5건 이상 | 300초 | 1/1 |
| `rds-cpu` | CPUUtilization · Average | 80% 이상 | 300초 | 3/3 |
| `rds-free-memory` | FreeableMemory · Minimum | 512 MiB 미만 | 300초 | 3/3 |
| `rds-free-storage` | FreeStorageSpace · Minimum | 5 GiB 미만 | 300초 | 1/1 |

- ELB 5xx: ALB가 생성한 오류, Target 5xx: WAS가 반환한 오류
- 누락 데이터: 5xx 경보는 `notBreaching`, 나머지는 `missing`
- 알림 동작: `actions_enabled = false`, SNS 등 수신 대상 없음
- 연결 수 경보: `db_max_connections = null`로 생성 보류. 실제 `SHOW max_connections;` 값을 입력하면 80% 기준·60초·3/3으로 생성
- ASG CPU 목표 추적 50%: 확장 정책. 위 CPU 80% 경보와 별도 설정

## 경보 조회·대응

```bash
aws cloudwatch describe-alarms \
  --region ap-northeast-2 --alarm-name-prefix arcamap- \
  --query 'MetricAlarms[].{Name:AlarmName,State:StateValue,Reason:StateReason,Actions:ActionsEnabled}'
```

| 상태·증상 | 점검 순서 |
|---|---|
| `INSUFFICIENT_DATA` | 지표 차원·수집 주기·실제 데이터 존재 여부 |
| 정상 인스턴스·대상 부족 | ASG 활동 → 인스턴스 상태 → 서비스 로그 → ALB 대상 상태 |
| ELB 5xx | ALB 로그 → 리스너·대상 연결 → 대상 상태 |
| API 5xx | API 로그 → `/health/db` → RDS 상태 |
| RDS 메모리·저장 공간 부족 | 지표 추이 → DB 연결·쿼리·용량 확인 |

## 백업 설정

| 대상 | 설정 | 제약 |
|---|---|---|
| RDS | 자동 백업 3일, 삭제 보호, 최종 스냅샷 생성 | 복구 가능 시각은 Earliest·LatestRestorableTime 기준 |
| 사진 S3 | 버전 관리, 이전 버전 7일 보존 | 현재 사진 기능 미사용 |
| 정적 S3 | 버전 관리 없음 | 이전 웹 배포 복구에 이전 산출물 필요 |
| API 배포 S3 | SHA-256별 객체 키 | 객체 변경 시 새 키 생성 |
| Terraform state | 루트별 로컬 파일 | 원격 backend 없음 |

```bash
aws rds describe-db-instances \
  --region ap-northeast-2 --db-instance-identifier arcamap-postgres \
  --query 'DBInstances[0].{Retention:BackupRetentionPeriod,DeletionProtection:DeletionProtection,Earliest:EarliestRestorableTime,Latest:LatestRestorableTime}'
aws rds describe-db-snapshots \
  --region ap-northeast-2 --db-instance-identifier arcamap-postgres \
  --query 'DBSnapshots[].{ID:DBSnapshotIdentifier,Type:SnapshotType,Status:Status,Created:SnapshotCreateTime}'
```

- 정상 기준: 보존 3일, 삭제 보호 true, 복구 가능 시각 확인
- 최종 스냅샷: `arcamap-postgres-final`; 같은 이름의 기존 스냅샷이 있으면 삭제 작업 전 고유 이름 필요
- Multi-AZ: 인스턴스 장애 대응. 오삭제·잘못된 적재의 복구는 백업·스냅샷 작업
