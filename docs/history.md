# 클라우드 작업 이력

시각: KST

| 날짜 | 수행 작업 | 결과 |
|---|---|---|
| 2026-09-05 | AWS 서비스 구성 설계 | S3·CloudFront·ALB·EC2·RDS·로그·경보 구성 정의 |
| 2026-09-07 | 초기 Terraform 구성 작성 | 네트워크·스토리지·DB·컴퓨트·출력 구성 작성 |
| 2026-09-09 | Terraform 모듈화 | 공통 모듈 10개, app·db·was·web 독립 루트 4개로 분리 |
| 2026-09-09 | 기반 AMI 자동 조회 적용 | Canonical Ubuntu 26.04 x86_64의 서울 리전 최신 이미지 조회 |
| 2026-09-13 | 웹의 운영 API 주소 반영 | `https://api.arcamap.app`을 빌드 입력으로 지정 |
| 2026-09-13 | API CORS 설정 | `https://arcamap.app` 출처의 GET 허용 |
| 2026-09-13 | 서비스 DNS 생성 구성 | CloudFront·ALB 별칭 레코드, DNS 계정의 AssumeRole 반영 |
| 2026-09-13 | WAS 실제 plan 실행 | app·db 적용 전 VPC·RDS 조회 실패, 선행 자원 부재 확인 |
| 2026-09-13 | EC2 역할·프로파일 구성 | 운영 EC2와 Image Builder의 역할·프로파일 분리 |
| 2026-09-13 | 초기 ASG 상태 검사 구성 | API 설치 전 EC2 검사 사용, 설치 후 ELB 전환 방식 적용 |
| 2026-09-14 | WAS의 RDS 포트 참조 수정 | `db_instance_port` 대신 `port` 사용, 접속 포트 5432 반영 |
| 2026-09-14 | CloudWatch Agent 원본 경로 수정 | 파일명을 `arcamap-cloudwatch-agent.json`으로 변경하여 재적용 시 파일 누락 해소 |
| 2026-09-14 | 수정한 Image Builder 구성 적용 | 이미지 생성 18분 1초 후 완료, 시작 템플릿 생성 완료 |
| 2026-09-14 | ASG 생성 실패 진단 | 역할 사용 거부 후 자동 재시도로 EC2 2대 복구, state에 tainted 잔존. 후속 해제 결과 기록 없음 |
| 2026-09-14 | 기존 EC2 2대에 API 수동 배포 | systemd 서비스·DB 인증·CA 배치 |
| 2026-09-15 | 운영 장소 스키마 적용 | 01:31:24에 `001_places` 적용 |
| 2026-09-15 | 보존목록 구조 적용 | `002_collections`, 장소 참조 외래 키 생성 |
| 2026-09-15 | 운영 CSV 적재 | 장소 50건·보존목록 9건 커밋, 기존 행 삭제 0건 |
