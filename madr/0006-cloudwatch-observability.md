# CloudWatch 운영 관측 — API·DSQL 관측 재구성 및 SNS 상태 알림

## 배경과 문제

### 배경

- 현재 AWS에 서비스 인프라는 배포되어 있지 않으며, 고가용성 구성을 단일 구성 운영 기반으로 재구성합니다.
- API 서버는 기존 사양과 목표 추적 정책을 유지하면서 ASG 최소 1대·최대 2대로 운영하고, 데이터베이스는 RDS에서 단일 리전 Aurora DSQL로 변경합니다.
- 기존 CloudWatch는 API·ASG·ALB 경보, EC2 서비스 로그, WAF 로그와 통합 대시보드를 구성하고 있습니다. 서비스가 바뀌면서 조정해야 하는 지표·경보·로그·대시보드 정책을 CloudWatch 서비스 범위에서 정합니다.

### 문제

- ASG의 `InService` 인스턴스 수와 ALB 정상 대상 수 경보는 2대 미만을 장애로 판단하므로, 정상적인 서버 1대 운영에서도 경보가 발생합니다.
- 기존 RDS CPU·가용 메모리·가용 저장 공간·연결 수 경보와 PostgreSQL·upgrade 로그 그룹은 DSQL에 그대로 적용할 수 없습니다.
- 기존 통합 대시보드에는 API·ASG·ALB·WAF 관측 항목이 있지만 DB 관측 항목은 없습니다. DSQL의 오류·처리량·지연·사용량을 추가해야 합니다.
- API 애플리케이션 로그는 journald를 통해 `/arcamap/ec2/system`에 수집되지만, 별도로 생성한 `/arcamap/api/application` 로그 그룹에는 수집 경로가 연결되어 있지 않습니다.
- 대시보드 로그 위젯의 시작 위치가 고정되어 있어 DSQL 지표 위젯을 추가하면 배치도 함께 조정해야 합니다.
- 직접 구성한 운영 경보는 경보 작업이 비활성화되어 있고 알림 대상도 비어 있어, 경보 발생과 지표 수집 중단을 운영자에게 알리지 않습니다.

## 검토한 대안

### 관측 구성

- **기존 API 대시보드를 유지하고 필수 경보만 수정:** 대수 경보를 조정하고 RDS 경보를 제거한 뒤 DSQL 연결 수 경보만 추가합니다. 변경량은 적지만 DSQL의 쿼리 오류·충돌·지연·사용량을 기존 통합 화면에서 확인하기 어렵습니다.
- **기존 CloudWatch 운영 방식으로 API·DSQL 관측을 함께 구성:** 필요한 경보와 로그를 정리하고 통합 대시보드에 DSQL 지표를 추가합니다. 추가 지표와 대시보드 설정이 필요하지만 서비스 운영에 필요한 상태를 함께 확인할 수 있습니다.

### 경보 알림

