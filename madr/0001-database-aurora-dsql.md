# 데이터베이스 선택 — Aurora DSQL

## 배경과 문제

### 배경

- 1차 운영에서 RDS PostgreSQL Multi-AZ를 포함한 이중화 인프라를 일주일간 운영했습니다.
- 이번 재구성의 목표는 '단일 구성 운영 기반'의 성능 효율성, 지속 가능성, 비용 최적화, 보안을 고려하여 구성하고 , 운영 우수성과 신뢰성(EC2 서버 운영 능력)을 기르는 것입니다.
- 고가용성 구조를 단일 운영 구조로 재편하면서, 성능 효율성·지속 가능성·비용 최적화·보안을 충족하도록 구성하는 것이 목표입니다.
- ‘단일 구성’이라는 이유로 운영에 필요한 서비스나 기능을 일괄 제외해서는 안 됩니다. 각 구성요소가 어떤 역할을 하는지, 단일 구성에서도 필요한지, 네 가지 기준에 어떤 영향을 주는지를 근거로 채택 여부를 판단해야 합니다.

### 문제

1차 운영에서 DB의 평균 CPU 사용률은 5.23%였고, RDS 비용은 전체 사용료의 44.71%를 차지했습니다. 관측된 부하에 비해 상시 인스턴스 유지 비용의 비중이 컸습니다.

| 항목 | 1차 운영 관측값 |
|---|---:|
| 7일 전체 추정 사용료 | 79.02달러 |
| RDS 추정 사용료 | 35.33달러 |
| RDS Multi-AZ 실행료 | 34.10달러·168시간 |
| RDS CPU 사용률 | 평균 5.23%·최대 29.34% |

RDS 비용의 대부분이 주·대기 인스턴스 실행에서 발생했으므로, 지속적인 운영을 위해 DB의 상시 실행 비용을 줄일 필요가 있습니다.

## 검토한 대안

| 대안 | 비용 구조 | DB 호스트 관리 |
|---|---|---|
| RDS PostgreSQL Multi-AZ 유지 | 주·대기 인스턴스 실행료와 저장 비용 | AWS가 담당 |
| 소형 RDS PostgreSQL Single-AZ | 단일 인스턴스 실행료와 저장 비용 | AWS가 담당 |
| EC2에 PostgreSQL 직접 운영 | EC2 실행료와 저장 비용 | 설치·패치·백업·복구를 직접 담당 |
| Aurora DSQL | DB 활동량과 저장량에 따른 과금 | AWS가 담당 |

과금 기준: [RDS PostgreSQL 요금](https://aws.amazon.com/rds/postgresql/pricing/), [Aurora DSQL 요금](https://aws.amazon.com/rds/aurora/dsql/pricing/).

## 결정과 이유

**선택: Aurora DSQL**

- **상시 DB 인스턴스 실행료 제거:** 상시 DB 인스턴스 실행료를 제거하고 DB 활동량과 저장량에 따른 과금 방식을 선택합니다. 전체 운영비에는 PrivateLink 비용도 포함됩니다. [DSQL 과금 기준](https://aws.amazon.com/rds/aurora/dsql/pricing/)
- **1차 운영 경험 반영:** 낮은 평균 CPU 사용률에서 누적된 Multi-AZ 실행료가 주요 비용 부담이었습니다. 인스턴스의 상시 실행 비용을 줄이는 방향으로 DB를 재구성합니다.
- **아키텍처·서버 운영 역량:** DB 호스트 관리는 AWS에 맡기고, EC2 서버의 구성·배포·모니터링·장애 대응과 서비스 간 연결·접근 권한 관리에 집중합니다.

### 결과

- **이점:** 상시 DB 인스턴스 실행료를 제거하고 사용량에 따라 DB 비용을 조정할 수 있습니다.
- **이점:** EC2에 PostgreSQL을 직접 운영하는 대안과 비교해 DB 호스트 관리 부담을 줄이고, EC2 애플리케이션 서버 운영에 집중할 수 있습니다.
- **제약:** 월 무료 제공량인 100,000 DPU와 1 GB-month를 초과한 사용량에 처리료·저장료가 발생합니다. EC2와 DSQL을 사설로 연결하는 VPC Interface Endpoint의 유지료·처리료는 별도로 발생합니다. [DSQL 요금](https://aws.amazon.com/rds/aurora/dsql/pricing/)
- **제약:** 기존 스키마·접속 코드·적재 코드를 DSQL에 맞춰 수정해야 합니다. 현재 `preservation_type`의 `text[]`는 지원하는 저장 형식으로 바꾸고, 데이터의 값·ID·연결 관계를 보존해야 합니다. [기존 스키마](../app/data/migrations/001_places.sql), [DSQL 자료형 지원 범위](https://docs.aws.amazon.com/aurora-dsql/latest/userguide/working-with-postgresql-compatibility-supported-data-types.html)
