# API 인스턴스

`compute` 모듈은 API 인스턴스의 시작 템플릿과 Auto Scaling 그룹(ASG)을 구성합니다. 사설 서브넷 1개에 인스턴스를 배치하고 ALB 대상 그룹에 연결합니다. [API 환경](../../env/api/README.md)에서 사용합니다.

## 인스턴스 설정

| 항목 | 설정 |
|---|---|
| AMI | `image`로 입력한 이미지 |
| 인스턴스 유형 | `ec2_instance_type` |
| 루트 볼륨 | 암호화한 `gp3`, 인스턴스 종료 시 삭제 |
| 루트 볼륨 크기 | `ec2_root_volume_size`, 최소 20GiB이며 AMI 볼륨 크기 이상 |
| 공인 IP | 할당 비활성화 |
| 인스턴스 메타데이터 | IMDSv2 필수, 응답 홉 제한 1 |
| CPU 크레딧 | `unlimited` |
| IAM 인스턴스 프로파일 | `ec2_instance_profile_name` |

인스턴스 시작 시 입력한 CloudWatch Agent 시작 명령을 실행합니다.

## 용량과 자동 조정

ASG의 최소 용량은 1대이며 최대 용량은 `asg_max_size`로 지정합니다. 최대 용량은 2대 이상입니다. 상태 검사 유형의 기본값은 `ELB`입니다. 상태 검사 유예 시간과 기본 준비 시간은 각각 300초입니다.

| 조정 기준 | 지표 | 목표값 |
|---|---|---|
| CPU | `ASGAverageCPUUtilization` | `asg_cpu_target` |
| 메모리 | `CWAgent`의 `mem_used_percent`, ASG별 평균 | `asg_memory_target` |

두 정책 모두 목표 추적 방식으로 용량을 늘리거나 줄입니다. ASG는 실행 인스턴스 수와 목표 인스턴스 수 지표를 1분 간격으로 수집합니다.

## 인스턴스 교체

시작 템플릿의 새 버전을 ASG에 연결하고 Instance Refresh로 인스턴스를 순차 교체합니다.

| 항목 | 설정 |
|---|---|
| 최소 정상 비율 | 100% |
| 최대 정상 비율 | 200% |
| 인스턴스 준비 시간 | 300초 |
| 동일한 설정의 인스턴스 | 교체 생략 |
| 자동 롤백 | 활성화 |
| 감시 경보 | `instance_refresh_alarm_names`에 지정한 1~10개 경보 |

## 입력과 출력

[variables.tf](variables.tf)에 네트워크, 이미지, IAM, 용량과 교체 설정을 정의합니다.

| 출력 | 내용 |
|---|---|
| `autoscaling_group` | ASG 이름과 ARN |
| `launch_template` | 시작 템플릿 ID·버전과 AMI ID |

출력 구조는 [outputs.tf](outputs.tf)에 정의합니다.