- **경보 작업 비활성화(`ActionsEnabled=false`):** 알림을 보내지 않으며, 운영자가 경보 발생·정상 전환·데이터 부족을 대시보드에서 직접 확인합니다.
- **`ALARM`·`OK` 상태 전환 알림:** 경보 작업을 활성화하고 `AlarmActions`·`OKActions`에 SNS 토픽 ARN을 지정합니다. 경보 발생·정상 전환을 알리며, 데이터 부족 상태는 운영자가 직접 확인합니다.
- **`ALARM`·`OK`·`INSUFFICIENT_DATA` 상태 전환 알림:** 경보 작업을 활성화하고 `AlarmActions`·`OKActions`·`InsufficientDataActions`에 SNS 토픽 ARN을 지정합니다. 경보 발생·정상 전환·데이터 부족을 구분해 알리며, 데이터 부족 알림에 대한 원인 확인도 필요합니다. [AWS 경보 작업과 SNS 알림 설정](https://docs.aws.amazon.com/AmazonCloudWatch/latest/APIReference/API_PutMetricAlarm.html)

### ASG·ALB 대수 경보의 누락 데이터 처리

- **`missing` — 데이터 부족으로 구분:** 평가 범위의 데이터가 모두 누락되면 `INSUFFICIENT_DATA`가 됩니다. 대수를 판단할 수 없는 상태로 구분하며, 해당 상태의 알림을 설정하면 수집 중단을 전달할 수 있습니다.
- **`ignore` — 현재 경보 상태 유지:** 누락 데이터로 경보 상태를 바꾸지 않습니다. 기존 상태가 `OK`이면 지표가 끊겨도 정상 상태가 유지될 수 있어, 수집 중단이 상태 변화로 드러나지 않을 수 있습니다.
- **`breaching` — 누락을 임계값 위반으로 처리:** 누락 데이터를 임계값 위반으로 간주해 평가합니다. 실제 대수가 정상이어도 지표 보고 중단으로 `ALARM`이 될 수 있으며, 교체 중 ALB 정상 대상 수 경보가 `ALARM`이 되면 기존 자동 롤백 조건에 포함됩니다.
- **`notBreaching` — 누락을 임계값 위반이 아닌 것으로 처리:** 누락 데이터를 임계값 위반이 아닌 것으로 간주해 평가합니다. 실제 장애로 지표가 끊겨도 누락 자체로는 경보가 발생하지 않습니다. [AWS 누락 데이터 처리](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/alarms-and-missing-data.html)

## 결정과 이유

**선택: API·DSQL 관측을 재구성하고, 기존 누락 데이터 처리를 유지하면서 SNS로 경보 발생·정상 전환·데이터 부족을 알림**

- 서버 대수와 DB 서비스 변경에 필요한 관측 설정을 함께 조정해 정상 운영과 장애를 구분합니다.
- 기존 경보 조건과 로그 보존 정책은 유지하고, 운영 구성 변경으로 의미가 달라지는 항목만 변경합니다.
- DSQL은 서비스에서 제공하는 처리·오류·지연·사용량 지표를 사용합니다.
- 경보 알림은 `ALARM`·`OK`·`INSUFFICIENT_DATA` 상태 전환을 모두 SNS로 전달하는 방식을 선택합니다. 운영자가 경보 발생·정상 전환·데이터 부족을 알림으로 확인할 수 있기 때문입니다.
- ASG·ALB 대수 경보의 누락 데이터 처리는 `missing`을 선택합니다. 대수 지표 누락만으로 정상이나 장애를 단정할 수 없으므로, 판단에 필요한 데이터가 없는 상태로 구분하고 `INSUFFICIENT_DATA` 알림으로 전달합니다.

### API·ASG·ALB 경보

- ASG의 `InService` 인스턴스 수와 ALB 정상 대상 수 경보의 임계값을 2대 미만에서 1대 미만으로 변경합니다. 두 경보 모두 기존 60초 주기·3회 평가 중 2회 충족 조건과 `Minimum` 통계를 유지합니다.
- ASG의 `GroupInServiceInstances`는 인스턴스 수명 주기에서 `InService` 상태인 대수를 셉니다. API의 상태 검사 결과는 ALB 정상 대상 수와 함께 판단합니다. [AWS ASG 지표](https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-target-tracking-metric-math.html)
- ALB의 `HealthyHostCount`는 상태 검사를 통과한 대상 수이며, `Minimum`은 평가 구간에 각 ALB 노드가 보고한 값의 최솟값입니다. 이 지표는 등록된 대상이 있을 때 보고되므로, 모든 대상이 등록 해제된 경우에는 0이 보고된다고 전제하지 않습니다. [AWS ALB 지표](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-cloudwatch-metrics.html)
- 나머지 기존 API 경보 조건은 다음과 같이 유지합니다.

| 관측 항목 | 경보 조건 | 통계·평가 조건 |
| --- | --- | --- |
| EC2 상태 검사 실패 | `StatusCheckFailed` 1 이상 | Maximum, 60초 주기, 3회 중 2회 |
| EC2 CPU 사용률 | 80% 이상 | Average, 300초 주기, 3회 연속 |
| EC2 메모리 사용률 | 80% 이상 | Average, 300초 주기, 3회 연속 |
| ALB 5xx 응답 | 300초 동안 5건 이상 | Sum, 1회 |
| API 대상 5xx 응답 | 300초 동안 5건 이상 | Sum, 1회 |

- ASG의 CPU·메모리 목표 추적 정책은 각각 50%를 유지합니다. AWS가 생성·관리하는 목표 추적 경보는 자동 증설·축소에 필요한 작업을 활성 상태로 유지합니다. [AWS 목표 추적 경보](https://docs.aws.amazon.com/autoscaling/ec2/userguide/as-scaling-target-tracking.html)
- ASG 단위 집계와 인스턴스별 메모리 지표 검색을 유지해 서버가 1대에서 2대로 증가해도 관측 대상이 따라가도록 합니다. 지표의 차원과 수집 주기는 해당 AWS 서비스에서 지원하는 기준을 적용합니다.
- Instance Refresh가 참조하는 ALB 정상 대상 수·ALB 5xx·API 5xx 경보 연결과 기존 자동 롤백 정책을 유지합니다. Instance Refresh는 연결한 경보의 상태를 읽으며, 교체 중 하나라도 `ALARM`이 되면 실패·자동 롤백을 판단합니다. 시작 시에는 연결한 경보가 모두 `OK`여야 합니다. [AWS Instance Refresh 롤백](https://docs.aws.amazon.com/autoscaling/ec2/userguide/instance-refresh-rollback.html)

### DSQL 지표와 경보

- RDS CPU·가용 메모리·가용 저장 공간·연결 수 경보와 RDS 인스턴스 식별자 참조를 제거합니다. RDS의 최대 연결 수를 입력받는 설정도 제거합니다.
- DSQL 관측 대상은 다음과 같이 구성합니다. 지표와 차원·단위는 AWS 정의를 따르고, 조회 통계는 관측 목적에 맞춰 설정합니다. [AWS DSQL CloudWatch 지표](https://docs.aws.amazon.com/aurora-dsql/latest/userguide/cloudwatch-monitoring.html)

| 관측 목적 | DSQL 지표 | 의미·측정 단위 |
| --- | --- | --- |
| 트랜잭션 처리량 | `ReadOnlyTransactions`, `TotalTransactions` | 읽기 전용·전체 트랜잭션 건수. 전체에는 읽기 전용도 포함 |
| 트랜잭션 시간 제한·동시성 충돌 | `QueryTimeouts`, `OccConflicts` | 최대 트랜잭션 시간 초과로 종료된 쿼리·낙관적 동시성 제어(OCC) 충돌로 중단된 트랜잭션 건수 |
| 커밋 지연 | `CommitLatency` | 쿼리 실행의 커밋 단계에서 소요된 시간의 중앙값(P50), 밀리초 |
| 읽기·쓰기 사용량 | `BytesRead`, `BytesWritten` | 저장소에서 읽거나 저장소에 쓴 데이터량, 바이트 |
| 연산 시간 | `ComputeTime` | 쿼리 처리기의 경과 시간, 밀리초 |
| 저장량 | `ClusterStorageSize` | 클러스터 저장량, 바이트 |
| DPU 사용량 | `ReadDPU`, `WriteDPU`, `ComputeDPU`, `TotalDPU` | 읽기·쓰기·연산·전체 처리 사용량의 근삿값. DPU(Distributed Processing Unit)는 처리 사용량을 정규화한 과금 단위 |

- 연결 수는 `AWS/Usage`의 `ResourceCount`를 사용합니다. 차원은 `Type=Resource`, `Resource=ClusterConnectionCount`, `ResourceId=cluster/<cluster-id>`, `Service=AuroraDSQL`입니다. DPU 사용량 지표의 `ResourceId=<cluster-id>`와 구분해 구성합니다. [AWS DSQL CloudWatch 지표](https://docs.aws.amazon.com/aurora-dsql/latest/userguide/cloudwatch-monitoring.html)
- 연결 수 경보는 기존 80% 이상·60초 평균·3회 연속 조건을 유지하되, 기준값을 RDS의 `max_connections`에서 해당 DSQL 클러스터에 적용된 연결 수 쿼터로 변경합니다. 기본 쿼터 10,000개를 적용하면 임계값은 8,000개이며, 쿼터 변경 시 임계값도 함께 조정합니다. [AWS DSQL 연결 수 쿼터](https://docs.aws.amazon.com/aurora-dsql/latest/userguide/CHAP_quotas.html)
- 시간 제한·동시성 충돌·커밋 지연·DPU 사용량은 우선 대시보드에서 관측하고, 추가 경보의 임계값은 운영 데이터를 바탕으로 정합니다.

### 로그와 보존 정책

- API 애플리케이션과 EC2 시스템 로그는 기존 journald 수집 경로와 `/arcamap/ec2/system` 로그 그룹을 유지합니다. 수집 경로가 연결되지 않은 `/arcamap/api/application` 로그 그룹은 제거합니다.
- RDS의 PostgreSQL·upgrade 로그 그룹은 제거합니다. API에서 발생한 DSQL 접속·쿼리 오류는 기존 서비스 로그에서 확인하며 IAM 인증 토큰은 로그에 기록하지 않습니다.
- 기존 EC2 서비스·ALB·Image Builder 로그 그룹의 보존 기간 30일과 API·CloudFront WAF 로그 그룹의 보존 기간 14일을 유지합니다.
- CloudWatch Agent의 ASG·인스턴스 차원과 기존 Image Builder 로그 수집 검사 경로를 유지합니다.

### 통합 대시보드와 경보 대응

- 기존 ASG·EC2·ALB·API·WAF 지표와 로그 조회를 유지하고, DSQL 트랜잭션·오류·커밋 지연·연결 수·저장량·DPU 사용량을 추가합니다.
- 대시보드 입력에 DSQL 클러스터 식별자와 DSQL 경보 ARN을 추가합니다. 클러스터 복구로 식별자가 바뀌면 관련 지표 차원과 대시보드 연결도 새 클러스터 기준으로 변경합니다.
- 로그 위젯의 시작 위치는 지표 위젯 행 수에 따라 계산해 DSQL 지표를 추가해도 겹치지 않도록 합니다. 기존 조회 범위 7일과 지표 위젯 주기 300초를 유지합니다.
- CloudFront WAF 지표·로그는 기존 `us-east-1` 조회를 유지하고, 서울 리전의 API·DSQL 관측 항목과 함께 표시합니다.
- ASG·ALB 대수 경보와 EC2 상태 검사·CPU·메모리 경보는 기존 `missing` 처리를 유지합니다. DSQL 연결 수 경보도 기존 DB 연결 수 경보와 동일하게 `missing`을 적용합니다. ALB·API 5xx 경보는 누락 데이터를 임계값 위반으로 보지 않는 `notBreaching`을 유지합니다.
- 대수 지표가 0으로 보고되고 평가 조건을 충족하면 `ALARM`이 됩니다. `missing`을 적용한 경보는 평가 범위의 데이터가 모두 누락되면 `INSUFFICIENT_DATA`가 됩니다. 데이터 부족은 정상·장애를 판단할 지표를 받지 못한 상태이며, 대수 지표가 0으로 보고된 경우와 구분합니다. [AWS 누락 데이터 처리](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/alarms-and-missing-data.html)
- 직접 구성한 운영 경보는 경보 작업을 활성화(`actions_enabled=true`)하고, `alarm_actions`·`ok_actions`·`insufficient_data_actions`에 SNS 토픽 ARN을 지정합니다. 각 설정은 경보 발생(`ALARM`)·경보 정상 상태 전환(`OK`)·데이터 부족(`INSUFFICIENT_DATA`) 시 알림을 전송합니다. [AWS 경보 작업과 SNS 알림 설정](https://docs.aws.amazon.com/AmazonCloudWatch/latest/APIReference/API_PutMetricAlarm.html)
- 운영자는 SNS에 연결한 수신 대상으로 상태 전환 알림을 받고 대시보드와 로그에서 원인을 확인합니다. `OK` 알림은 해당 경보의 정상 상태 전환을 의미합니다.

### 결과

- 이점: 기본 1대 운영에 맞는 대수 경보를 적용하고, ASG의 `InService` 대수나 ALB 노드가 보고한 정상 대상 수가 0으로 내려가 평가 조건을 충족하면 감지할 수 있습니다.
- 이점: API 상태와 DSQL의 처리·오류·지연·사용량을 통합 대시보드에서 함께 확인할 수 있습니다.
- 이점: RDS 전용 관측 설정과 수집되지 않는 API 로그 그룹을 제거하고 기존 로그 수집 경로와 보존 정책을 활용할 수 있습니다.
- 이점: 경보 발생·정상 전환·데이터 부족을 SNS로 전달해 운영자가 상태 변화를 알림으로 확인할 수 있습니다.
- 제약: 대수 지표가 모두 누락되면 0대 여부를 판정할 수 없으므로, `INSUFFICIENT_DATA`의 원인을 별도로 확인해야 합니다.
- 제약: SNS 토픽과 수신 대상의 구독 설정을 관리해야 합니다.
- 제약: CloudWatch 지표·로그·조회 비용은 수집량과 사용량에 따라 발생하므로 운영 중 실제 사용량을 확인해야 합니다.
