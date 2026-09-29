# Compute(API 인스턴스 운영)

**AMI로 API 인스턴스를 실행하고 확장·교체하는 구성**

시작 템플릿에는 API 서버의 실행 환경을 정의하고 Auto Scaling Group은 이 환경에서 실행할 인스턴스를 관리합니다. 서버를 두 가용 영역의 프라이빗 서브넷에 배치하며 CPU 부하에 따라 처리 용량을 조절합니다.

## 1. Compute Architecture(컴퓨팅 구성)

| 배치 | 인스턴스 수 | CPU 확장 목표 | 이미지 기반 |
|:---:|:---:|:---:|:---:|
| 두 가용 영역 | 2~4대 | 50% | AMI |

- **시작 템플릿** — AMI와 인스턴스 실행 설정을 묶어 서버를 생성할 때 사용합니다.

- **Auto Scaling Group** — 인스턴스 수를 유지하고 비정상 인스턴스를 교체합니다.

- **용량 조절** — 평균 CPU 사용률을 기준으로 인스턴스를 늘리거나 줄입니다.

## 2. Instance Lifecycle(인스턴스 수명 주기)

1. 시작 템플릿의 AMI와 실행 설정을 사용하여 인스턴스를 생성합니다.
2. API 서버가 ALB의 대상 그룹을 통해 요청을 처리합니다.
3. 부하와 상태에 따라 인스턴스 수를 조절하거나 비정상 인스턴스를 교체합니다.
4. 새 AMI가 반영되면 Instance Refresh로 서버를 교체합니다.

## 3. Operational Criteria and Constraints(운영 기준 및 제약)

- **장애 대응** — EC2 상태 검사·ALB 헬스 체크를 기준으로 인스턴스 상태를 판단합니다.

- **확장 범위** — API 인스턴스는 평균 CPU 50%를 목표로 2~4대 범위에서 운영합니다.

### 제약 조건

> **교체 정책**: Instance Refresh가 최소 정상 비율 100%, 최대 용량 비율 200%로 새 서버를 먼저 준비한 뒤 기존 서버를 종료하도록 구성했습니다. AWS 적용 및 무중단 검증은 아직 수행하지 않았습니다.

## 코드 위치

| 파일 | 역할 |
|---|---|
| [main.tf](main.tf) | Auto Scaling 그룹·인스턴스 교체 |
| [launch-template.tf](launch-template.tf) | AMI·EBS·IMDSv2·EC2 시작 설정 |
| [scaling.tf](scaling.tf) | CPU·메모리 목표 추적 정책 |
| [moved.tf](moved.tf) | 이전 인덱스 주소와의 상태 호환 선언 |
