# Review Checklist(공식 질문·모범 사례 검토 목록)

**📋 공식 질문·모범 사례를 기준으로 6개 제출 문서를 검토하는 기록**

AWS MCP로 조회한 공식 Appendix 목차의 질문·모범 사례 ID, 명칭, 링크를 그대로 기입합니다. 확인란은 제출 문서 검토의 진행 상태를 나타내며 AWS 구성의 충족 여부와는 구분합니다.

## 1. Review Scope(검토 범위)

- **공식 기준**: [Appendix: Questions and best practices](https://docs.aws.amazon.com/wellarchitected/latest/framework/appendix.html), [공식 전체 목차](https://docs.aws.amazon.com/wellarchitected/latest/framework/toc-contents.json)
- **조회일**: 2026-09-22 KST
- **대상**: 기둥별 제출 문서 6개와 [작성 가이드](guide.md)
- **검토 항목**: 공식 질문·BP의 기재 여부, 기준·현재 상태·근거·판정·사유, 목차·스타일, 1번과 4번의 구분, 문서 간 일관성
- **확인란**: `[ ]` 미검토. 보완이 필요한 항목은 검토 기록에 사유를 남깁니다.

| 기둥 | 질문 | 모범 사례 | 제출 문서 |
|---|---:|---:|---|
| 운영 우수성 | 11 | 68 | [01-operational-excellence.md](01-operational-excellence.md) |
| 보안 | 11 | 63 | [02-security.md](02-security.md) |
| 신뢰성 | 13 | 65 | [03-reliability.md](03-reliability.md) |
| 성능 효율성 | 5 | 32 | [04-performance-efficiency.md](04-performance-efficiency.md) |
| 비용 최적화 | 11 | 50 | [05-cost-optimization.md](05-cost-optimization.md) |
| 지속 가능성 | 6 | 29 | [06-sustainability.md](06-sustainability.md) |

## 2. Review Results(검토 결과)

### 2.1 Submission Review(제출 문서 검토)

공식 질문 57개와 모범 사례 307개가 6개 제출 문서에 모두 기재되어 있습니다. 제출 문서의 ID·명칭·공식 링크에서 누락·중복·불일치를 발견하지 못했으며, 로컬 파일 링크와 지정된 줄 위치의 대상도 존재합니다. 각 문서는 공통 5개 목차와 운영 현황의 3개 하위 항목을 갖추고 있습니다.

제출 문서에 기록된 AWS MCP 조회 범위·시점·응답 사실과 Terraform 참조를 판정 사유에 대조했습니다. 조직 절차, 조회 권한 부족, 관측 기간 밖의 상황처럼 근거가 부족한 사항은 확인 불가로 남겨야 합니다. 아래의 보완 요청은 문서의 판정·표현에 관한 것이며 AWS 리소스 개선 완료를 뜻하지 않습니다.

| 문서 | 목록·구조·링크 | 보완 대상 | 상태 |
|---|---|---|---|
| [01-operational-excellence.md](01-operational-excellence.md) | 확인 완료 | R01·R02 | 보완·재확인 완료 |
| [02-security.md](02-security.md) | 확인 완료 | R03 | 보완·재확인 완료 |
| [03-reliability.md](03-reliability.md) | 확인 완료 | R04 | 보완·재확인 완료 |
| [04-performance-efficiency.md](04-performance-efficiency.md) | 확인 완료 | R05 | 보완·재확인 완료 |
| [05-cost-optimization.md](05-cost-optimization.md) | 확인 완료 | R06·R07 | 보완·재확인 완료 |
| [06-sustainability.md](06-sustainability.md) | 확인 완료 | R08 | 보완·재확인 완료 |

### 2.2 Correction Requests(보완 요청)

| 번호 | 문서·대상 | 확인한 문제 | 요청 사항 | 보완 결과 |
|---|---|---|---|---|
| R01 | [01-operational-excellence.md](01-operational-excellence.md) · OPS05-BP01·OPS05-BP06·OPS11-BP04 | 버전 관리·설계 기준 공유·지식 관리에서 확인된 구현과 미확인 운영 절차를 구분해야 합니다. README의 존재만으로 설계 기준의 지속적인 갱신·공유까지 충족했다고 판단할 근거는 부족합니다. | 기존 근거로 입증되는 범위를 명시하고, 확인된 부족 없이 남은 요구 사항만 미확인인 경우 가이드에 따라 확인 불가로 수정합니다. 관련 질문 요약도 맞춥니다. | 완료 · OPS05-BP01·OPS05-BP06·OPS11-BP04를 확인 불가로 수정했습니다. OPS11 질문과 집계·결론도 일치합니다. |
| R02 | [01-operational-excellence.md](01-operational-excellence.md) · 1.3과 4번 | 1.3에 X-Ray 조회 구간의 0건 결과와 업그레이드 로그 storedBytes=0이라는 실제 관측값이 포함되어 있습니다. | 1.3에는 수집 대상·경로·보존·수집 상태를 남기고, 조회 기간과 실제 결과는 4번의 관련 기록으로 이동합니다. | 완료 · X-Ray의 조회 기간·0건 결과와 업그레이드 로그 저장량 0 기록을 4.5에 두고 1.3은 수집 구성·범위로 정리했습니다. |
| R03 | [02-security.md](02-security.md) · SEC01-BP01 | 공식 기준은 서로 관련 없는 워크로드·환경과 클라우드 운영의 격리입니다. 현재 기준 문장은 API·빌드·보안 구성 요소를 각각 계정으로 분리해야 하는 것으로 읽힐 수 있습니다. | 공식 기준에 맞게 요구 사항을 수정하고, 실제 확인한 계정 격리 부족과 조사하지 않은 환경을 구분해 판정 사유를 보완합니다. 동일 워크로드 구성 요소의 동거만으로 미충족을 단정하지 않습니다. | 완료 · 공식 격리 대상을 명시하고 SEC01-BP01을 확인 불가로 수정했습니다. 계정 동거만으로 결함을 단정한 질문 요약·결론도 수정했습니다. |
| R04 | [03-reliability.md](03-reliability.md) · REL13-BP04 | 상시 DR EC2·ASG·RDS를 발견하지 못한 사실만으로 해당 없음으로 분류했습니다. 같은 문서에서 DR 전략은 확인 불가이므로 필요 시 생성하는 복구 환경까지 적용 제외할 근거가 부족합니다. | DR 전략·복구 대상 환경의 적용 범위를 입증할 기존 근거가 없다면 확인 불가로 수정하고, 질문 요약·집계가 있으면 함께 맞춥니다. | 완료 · REL13-BP04를 해당 없음에서 확인 불가로 수정하고, 상시 리소스 부재와 필요 시 생성하는 DR 환경을 구분했습니다. |
| R05 | [04-performance-efficiency.md](04-performance-efficiency.md) · PERF03-BP01·PERF04-BP02·PERF04-BP05·PERF05-BP01·PERF05-BP06 | 저장소·네트워크 기능·프로토콜·자원 경보·교체 이력의 존재와, 적합성 평가·업무 KPI·정기 업데이트 절차의 미확인이 혼재되어 있습니다. 부분 충족의 사유에서 확인된 부족이 분명하지 않습니다. | 각 BP에서 입증된 구현, 확인된 결함, 미확인 절차를 분리합니다. 확인된 부족 없이 절차·선택 근거만 미확인인 항목은 확인 불가로 수정하고 관련 질문 요약을 맞춥니다. | 완료 · 지정한 5개 BP를 확인 불가로 수정하고 관련 질문 요약·집계·결론에서 확인된 구성과 미확인 평가 절차를 구분했습니다. |
| R06 | [05-cost-optimization.md](05-cost-optimization.md) · COST01-BP05·COST02-BP02 | 이상 비용 알림과 자원 상한은 확인되었으나 정기 최적화 보고·비용과 사용량의 목표는 미확인입니다. 이를 부분 충족으로 분류한 사유에 확인된 부족이 구체적으로 제시되지 않았습니다. | 알림 구성과 미확인 보고 체계, 자원 한도와 비용·사용 목표를 구분하고 가이드의 판정 기준을 적용합니다. 관련 질문 요약도 맞춥니다. | 완료 · COST01-BP05·COST02-BP02를 확인 불가로 수정했습니다. 알림·자원 한도와 정기 보고·비용 목표를 구분하고 요약·집계·결론을 맞췄습니다. |
| R07 | [05-cost-optimization.md](05-cost-optimization.md) · 1.3과 4번 | 1.3에 2026년 8월 비용 조회 합계 0이라는 실제 조회 결과가 포함되어 있습니다. | 비용 자료의 수집 범위·비교 한계 설명은 유지하되, 8월 합계와 그 해석은 4.1의 실제 비용 기록으로 옮깁니다. | 완료 · 8월 비용 합계 0과 해석을 4.1로 이동하고 1.3에는 자료 수집 범위와 비교 한계 안내를 남겼습니다. |
| R08 | [06-sustainability.md](06-sustainability.md) · SUS02-BP04·SUS03-BP05·SUS04-BP02 | 배치·저장소 분리·캐시·STANDARD 사용은 확인했지만 지리별 수요와 실제 데이터 접근 특성은 미확인입니다. 계층 전환이 필요한지 확인하지 못한 상태에서 정책 부재를 부족으로 판단할 수 없습니다. | 기존 관측 공백과 구현 부적합을 구분합니다. 요구에 맞지 않는 구성이라는 근거가 없다면 해당 BP는 확인 불가로 조정하고 질문 요약을 맞춥니다. | 완료 · 지정한 3개 BP를 확인 불가로 수정했습니다. SUS 3 질문·집계·결론을 맞추고 관측 공백을 구성 결함으로 단정한 사유를 정정했습니다. |

### 2.3 Cross-document Consistency(문서 간 일관성)

- 배포 중 정상 대상 수 0, 서비스 경보 9개의 작업 비활성화, RDS·NAT 비용과 로그 수집 구성은 제출 문서 사이에서 서로 부합합니다. 정상 대상 수 0이라는 분 단위 지표를 연속 장애 시간이나 사용자 피해로 단정하지 않은 점도 확인했습니다.
- 지속 가능성 문서의 집계 구간은 9월 14일 00:00~21일 00:00 UTC이며, 다른 문서의 주요 집계 구간은 9월 14일 18:00~21일 18:00 UTC입니다. 요청 수·최댓값 차이는 서로 다른 기간의 값이므로 불일치로 분류하지 않습니다.
- 배포 전후의 요청 수는 문서별 조회 구간이 다릅니다. 각 문서에 표시된 기간과 통계 단위를 함께 읽어야 합니다.
- 전용 API 로그 그룹의 수집 공백과 시스템 로그에 포함된 애플리케이션 기록은 구분되어 있습니다. 전용 그룹의 자료 부족이 모든 애플리케이션 로그의 부재를 뜻하지 않습니다.
- CloudFront·ALB의 기존 로그 옵션과 별도 로그 전달 설정을 구분하고, 반환된 객체·로그 건수의 조회 한계를 표시한 점을 확인했습니다.
- 업무 KPI와 갱신·검증 절차의 근거 부족을 다르게 판정한 부분은 R01·R05·R06·R08에서 보완했으며, 근거가 부족한 항목을 확인 불가로 구분했습니다.

### 2.4 Final Review Status(최종 검토 상태)

문서별 보완 요청 8건을 모두 반영하고 요청한 BP 15개와 직접 관련된 질문 요약·집계·결론을 재확인했습니다. 보완 전후 BP 행을 비교한 결과 지정한 BP 외의 평가 행은 변경되지 않았습니다. 운영 현황에서 분리하도록 요청한 실제 관측 기록도 4번에 반영됐습니다.

| 문서 | 충족 | 부분 충족 | 미충족 | 해당 없음 | 확인 불가 | 합계 |
|---|---:|---:|---:|---:|---:|---:|
| [운영 우수성](01-operational-excellence.md) | 1 | 11 | 1 | 0 | 55 | 68 |
| [보안](02-security.md) | 2 | 20 | 3 | 1 | 37 | 63 |
| [신뢰성](03-reliability.md) | 11 | 10 | 2 | 2 | 40 | 65 |
| [성능 효율성](04-performance-efficiency.md) | 1 | 10 | 0 | 2 | 19 | 32 |
| [비용 최적화](05-cost-optimization.md) | 5 | 9 | 1 | 1 | 34 | 50 |
| [지속 가능성](06-sustainability.md) | 3 | 6 | 0 | 1 | 19 | 29 |
| **합계** | **23** | **66** | **7** | **7** | **204** | **307** |

**남은 확인 사항**: 업무 KPI·SLA·RTO/RPO, 조직 책임과 운영 절차, 비공개 애플리케이션과 외부 도구, 부하·복구·갱신 시험 기록, 실제 데이터 접근과 사용자 분포 등의 추가 근거가 필요합니다. 확인 불가 204개는 미구현 항목이나 결함 수가 아닙니다. 문서 작성·보완의 완료와 실제 AWS 개선의 완료는 구분합니다.

## 3. Operational Excellence(운영 우수성)

[공식 질문·모범 사례](https://docs.aws.amazon.com/wellarchitected/latest/framework/a-operational-excellence.html) · [제출 문서](01-operational-excellence.md)

### 3.1 OPS 1. How do you determine what your priorities are?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops-01.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [OPS01-BP01 Evaluate external customer needs](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_priorities_ext_cust_needs.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS01-BP02 Evaluate internal customer needs](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_priorities_int_cust_needs.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS01-BP03 Evaluate governance requirements](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_priorities_governance_reqs.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS01-BP04 Evaluate compliance requirements](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_priorities_compliance_reqs.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS01-BP05 Evaluate threat landscape](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_priorities_eval_threat_landscape.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS01-BP06 Evaluate tradeoffs while managing benefits and risks](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_priorities_eval_tradeoffs.html) | 기재·근거·판정 사유 대조 완료 |

### 3.2 OPS 2. How do you structure your organization to support your business outcomes?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops-02.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [OPS02-BP01 Resources have identified owners](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_ops_model_def_resource_owners.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS02-BP02 Processes and procedures have identified owners](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_ops_model_def_proc_owners.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS02-BP03 Operations activities have identified owners responsible for their performance](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_ops_model_def_activity_owners.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS02-BP04 Mechanisms exist to manage responsibilities and ownership](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_ops_model_def_responsibilities_ownership.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS02-BP05 Mechanisms exist to request additions, changes, and exceptions](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_ops_model_req_add_chg_exception.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS02-BP06 Responsibilities between teams are predefined or negotiated](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_ops_model_def_neg_team_agreements.html) | 기재·근거·판정 사유 대조 완료 |

### 3.3 OPS 3. How does your organizational culture support your business outcomes?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops-03.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [OPS03-BP01 Provide executive sponsorship](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_org_culture_executive_sponsor.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS03-BP02 Team members are empowered to take action when outcomes are at risk](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_org_culture_team_emp_take_action.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS03-BP03 Escalation is encouraged](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_org_culture_team_enc_escalation.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS03-BP04 Communications are timely, clear, and actionable](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_org_culture_effective_comms.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS03-BP05 Experimentation is encouraged](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_org_culture_team_enc_experiment.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS03-BP06 Team members are encouraged to maintain and grow their skill sets](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_org_culture_team_enc_learn.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS03-BP07 Resource teams appropriately](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_org_culture_team_res_appro.html) | 기재·근거·판정 사유 대조 완료 |

### 3.4 OPS 4. How do you implement observability in your workload?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops-04.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [OPS04-BP01 Identify key performance indicators](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_observability_identify_kpis.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS04-BP02 Implement application telemetry](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_observability_application_telemetry.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS04-BP03 Implement user experience telemetry](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_observability_customer_telemetry.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS04-BP04 Implement dependency telemetry](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_observability_dependency_telemetry.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS04-BP05 Implement distributed tracing](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_observability_dist_trace.html) | 기재·근거·판정 사유 대조 완료 |

### 3.5 OPS 5. How do you reduce defects, ease remediation, and improve flow into production?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops-05.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [OPS05-BP01 Use version control](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_dev_integ_version_control.html) | R01 · 보완 완료, 판정·사유 재확인 |
| [ ] | [OPS05-BP02 Test and validate changes](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_dev_integ_test_val_chg.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS05-BP03 Use configuration management systems](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_dev_integ_conf_mgmt_sys.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS05-BP04 Use build and deployment management systems](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_dev_integ_build_mgmt_sys.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS05-BP05 Perform patch management](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_dev_integ_patch_mgmt.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS05-BP06 Share design standards](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_dev_integ_share_design_stds.html) | R01 · 보완 완료, 판정·사유 재확인 |
| [ ] | [OPS05-BP07 Implement practices to improve code quality](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_dev_integ_code_quality.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS05-BP08 Use multiple environments](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_dev_integ_multi_env.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS05-BP09 Make frequent, small, reversible changes](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_dev_integ_freq_sm_rev_chg.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS05-BP10 Fully automate integration and deployment](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_dev_integ_auto_integ_deploy.html) | 기재·근거·판정 사유 대조 완료 |

### 3.6 OPS 6. How do you mitigate deployment risks?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops-06.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [OPS06-BP01 Plan for unsuccessful changes](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_mit_deploy_risks_plan_for_unsucessful_changes.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS06-BP02 Test deployments](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_mit_deploy_risks_test_val_chg.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS06-BP03 Employ safe deployment strategies](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_mit_deploy_risks_deploy_mgmt_sys.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS06-BP04 Automate testing and rollback](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_mit_deploy_risks_auto_testing_and_rollback.html) | 기재·근거·판정 사유 대조 완료 |

### 3.7 OPS 7. How do you know that you are ready to support a workload?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops-07.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [OPS07-BP01 Ensure personnel capability](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_ready_to_support_personnel_capability.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS07-BP02: Ensure a consistent review of operational readiness](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_ready_to_support_const_orr.html) | — |
| [ ] | [OPS07-BP03 Use runbooks to perform procedures](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_ready_to_support_use_runbooks.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS07-BP04 Use playbooks to investigate issues](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_ready_to_support_use_playbooks.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS07-BP05 Make informed decisions to deploy systems and changes](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_ready_to_support_informed_deploy_decisions.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS07-BP06 Create support plans for production workloads](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_ready_to_support_enable_support_plans.html) | 기재·근거·판정 사유 대조 완료 |

### 3.8 OPS 8. How do you utilize workload observability in your organization?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops-08.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [OPS08-BP01 Analyze workload metrics](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_workload_observability_analyze_workload_metrics.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS08-BP02 Analyze workload logs](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_workload_observability_analyze_workload_logs.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS08-BP03 Analyze workload traces](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_workload_observability_analyze_workload_traces.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS08-BP04 Create actionable alerts](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_workload_observability_create_alerts.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS08-BP05 Create dashboards](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_workload_observability_create_dashboards.html) | 기재·근거·판정 사유 대조 완료 |

### 3.9 OPS 9. How do you understand the health of your operations?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops-09.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [OPS09-BP01 Measure operations goals and KPIs with metrics](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_operations_health_measure_ops_goals_kpis.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS09-BP02 Communicate status and trends to ensure visibility into operation](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_operations_health_communicate_status_trends.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS09-BP03 Review operations metrics and prioritize improvement](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_operations_health_review_ops_metrics_prioritize_improvement.html) | 기재·근거·판정 사유 대조 완료 |

### 3.10 OPS 10. How do you manage workload and operations events?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops-10.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [OPS10-BP01 Use a process for event, incident, and problem management](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_event_response_event_incident_problem_process.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS10-BP02 Have a process per alert](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_event_response_process_per_alert.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS10-BP03 Prioritize operational events based on business impact](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_event_response_prioritize_events.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS10-BP04 Define escalation paths](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_event_response_define_escalation_paths.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS10-BP05 Define a customer communication plan for service-impacting events](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_event_response_push_notify.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS10-BP06 Communicate status through dashboards](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_event_response_dashboards.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS10-BP07 Automate responses to events](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_event_response_auto_event_response.html) | 기재·근거·판정 사유 대조 완료 |

### 3.11 OPS 11. How do you evolve operations?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops-11.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [OPS11-BP01 Have a process for continuous improvement](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_evolve_ops_process_cont_imp.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS11-BP02 Perform post-incident analysis](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_evolve_ops_perform_rca_process.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS11-BP03 Implement feedback loops](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_evolve_ops_feedback_loops.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS11-BP04 Perform knowledge management](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_evolve_ops_knowledge_management.html) | R01 · 보완 완료, 판정·사유 재확인 |
| [ ] | [OPS11-BP05 Define drivers for improvement](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_evolve_ops_drivers_for_imp.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS11-BP06 Validate insights](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_evolve_ops_validate_insights.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS11-BP07 Perform operations metrics reviews](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_evolve_ops_metrics_review.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS11-BP08 Document and share lessons learned](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_evolve_ops_share_lessons_learned.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [OPS11-BP09 Allocate time to make improvements](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_evolve_ops_allocate_time_for_imp.html) | 기재·근거·판정 사유 대조 완료 |

## 4. Security(보안)

[공식 질문·모범 사례](https://docs.aws.amazon.com/wellarchitected/latest/framework/a-security.html) · [제출 문서](02-security.md)

### 4.1 SEC 1. How do you securely operate your workload?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec-01.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [SEC01-BP01 Separate workloads using accounts](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_securely_operate_multi_accounts.html) | R03 · 보완 완료, 판정·사유 재확인 |
| [ ] | [SEC01-BP02 Secure account root user and properties](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_securely_operate_aws_account.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC01-BP03 Identify and validate control objectives](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_securely_operate_control_objectives.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC01-BP04 Stay up to date with security threats and recommendations](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_securely_operate_updated_threats.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC01-BP05 Reduce security management scope](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_securely_operate_reduce_management_scope.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC01-BP06 Automate deployment of standard security controls](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_securely_operate_automate_security_controls.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC01-BP07 Identify threats and prioritize mitigations using a threat model](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_securely_operate_threat_model.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC01-BP08 Evaluate and implement new security services and features regularly](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_securely_operate_implement_services_features.html) | 기재·근거·판정 사유 대조 완료 |

### 4.2 SEC 2. How do you manage authentication for people and machines?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec-02.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [SEC02-BP01 Use strong sign-in mechanisms](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_identities_enforce_mechanisms.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC02-BP02 Use temporary credentials](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_identities_unique.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC02-BP03 Store and use secrets securely](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_identities_secrets.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC02-BP04 Rely on a centralized identity provider](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_identities_identity_provider.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC02-BP05 Audit and rotate credentials periodically](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_identities_audit.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC02-BP06 Employ user groups and attributes](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_identities_groups_attributes.html) | 기재·근거·판정 사유 대조 완료 |

### 4.3 SEC 3. How do you manage permissions for people and machines?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec-03.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [SEC03-BP01 Define access requirements](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_permissions_define.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC03-BP02 Grant least privilege access](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_permissions_least_privileges.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC03-BP03 Establish emergency access process](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_permissions_emergency_process.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC03-BP04 Reduce permissions continuously](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_permissions_continuous_reduction.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC03-BP05 Define permission guardrails for your organization](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_permissions_define_guardrails.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC03-BP06 Manage access based on lifecycle](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_permissions_lifecycle.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC03-BP07 Analyze public and cross-account access](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_permissions_analyze_cross_account.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC03-BP08 Share resources securely within your organization](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_permissions_share_securely.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC03-BP09 Share resources securely with a third party](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_permissions_share_securely_third_party.html) | 기재·근거·판정 사유 대조 완료 |

### 4.4 SEC 4. How do you detect and investigate security events?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec-04.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [SEC04-BP01 Configure service and application logging](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_detect_investigate_events_app_service_logging.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC04-BP02 Capture logs, findings, and metrics in standardized locations](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_detect_investigate_events_logs.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC04-BP03 Correlate and enrich security alerts](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_detect_investigate_events_security_alerts.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC04-BP04 Initiate remediation for non-compliant resources](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_detect_investigate_events_noncompliant_resources.html) | 기재·근거·판정 사유 대조 완료 |

### 4.5 SEC 5. How do you protect your network resources?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec-05.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [SEC05-BP01 Create network layers](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_network_protection_create_layers.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC05-BP02 Control traffic flow within your network layers](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_network_protection_layered.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC05-BP03 Implement inspection-based protection](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_network_protection_inspection.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC05-BP04 Automate network protection](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_network_auto_protect.html) | 기재·근거·판정 사유 대조 완료 |

### 4.6 SEC 6. How do you protect your compute resources?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec-06.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [SEC06-BP01 Perform vulnerability management](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_protect_compute_vulnerability_management.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC06-BP02 Provision compute from hardened images](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_protect_compute_hardened_images.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC06-BP03 Reduce manual management and interactive access](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_protect_compute_reduce_manual_management.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC06-BP04 Validate software integrity](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_protect_compute_validate_software_integrity.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC06-BP05 Automate compute protection](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_protect_compute_auto_protection.html) | 기재·근거·판정 사유 대조 완료 |

### 4.7 SEC 7. How do you classify your data?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec-07.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [SEC07-BP01 Understand your data classification scheme](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_data_classification_identify_data.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC07-BP02 Apply data protection controls based on data sensitivity](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_data_classification_define_protection.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC07-BP03 Automate identification and classification](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_data_classification_auto_classification.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC07-BP04 Define scalable data lifecycle management](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_data_classification_lifecycle_management.html) | 기재·근거·판정 사유 대조 완료 |

### 4.8 SEC 8. How do you protect your data at rest?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec-08.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [SEC08-BP01 Implement secure key management](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_protect_data_rest_key_mgmt.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC08-BP02 Enforce encryption at rest](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_protect_data_rest_encrypt.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC08-BP03 Automate data at rest protection](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_protect_data_rest_automate_protection.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC08-BP04 Enforce access control](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_protect_data_rest_access_control.html) | 기재·근거·판정 사유 대조 완료 |

### 4.9 SEC 9. How do you protect your data in transit?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec-09.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [SEC09-BP01 Implement secure key and certificate management](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_protect_data_transit_key_cert_mgmt.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC09-BP02 Enforce encryption in transit](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_protect_data_transit_encrypt.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC09-BP03 Authenticate network communications](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_protect_data_transit_authentication.html) | 기재·근거·판정 사유 대조 완료 |

### 4.10 SEC 10. How do you anticipate, respond to, and recover from incidents?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec-10.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [SEC10-BP01 Identify key personnel and external resources](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_incident_response_identify_personnel.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC10-BP02 Develop incident management plans](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_incident_response_develop_management_plans.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC10-BP03 Prepare forensic capabilities](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_incident_response_prepare_forensic.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC10-BP04 Develop and test security incident response playbooks](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_incident_response_playbooks.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC10-BP05 Pre-provision access](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_incident_response_pre_provision_access.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC10-BP06 Pre-deploy tools](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_incident_response_pre_deploy_tools.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC10-BP07 Run simulations](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_incident_response_run_game_days.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC10-BP08 Establish a framework for learning from incidents](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_incident_response_establish_incident_framework.html) | 기재·근거·판정 사유 대조 완료 |

### 4.11 SEC 11. How do you incorporate and validate the security properties of applications throughout the design, development, and deployment lifecycle?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec-11.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [SEC11-BP01 Train for application security](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_appsec_train_for_application_security.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC11-BP02 Automate testing throughout the development and release lifecycle](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_appsec_automate_testing_throughout_lifecycle.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC11-BP03 Perform regular penetration testing](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_appsec_perform_regular_penetration_testing.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC11-BP04 Conduct code reviews](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_appsec_manual_code_reviews.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC11-BP05 Centralize services for packages and dependencies](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_appsec_centralize_services_for_packages_and_dependencies.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC11-BP06 Deploy software programmatically](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_appsec_deploy_software_programmatically.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC11-BP07 Regularly assess security properties of the pipelines](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_appsec_regularly_assess_security_properties_of_pipelines.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SEC11-BP08 Build a program that embeds security ownership in workload teams](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_appsec_build_program_that_embeds_security_ownership_in_teams.html) | 기재·근거·판정 사유 대조 완료 |

## 5. Reliability(신뢰성)

[공식 질문·모범 사례](https://docs.aws.amazon.com/wellarchitected/latest/framework/a-reliability.html) · [제출 문서](03-reliability.md)

### 5.1 REL 1. How do you manage Service Quotas and constraints?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel-01.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [REL01-BP01 Aware of service quotas and constraints](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_manage_service_limits_aware_quotas_and_constraints.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL01-BP02 Manage service quotas across accounts and regions](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_manage_service_limits_limits_considered.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL01-BP03 Accommodate fixed service quotas and constraints through architecture](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_manage_service_limits_aware_fixed_limits.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL01-BP04 Monitor and manage quotas](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_manage_service_limits_monitor_manage_limits.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL01-BP05 Automate quota management](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_manage_service_limits_automated_monitor_limits.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL01-BP06 Ensure that a sufficient gap exists between the current quotas and the maximum usage to accommodate failover](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_manage_service_limits_suff_buffer_limits.html) | 기재·근거·판정 사유 대조 완료 |

### 5.2 REL 2. How do you plan your network topology?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel-02.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [REL02-BP01 Use highly available network connectivity for your workload public endpoints](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_planning_network_topology_ha_conn_users.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL02-BP02 Provision redundant connectivity between private networks in the cloud and on-premises environments](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_planning_network_topology_ha_conn_private_networks.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL02-BP03 Ensure IP subnet allocation accounts for expansion and availability](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_planning_network_topology_ip_subnet_allocation.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL02-BP04 Prefer hub-and-spoke topologies over many-to-many mesh](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_planning_network_topology_prefer_hub_and_spoke.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL02-BP05 Enforce non-overlapping private IP address ranges in all private address spaces where they are connected](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_planning_network_topology_non_overlap_ip.html) | 기재·근거·판정 사유 대조 완료 |

### 5.3 REL 3. How do you design your workload service architecture?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel-03.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [REL03-BP01 Choose how to segment your workload](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_service_architecture_monolith_soa_microservice.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL03-BP02 Build services focused on specific business domains and functionality](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_service_architecture_business_domains.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL03-BP03 Provide service contracts per API](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_service_architecture_api_contracts.html) | 기재·근거·판정 사유 대조 완료 |

### 5.4 REL 4. How do you design interactions in a distributed system to prevent failures?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel-04.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [REL04-BP01 Identify the kind of distributed systems you depend on](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_prevent_interaction_failure_identify.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL04-BP02 Implement loosely coupled dependencies](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_prevent_interaction_failure_loosely_coupled_system.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL04-BP03 Do constant work](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_prevent_interaction_failure_constant_work.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL04-BP04 Make mutating operations idempotent](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_prevent_interaction_failure_idempotent.html) | 기재·근거·판정 사유 대조 완료 |

### 5.5 REL 5. How do you design interactions in a distributed system to mitigate or withstand failures?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel-05.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [REL05-BP01 Implement graceful degradation to transform applicable hard dependencies into soft dependencies](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_mitigate_interaction_failure_graceful_degradation.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL05-BP02 Throttle requests](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_mitigate_interaction_failure_throttle_requests.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL05-BP03 Control and limit retry calls](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_mitigate_interaction_failure_limit_retries.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL05-BP04 Fail fast and limit queues](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_mitigate_interaction_failure_fail_fast.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL05-BP05 Set client timeouts](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_mitigate_interaction_failure_client_timeouts.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL05-BP06 Make systems stateless where possible](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_mitigate_interaction_failure_stateless.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL05-BP07 Implement emergency levers](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_mitigate_interaction_failure_emergency_levers.html) | 기재·근거·판정 사유 대조 완료 |

### 5.6 REL 6. How do you monitor workload resources?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel-06.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [REL06-BP01 Monitor all components for the workload (Generation)](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_monitor_aws_resources_monitor_resources.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL06-BP02 Define and calculate metrics (Aggregation)](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_monitor_aws_resources_notification_aggregation.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL06-BP03 Send notifications (Real-time processing and alarming)](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_monitor_aws_resources_notification_monitor.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL06-BP04 Automate responses (Real-time processing and alarming)](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_monitor_aws_resources_automate_response_monitor.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL06-BP05 Analyze logs](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_monitor_aws_resources_storage_analytics.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL06-BP06 Regularly review monitoring scope and metrics](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_monitor_aws_resources_review_monitoring.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL06-BP07 Monitor end-to-end tracing of requests through your system](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_monitor_aws_resources_end_to_end.html) | 기재·근거·판정 사유 대조 완료 |

### 5.7 REL 7. How do you design your workload to adapt to changes in demand?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel-07.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [REL07-BP01 Use automation when obtaining or scaling resources](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_adapt_to_changes_autoscale_adapt.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL07-BP02 Obtain resources upon detection of impairment to a workload](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_adapt_to_changes_reactive_adapt_auto.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL07-BP03 Obtain resources upon detection that more resources are needed for a workload](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_adapt_to_changes_proactive_adapt_auto.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL07-BP04 Load test your workload](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_adapt_to_changes_load_tested_adapt.html) | 기재·근거·판정 사유 대조 완료 |

### 5.8 REL 8. How do you implement change?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel-08.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [REL08-BP01 Use runbooks for standard activities such as deployment](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_tracking_change_management_planned_changemgmt.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL08-BP02 Integrate functional testing as part of your deployment](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_tracking_change_management_functional_testing.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL08-BP03 Integrate resiliency testing as part of your deployment](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_tracking_change_management_resiliency_testing.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL08-BP04 Deploy using immutable infrastructure](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_tracking_change_management_immutable_infrastructure.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL08-BP05 Deploy changes with automation](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_tracking_change_management_automated_changemgmt.html) | 기재·근거·판정 사유 대조 완료 |

### 5.9 REL 9. How do you back up data?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel-09.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [REL09-BP01 Identify and back up all data that needs to be backed up, or reproduce the data from sources](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_backing_up_data_identified_backups_data.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL09-BP02 Secure and encrypt backups](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_backing_up_data_secured_backups_data.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL09-BP03 Perform data backup automatically](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_backing_up_data_automated_backups_data.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL09-BP04 Perform periodic recovery of the data to verify backup integrity and processes](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_backing_up_data_periodic_recovery_testing_data.html) | 기재·근거·판정 사유 대조 완료 |

### 5.10 REL 10. How do you use fault isolation to protect your workload?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel-10.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [REL10-BP01 Deploy the workload to multiple locations](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_fault_isolation_multiaz_region_system.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL10-BP02 Automate recovery for components constrained to a single location](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_fault_isolation_single_az_system.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL10-BP03 Use bulkhead architectures to limit scope of impact](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_fault_isolation_use_bulkhead.html) | 기재·근거·판정 사유 대조 완료 |

### 5.11 REL 11. How do you design your workload to withstand component failures?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel-11.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [REL11-BP01 Monitor all components of the workload to detect failures](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_withstand_component_failures_monitoring_health.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL11-BP02 Fail over to healthy resources](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_withstand_component_failures_failover2good.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL11-BP03 Automate healing on all layers](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_withstand_component_failures_auto_healing_system.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL11-BP04 Rely on the data plane and not the control plane during recovery](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_withstand_component_failures_avoid_control_plane.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL11-BP05 Use static stability to prevent bimodal behavior](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_withstand_component_failures_static_stability.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL11-BP06 Send notifications when events impact availability](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_withstand_component_failures_notifications_sent_system.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL11-BP07 Architect your product to meet availability targets and uptime service level agreements (SLAs)](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_withstand_component_failures_service_level_agreements.html) | 기재·근거·판정 사유 대조 완료 |

### 5.12 REL 12. How do you test reliability?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel-12.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [REL12-BP01 Use playbooks to investigate failures](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_testing_resiliency_playbook_resiliency.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL12-BP02 Perform post-incident analysis](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_testing_resiliency_rca_resiliency.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL12-BP03 Test scalability and performance requirements](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_testing_resiliency_test_non_functional.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL12-BP04 Test resiliency using chaos engineering](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_testing_resiliency_failure_injection_resiliency.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL12-BP05 Conduct game days regularly](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_testing_resiliency_game_days_resiliency.html) | 기재·근거·판정 사유 대조 완료 |

### 5.13 REL 13. How do you plan for disaster recovery (DR)?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel-13.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [REL13-BP01 Define recovery objectives for downtime and data loss](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_planning_for_recovery_objective_defined_recovery.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL13-BP02 Use defined recovery strategies to meet the recovery objectives](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_planning_for_recovery_disaster_recovery.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL13-BP03 Test disaster recovery implementation to validate the implementation](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_planning_for_recovery_dr_tested.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [REL13-BP04 Manage configuration drift at the DR site or Region](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_planning_for_recovery_config_drift.html) | R04 · 보완 완료, 판정·사유 재확인 |
| [ ] | [REL13-BP05 Automate recovery](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_planning_for_recovery_auto_recovery.html) | 기재·근거·판정 사유 대조 완료 |

## 6. Performance Efficiency(성능 효율성)

[공식 질문·모범 사례](https://docs.aws.amazon.com/wellarchitected/latest/framework/a-performance-efficiency.html) · [제출 문서](04-performance-efficiency.md)

### 6.1 PERF 1. How do you select appropriate cloud resources and architecture for your workload?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf-01.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [PERF01-BP01 Learn about and understand available cloud services and features](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_architecture_understand_cloud_services_and_features.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [PERF01-BP02 Use guidance from your cloud provider or an appropriate partner to learn about architecture patterns and best practices](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_architecture_guidance_architecture_patterns_best_practices.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [PERF01-BP03 Factor cost into architectural decisions](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_architecture_factor_cost_into_architectural_decisions.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [PERF01-BP04 Evaluate how trade-offs impact customers and architecture efficiency](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_architecture_evaluate_trade_offs.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [PERF01-BP05 Use policies and reference architectures](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_architecture_use_policies_and_reference_architectures.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [PERF01-BP06 Use benchmarking to drive architectural decisions](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_architecture_use_benchmarking.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [PERF01-BP07 Use a data-driven approach for architectural choices](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_architecture_use_data_driven_approach.html) | 기재·근거·판정 사유 대조 완료 |

### 6.2 PERF 2. How do you select and use compute resources in your workload?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf-02.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [PERF02-BP01 Select the best compute options for your workload](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_compute_hardware_select_best_compute_options.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [PERF02-BP02 Understand the available compute configuration and features](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_compute_hardware_understand_compute_configuration_features.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [PERF02-BP03 Collect compute-related metrics](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_compute_hardware_collect_compute_related_metrics.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [PERF02-BP04 Configure and right-size compute resources](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_compute_hardware_configure_and_right_size_compute_resources.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [PERF02-BP05 Scale your compute resources dynamically](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_compute_hardware_scale_compute_resources_dynamically.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [PERF02-BP06 Use optimized hardware-based compute accelerators](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_compute_hardware_compute_accelerators.html) | 기재·근거·판정 사유 대조 완료 |

### 6.3 PERF 3. How do you store, manage, and access data in your workload?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf-03.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [PERF03-BP01 Use a purpose-built data store that best supports your data access and storage requirements](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_data_use_purpose_built_data_store.html) | R05 · 보완 완료, 판정·사유 재확인 |
| [ ] | [PERF03-BP02 Evaluate available configuration options for data store](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_data_evaluate_configuration_options_data_store.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [PERF03-BP03 Collect and record data store performance metrics](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_data_collect_record_data_store_performance_metrics.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [PERF03-BP04 Implement strategies to improve query performance in data store](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_data_implement_strategies_to_improve_query_performance.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [PERF03-BP05 Implement data access patterns that utilize caching](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_data_access_patterns_caching.html) | 기재·근거·판정 사유 대조 완료 |

### 6.4 PERF 4. How do you select and configure networking resources in your workload?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf-04.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [PERF04-BP01 Understand how networking impacts performance](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_networking_understand_how_networking_impacts_performance.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [PERF04-BP02 Evaluate available networking features](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_networking_evaluate_networking_features.html) | R05 · 보완 완료, 판정·사유 재확인 |
| [ ] | [PERF04-BP03 Choose appropriate dedicated connectivity or VPN for your workload](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_networking_choose_appropriate_dedicated_connectivity_or_vpn.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [PERF04-BP04 Use load balancing to distribute traffic across multiple resources](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_networking_load_balancing_distribute_traffic.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [PERF04-BP05 Choose network protocols to improve performance](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_networking_choose_network_protocols_improve_performance.html) | R05 · 보완 완료, 판정·사유 재확인 |
| [ ] | [PERF04-BP06 Choose your workload's location based on network requirements](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_networking_choose_workload_location_network_requirements.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [PERF04-BP07 Optimize network configuration based on metrics](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_networking_optimize_network_configuration_based_on_metrics.html) | 기재·근거·판정 사유 대조 완료 |

### 6.5 PERF 5. How do your organizational practices and culture contribute to performance efficiency in your workload?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf-05.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [PERF05-BP01 Establish key performance indicators (KPIs) to measure workload health and performance](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_process_culture_establish_key_performance_indicators.html) | R05 · 보완 완료, 판정·사유 재확인 |
| [ ] | [PERF05-BP02 Use monitoring solutions to understand the areas where performance is most critical](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_process_culture_use_monitoring_solutions.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [PERF05-BP03 Define a process to improve workload performance](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_process_culture_workload_performance.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [PERF05-BP04 Load test your workload](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_process_culture_load_test.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [PERF05-BP05 Use automation to proactively remediate performance-related issues](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_process_culture_automation_remediate_issues.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [PERF05-BP06 Keep your workload and services up-to-date](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_process_culture_keep_workload_and_services_up_to_date.html) | R05 · 보완 완료, 판정·사유 재확인 |
| [ ] | [PERF05-BP07 Review metrics at regular intervals](https://docs.aws.amazon.com/wellarchitected/latest/framework/perf_process_culture_review_metrics.html) | 기재·근거·판정 사유 대조 완료 |

## 7. Cost Optimization(비용 최적화)

[공식 질문·모범 사례](https://docs.aws.amazon.com/wellarchitected/latest/framework/a-cost-optimization.html) · [제출 문서](05-cost-optimization.md)

### 7.1 COST 1. How do you implement cloud financial management?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost-01.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [COST01-BP01 Establish ownership of cost optimization](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_cloud_financial_management_function.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [COST01-BP02 Establish a partnership between finance and technology](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_cloud_financial_management_partnership.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [COST01-BP03 Establish cloud budgets and forecasts](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_cloud_financial_management_budget_forecast.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [COST01-BP04 Implement cost awareness in your organizational processes](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_cloud_financial_management_cost_awareness.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [COST01-BP05 Report and notify on cost optimization](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_cloud_financial_management_usage_report.html) | R06 · 보완 완료, 판정·사유 재확인 |
| [ ] | [COST01-BP06 Monitor cost proactively](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_cloud_financial_management_proactive_process.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [COST01-BP07 Keep up-to-date with new service releases](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_cloud_financial_management_scheduled.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [COST01-BP08 Create a cost-aware culture](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_cloud_financial_management_culture.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [COST01-BP09 Quantify business value from cost optimization](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_cloud_financial_management_quantify_value.html) | 기재·근거·판정 사유 대조 완료 |

### 7.2 COST 2. How do you govern usage?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost-02.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [COST02-BP01 Develop policies based on your organization requirements](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_govern_usage_policies.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [COST02-BP02 Implement goals and targets](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_govern_usage_goal_target.html) | R06 · 보완 완료, 판정·사유 재확인 |
| [ ] | [COST02-BP03 Implement an account structure](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_govern_usage_account_structure.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [COST02-BP04 Implement groups and roles](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_govern_usage_groups_roles.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [COST02-BP05 Implement cost controls](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_govern_usage_controls.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [COST02-BP06 Track project lifecycle](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_govern_usage_track_lifecycle.html) | 기재·근거·판정 사유 대조 완료 |

### 7.3 COST 3. How do you monitor your cost and usage?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost-03.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [COST03-BP01 Configure detailed information sources](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_monitor_usage_detailed_source.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [COST03-BP02 Add organization information to cost and usage](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_monitor_usage_org_information.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [COST03-BP03 Identify cost attribution categories](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_monitor_usage_define_attribution.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [COST03-BP04 Establish organization metrics](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_monitor_usage_define_kpi.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [COST03-BP05 Configure billing and cost management tools](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_monitor_usage_config_tools.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [COST03-BP06 Allocate costs based on workload metrics](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_monitor_usage_allocate_outcome.html) | 기재·근거·판정 사유 대조 완료 |

### 7.4 COST 4. How do you decommission resources?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost-04.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [COST04-BP01 Track resources over their lifetime](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_decomissioning_resources_track.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [COST04-BP02 Implement a decommissioning process](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_decomissioning_resources_implement_process.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [COST04-BP03 Decommission resources](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_decomissioning_resources_decommission.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [COST04-BP04 Decommission resources automatically](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_decomissioning_resources_decomm_automated.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [COST04-BP05 Enforce data retention policies](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_decomissioning_resources_data_retention.html) | 기재·근거·판정 사유 대조 완료 |

### 7.5 COST 5. How do you evaluate cost when you select services?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost-05.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [COST05-BP01 Identify organization requirements for cost](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_select_service_requirements.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [COST05-BP02 Analyze all components of the workload](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_select_service_analyze_all.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [COST05-BP03 Perform a thorough analysis of each component](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_select_service_thorough_analysis.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [COST05-BP04 Select software with cost-effective licensing](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_select_service_licensing.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [COST05-BP05 Select components of this workload to optimize cost in line with organization priorities](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_select_service_select_for_cost.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [COST05-BP06 Perform cost analysis for different usage over time](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_select_service_analyze_over_time.html) | 기재·근거·판정 사유 대조 완료 |

### 7.6 COST 6. How do you meet cost targets when you select resource type, size and number?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost-06.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [COST06-BP01 Perform cost modeling](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_type_size_number_resources_cost_modeling.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [COST06-BP02 Select resource type, size, and number based on data](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_type_size_number_resources_data.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [COST06-BP03 Select resource type, size, and number automatically based on metrics](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_type_size_number_resources_metrics.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [COST06-BP04 Consider using shared resources](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_type_size_number_resources_shared.html) | 기재·근거·판정 사유 대조 완료 |

### 7.7 COST 7. How do you use pricing models to reduce cost?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost-07.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [COST07-BP01 Perform pricing model analysis](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_pricing_model_analysis.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [COST07-BP02 Choose Regions based on cost](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_pricing_model_region_cost.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [COST07-BP03 Select third-party agreements with cost-efficient terms](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_pricing_model_third_party.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [COST07-BP04 Implement pricing models for all components of this workload](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_pricing_model_implement_models.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [COST07-BP05 Perform pricing model analysis at the management account level](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_pricing_model_master_analysis.html) | 기재·근거·판정 사유 대조 완료 |

### 7.8 COST 8. How do you plan for data transfer charges?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost-08.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [COST08-BP01 Perform data transfer modeling](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_data_transfer_modeling.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [COST08-BP02 Select components to optimize data transfer cost](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_data_transfer_optimized_components.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [COST08-BP03 Implement services to reduce data transfer costs](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_data_transfer_implement_services.html) | 기재·근거·판정 사유 대조 완료 |

### 7.9 COST 9. How do you manage demand, and supply resources?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost-09.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [COST09-BP01 Perform an analysis on the workload demand](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_manage_demand_resources_cost_analysis.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [COST09-BP02 Implement a buffer or throttle to manage demand](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_manage_demand_resources_buffer_throttle.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [COST09-BP03 Supply resources dynamically](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_manage_demand_resources_dynamic.html) | 기재·근거·판정 사유 대조 완료 |

### 7.10 COST 10. How do you evaluate new services?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost-10.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [COST10-BP01 Develop a workload review process](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_evaluate_new_services_review_process.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [COST10-BP02 Review and analyze this workload regularly](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_evaluate_new_services_review_workload.html) | 기재·근거·판정 사유 대조 완료 |

### 7.11 COST 11. How do you evaluate the cost of effort?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost-11.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [COST11-BP01 Perform automation for operations](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_evaluate_cost_effort_automations_operations.html) | 기재·근거·판정 사유 대조 완료 |

## 8. Sustainability(지속 가능성)

[공식 질문·모범 사례](https://docs.aws.amazon.com/wellarchitected/latest/framework/a-sustainability.html) · [제출 문서](06-sustainability.md)

### 8.1 SUS 1 How do you select Regions for your workload?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/w2aac19c17b7b5.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [SUS01-BP01 Choose Region based on both business requirements and sustainability goals](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_region_a2.html) | 기재·근거·판정 사유 대조 완료 |

### 8.2 SUS 2 How do you align cloud resources to your demand?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus-02.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [SUS02-BP01 Scale workload infrastructure dynamically](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_user_a2.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SUS02-BP02 Align SLAs with sustainability goals](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_user_a3.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SUS02-BP03 Stop the creation and maintenance of unused assets](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_user_a4.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SUS02-BP04 Optimize geographic placement of workloads based on their networking requirements](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_user_a5.html) | R08 · 보완 완료, 판정·사유 재확인 |
| [ ] | [SUS02-BP05 Optimize team member resources for activities performed](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_user_a6.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SUS02-BP06 Implement buffering or throttling to flatten the demand curve](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_user_a7.html) | 기재·근거·판정 사유 대조 완료 |

### 8.3 SUS 3 How do you take advantage of software and architecture patterns to support your sustainability goals?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus-03.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [SUS03-BP01 Optimize software and architecture for asynchronous and scheduled jobs](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_software_a2.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SUS03-BP02 Remove or refactor workload components with low or no use](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_software_a3.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SUS03-BP03 Optimize areas of code that consume the most time or resources](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_software_a4.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SUS03-BP04 Optimize impact on devices and equipment](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_software_a5.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SUS03-BP05 Use software patterns and architectures that best support data access and storage patterns](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_software_a6.html) | R08 · 보완 완료, 판정·사유 재확인 |

### 8.4 SUS 4 How do you take advantage of data management policies and patterns to support your sustainability goals?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus-04.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [SUS04-BP01 Implement a data classification policy](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_data_a2.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SUS04-BP02 Use technologies that support data access and storage patterns](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_data_a3.html) | R08 · 보완 완료, 판정·사유 재확인 |
| [ ] | [SUS04-BP03 Use policies to manage the lifecycle of your datasets](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_data_a4.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SUS04-BP04 Use elasticity and automation to expand block storage or file system](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_data_a5.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SUS04-BP05 Remove unneeded or redundant data](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_data_a6.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SUS04-BP06 Use shared file systems or storage to access common data](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_data_a7.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SUS04-BP07 Minimize data movement across networks](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_data_a8.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SUS04-BP08 Back up data only when difficult to recreate](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_data_a9.html) | 기재·근거·판정 사유 대조 완료 |

### 8.5 SUS 5 How do you select and use cloud hardware and services in your architecture to support your sustainability goals?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus-05.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [SUS05-BP01 Use the minimum amount of hardware to meet your needs](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_hardware_a2.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SUS05-BP02 Use instance types with the least impact](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_hardware_a3.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SUS05-BP03 Use managed services](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_hardware_a4.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SUS05-BP04 Optimize your use of hardware-based compute accelerators](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_hardware_a5.html) | 기재·근거·판정 사유 대조 완료 |

### 8.6 SUS 6 How do your organizational processes support your sustainability goals?

- [ ] [공식 질문](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus-06.html) — 해당 질문과 BP 판정 근거를 검토했습니다. 보완 대상은 아래 행에 표시합니다.

| 확인 | BP ID·공식 명칭 | 검토 기록 |
|---|---|---|
| [ ] | [SUS06-BP01 Communicate and cascade your sustainability goals](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_dev_a1.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SUS06-BP02 Adopt methods that can rapidly introduce sustainability improvements](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_dev_a2.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SUS06-BP03 Keep your workload up-to-date](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_dev_a3.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SUS06-BP04 Increase utilization of build environments](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_dev_a4.html) | 기재·근거·판정 사유 대조 완료 |
| [ ] | [SUS06-BP05 Use managed device farms for testing](https://docs.aws.amazon.com/wellarchitected/latest/framework/sus_sus_dev_a5.html) | 기재·근거·판정 사유 대조 완료 |
