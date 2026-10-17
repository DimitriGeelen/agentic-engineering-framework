# T-1189 — AEF node id map, old -> new (designer 0.21.0, AEF c1a87c16f)

Produced by 832 tools/_t1168-node-id-map.mjs --dir --designer, run against the RELEASED designer-v0.21.0 artefact
(sha256 da1619714dfcb46f265c989d08a2c5129fb0134c40f726826a86fff93294b505). Old and new ids are paired through each
node's aef:uid, never by number. Every map is a pure id rename: reversing the map restores the original byte for
byte; the patch applies cleanly at c1a87c16f. 0.21.0 skips a leading task id in a node's name (T-1194), so
"T-001: Orientation ..." gives agt_1_orientation. Ids not listed are unchanged.

| map | renamed |
|---|---|
| aef-audit-cron/v1 | 9 |
| aef-dispatch-loop/v1 | 9 |
| aef-dispatch-loop/v2 | 9 |
| aef-dispatch-loop/v3 | 9 |
| aef-existing-project-onboarding/v1 | 9 |
| aef-greenfield-onboarding/v1 | 6 |
| aef-greenfield-onboarding/v2 | 6 |
| aef-inception-flow/v1 | 9 |
| aef-session-lifecycle/v1 | 10 |
| aef-task-lifecycle/v1 | 11 |
| aef-task-lifecycle/v2 | 14 |
| aef-task-lifecycle/v3 | 14 |
| aef-tier0-escalation/v1 | 10 |
| draft-arc-lifecycle/v1 | 12 |
| draft-arc-lifecycle/v2 | 12 |
| draft-arc-lifecycle/v3 | 13 |
| draft-arc-lifecycle/v4 | 12 |
| draft-continuous-run-loop/v1 | 12 |
| draft-continuous-run-loop/v2 | 12 |
| draft-continuous-run-loop/v3 | 12 |
| draft-continuous-run-loop/v4 | 12 |
| draft-continuous-run-loop/v5 | 12 |
| draft-exception-handling/v1 | 3 |
| draft-exception-handling/v2 | 10 |
| draft-exception-handling/v3 | 9 |
| draft-inception-readiness/v1 | 16 |
| draft-inception-readiness/v2 | 15 |
| draft-knowledge-leveling/v1 | 3 |
| draft-knowledge-leveling/v2 | 15 |
| draft-knowledge-leveling/v3 | 15 |
| draft-knowledge-leveling/v4 | 13 |
| draft-knowledge-leveling/v5 | 11 |
| draft-knowledge-leveling/v6 | 9 |
| draft-knowledge-leveling/v7 | 12 |
| draft-knowledge-leveling/v8 | 12 |
| draft-t2584-scratch/v1 | 1 |
| draft-task-creation/v1 | 3 |
| draft-task-creation/v2 | 13 |
| draft-task-creation/v3 | 14 |
| draft-task-creation/v4 | 16 |
| draft-task-creation/v5 | 16 |
| draft-trigger-handling/v1 | 19 |
| draft-trigger-handling/v2 | 18 |
| draft-trigger-handling/v3 | 18 |
| draft-trigger-handling/v4 | 18 |
| draft-trigger-handling/v5 | 18 |
| draft-trigger-handling/v6 | 18 |
| **total** | **549** |

## aef-audit-cron/v1

| old | new |
|---|---|
| `agt_1_daily` | `agt_start_daily` |
| `agt_5_audit` | `agt_end_audit` |
| `hum_2_findings` | `hum_end_findings` |
| `agt_2_fw` | `agt_1_fw` |
| `agt_3_record` | `agt_2_record` |
| `agt_7_emit` | `agt_3_emit` |
| `agt_4_sweep` | `agt_gw_sweep` |
| `agt_8_handoff_lifecycle` | `agt_link_handoff` |
| `agt_6_warn` | `agt_error_warn` |

## aef-dispatch-loop/v1

| old | new |
|---|---|
| `agt_0_start` | `agt_start_task` |
| `agt_6_done` | `agt_end_loop` |
| `agt_1_resolve` | `agt_1_fw` |
| `agt_4_retry` | `agt_4_re` |
| `agt_5_outcome` | `agt_3_fw` |
| `hum_3_pause` | `hum_1_operator` |
| `agt_gw_paused` | `agt_gw_worker` |
| `agt_7_handoff_back` | `lan_link_handoff` |
| `agt_msg_result` | `agt_message_worker` |

## aef-dispatch-loop/v2

| old | new |
|---|---|
| `agt_0_start` | `agt_start_task` |
| `agt_6_done` | `agt_end_loop` |
| `agt_1_resolve` | `agt_1_fw` |
| `agt_4_retry` | `agt_4_re` |
| `agt_5_outcome` | `agt_3_fw` |
| `hum_3_pause` | `hum_1_operator` |
| `agt_gw_paused` | `agt_gw_worker` |
| `agt_7_handoff_back` | `agt_link_handoff` |
| `agt_msg_result` | `agt_message_worker` |

## aef-dispatch-loop/v3

| old | new |
|---|---|
| `agt_1_task` | `agt_start_task` |
| `agt_8_loop` | `agt_end_loop` |
| `agt_2_fw` | `agt_1_fw` |
| `agt_3_spawn` | `agt_2_spawn` |
| `agt_7_re` | `agt_4_re` |
| `agt_6_fw` | `agt_3_fw` |
| `agt_5_worker` | `agt_gw_worker` |
| `agt_9_handoff` | `agt_link_handoff` |
| `agt_4_worker` | `agt_message_worker` |

## aef-existing-project-onboarding/v1

| old | new |
|---|---|
| `agt_0_start` | `agt_start_you` |
| `agt_7_released` | `agt_end_prologue` |
| `agt_2_first_commit` | `agt_2_your` |
| `agt_3_fabric` | `agt_3_register` |
| `agt_4_lifecycle` | `agt_4_walk` |
| `agt_5_handover` | `agt_5_generate` |
| `agt_6_learning` | `agt_6_record` |
| `agt_7_objectives` | `agt_7_write` |
| `hum_alongside` | `hum_1_you` |

## aef-greenfield-onboarding/v1

| old | new |
|---|---|
| `agt_0_start` | `agt_start_fw` |
| `agt_6_ready` | `agt_end_ready` |
| `agt_3_first_commit` | `agt_2_first` |
| `agt_4_lifecycle` | `agt_3_complete` |
| `agt_5_handover` | `agt_4_generate` |
| `hum_2_goals` | `hum_1_define` |

## aef-greenfield-onboarding/v2

| old | new |
|---|---|
| `agt_0_start` | `agt_start_you` |
| `agt_6_ready` | `agt_end_ready` |
| `agt_3_first_commit` | `agt_2_your` |
| `agt_4_lifecycle` | `agt_3_walk` |
| `agt_5_handover` | `agt_4_generate` |
| `hum_2_goals` | `hum_1_define` |

## aef-inception-flow/v1

| old | new |
|---|---|
| `agt_0_question` | `agt_start_question` |
| `agt_6_go` | `agt_end_build` |
| `agt_7_closed` | `agt_end_question` |
| `agt_2_artifact` | `agt_2_create` |
| `agt_4_children` | `agt_4_file` |
| `agt_5_archive` | `agt_3_archive` |
| `agt_gw_outcome` | `agt_gw_decision` |
| `agt_8_handoff_tl` | `agt_link_handoff` |
| `hum_3_inception` | `hum_1_explore` |

## aef-session-lifecycle/v1

| old | new |
|---|---|
| `hum_1_operator` | `hum_start_operator` |
| `agt_10_session` | `agt_end_session_2` |
| `agt_9_session` | `agt_end_session` |
| `agt_4_session` | `agt_3_session` |
| `agt_5_fw` | `agt_4_fw` |
| `agt_6_push` | `agt_5_push` |
| `hum_2_operator` | `hum_1_operator` |
| `agt_3_budget` | `agt_gw_budget` |
| `agt_7_restart` | `agt_gw_restart` |
| `agt_8_wrapper` | `agt_timer_wrapper` |

## aef-task-lifecycle/v1

| old | new |
|---|---|
| `agt_0_capture` | `agt_start_work` |
| `agt_8_done` | `agt_end_task` |
| `agt_1c_parked` | `agt_2_parked` |
| `agt_2_start` | `agt_3_start` |
| `agt_3_work` | `agt_4_do` |
| `agt_4_heal` | `agt_5_healing` |
| `agt_5_verify` | `agt_6_completion` |
| `hum_6_review` | `hum_1_partial` |
| `agt_1b_gw_ready` | `agt_gw_ready` |
| `agt_gw_human` | `agt_gw_unchecked` |
| `agt_9_handoff_dispatch` | `agt_link_handoff` |

## aef-task-lifecycle/v2

| old | new |
|---|---|
| `agt_1_work` | `agt_start_work` |
| `agt_14_task` | `agt_end_task` |
| `agt_2_create` | `agt_1_create` |
| `agt_4_parked` | `agt_2_parked` |
| `agt_5_start` | `agt_3_start` |
| `agt_6_do` | `agt_4_do` |
| `agt_8_healing` | `agt_5_healing` |
| `agt_10_completion` | `agt_6_completion` |
| `agt_13_archive` | `agt_7_archive` |
| `agt_3_ready` | `agt_gw_ready` |
| `agt_9_issues` | `agt_gw_issues` |
| `agt_11_gates` | `agt_gw_gates` |
| `agt_12_unchecked` | `agt_gw_unchecked` |
| `agt_7_handoff` | `agt_link_handoff` |

## aef-task-lifecycle/v3

| old | new |
|---|---|
| `agt_1_work` | `agt_start_work` |
| `agt_14_task` | `agt_end_task` |
| `agt_2_create` | `agt_1_create` |
| `agt_4_parked` | `agt_2_parked` |
| `agt_5_start` | `agt_3_start` |
| `agt_6_do` | `agt_4_do` |
| `agt_8_healing` | `agt_5_healing` |
| `agt_10_completion` | `agt_6_completion` |
| `agt_13_archive` | `agt_7_archive` |
| `agt_3_ready` | `agt_gw_ready` |
| `agt_9_issues` | `agt_gw_issues` |
| `agt_11_gates` | `agt_gw_gates` |
| `agt_12_unchecked` | `agt_gw_unchecked` |
| `agt_7_handoff` | `agt_link_handoff` |

## aef-tier0-escalation/v1

| old | new |
|---|---|
| `agt_0_command` | `agt_start_agent` |
| `fw_end_allow` | `fw_end_command` |
| `fw_end_executed` | `fw_end_command_2` |
| `hum_end_abandoned` | `hum_end_command` |
| `fw_6_audit` | `fw_5_write` |
| `fw_5_notify` | `fw_6_human` |
| `hum_2_reject` | `hum_2_write` |
| `hum_1_disposition` | `hum_1_review` |
| `fw_gw_trigger` | `fw_gw_destructive` |
| `fw_gw_preauth` | `fw_gw_valid` |

## draft-arc-lifecycle/v1

| old | new |
|---|---|
| `hum_1_open` | `hum_start_operator` |
| `hum_5_closed` | `hum_end_arc` |
| `agt_5_file` | `agt_3_file` |
| `fwk_2_exit_recalc` | `fwk_2_exit` |
| `fwk_4_report` | `fwk_3_report` |
| `fwk_5_close_gates` | `fwk_4_062` |
| `hum_2_approve` | `hum_1_approve` |
| `hum_3_flag` | `hum_2_raise` |
| `hum_4_close` | `hum_3_close` |
| `agt_3_hv` | `agt_gw_hv` |
| `fwk_3_resurfaced` | `fwk_gw_any` |
| `fwk_6_gates_pass` | `fwk_gw_close` |

## draft-arc-lifecycle/v2

| old | new |
|---|---|
| `hum_1_operator` | `hum_start_operator` |
| `hum_5_arc` | `hum_end_arc` |
| `agt_5_work` | `agt_4_work` |
| `agt_4_file` | `agt_3_file` |
| `fwk_4_report` | `fwk_3_report` |
| `fwk_5_062` | `fwk_4_062` |
| `hum_2_approve` | `hum_1_approve` |
| `hum_3_raise` | `hum_2_raise` |
| `hum_4_close` | `hum_3_close` |
| `agt_3_hv` | `agt_gw_hv` |
| `fwk_3_any` | `fwk_gw_any` |
| `fwk_6_close` | `fwk_gw_close` |

## draft-arc-lifecycle/v3

| old | new |
|---|---|
| `hum_1_operator` | `hum_start_operator` |
| `hum_5_arc` | `hum_end_arc` |
| `agt_1_propose` | `agt_1_decide` |
| `agt_1b_inform` | `agt_2_inform` |
| `agt_2_pick` | `agt_3_pick` |
| `fwk_4_report` | `fwk_3_report` |
| `fwk_5_062` | `fwk_4_062` |
| `hum_2_adjust` | `hum_1_adjust` |
| `hum_3_raise` | `hum_2_raise` |
| `hum_4_close` | `hum_3_close` |
| `agt_3_hv` | `agt_gw_hv` |
| `fwk_3_any` | `fwk_gw_any` |
| `fwk_6_close` | `fwk_gw_close` |

## draft-arc-lifecycle/v4

| old | new |
|---|---|
| `hum_1_operator` | `hum_start_operator` |
| `hum_5_arc` | `hum_end_arc` |
| `agt_6_work` | `agt_5_work` |
| `agt_5_file` | `agt_4_file` |
| `fwk_4_report` | `fwk_3_report` |
| `fwk_5_062` | `fwk_4_062` |
| `hum_2_adjust` | `hum_1_adjust` |
| `hum_3_raise` | `hum_2_raise` |
| `hum_4_close` | `hum_3_close` |
| `agt_4_hv` | `agt_gw_hv` |
| `fwk_3_any` | `fwk_gw_any` |
| `fwk_6_close` | `fwk_gw_close` |

## draft-continuous-run-loop/v1

| old | new |
|---|---|
| `hum_1_operator` | `hum_start_operator` |
| `agt_4_run` | `agt_end_run` |
| `agt_5_run` | `agt_end_run_2` |
| `hum_3_run` | `hum_end_run` |
| `agt_3_finish` | `agt_3_let` |
| `fw_5_handover` | `fw_2_handover` |
| `fw_6_boundary` | `fw_3_cross` |
| `hum_2_operator` | `hum_1_operator` |
| `fw_2_budget` | `fw_gw_budget` |
| `fw_3_stop` | `fw_gw_stop` |
| `fw_4_run` | `fw_gw_run` |
| `fw_7_sessionstart` | `fw_gw_sessionstart` |

## draft-continuous-run-loop/v2

| old | new |
|---|---|
| `hum_1_operator` | `hum_start_operator` |
| `agt_4_run` | `agt_end_run` |
| `agt_5_run` | `agt_end_run_2` |
| `hum_3_run` | `hum_end_run` |
| `agt_3_finish` | `agt_3_let` |
| `fw_5_handover` | `fw_2_handover` |
| `fw_6_boundary` | `fw_3_cross` |
| `hum_2_operator` | `hum_1_operator` |
| `fw_2_budget` | `fw_gw_budget` |
| `fw_3_stop` | `fw_gw_stop` |
| `fw_4_run` | `fw_gw_run` |
| `fw_7_sessionstart` | `fw_gw_sessionstart` |

## draft-continuous-run-loop/v3

| old | new |
|---|---|
| `hum_1_operator` | `hum_start_operator` |
| `agt_3_run` | `agt_end_run` |
| `agt_5_run` | `agt_end_run_2` |
| `hum_3_run` | `hum_end_run` |
| `agt_4_let` | `agt_3_let` |
| `fw_5_handover` | `fw_2_handover` |
| `fw_6_cross` | `fw_3_cross` |
| `hum_2_operator` | `hum_1_operator` |
| `fw_2_budget` | `fw_gw_budget` |
| `fw_3_stop` | `fw_gw_stop` |
| `fw_4_run` | `fw_gw_run` |
| `fw_7_sessionstart` | `fw_gw_sessionstart` |

## draft-continuous-run-loop/v4

| old | new |
|---|---|
| `hum_1_operator` | `hum_start_operator` |
| `agt_3_run` | `agt_end_run` |
| `agt_5_run` | `agt_end_run_2` |
| `hum_3_run` | `hum_end_run` |
| `agt_4_let` | `agt_3_let` |
| `fw_5_handover` | `fw_2_handover` |
| `fw_6_cross` | `fw_3_cross` |
| `hum_2_operator` | `hum_1_operator` |
| `fw_2_budget` | `fw_gw_budget` |
| `fw_3_stop` | `fw_gw_stop` |
| `fw_4_run` | `fw_gw_run` |
| `fw_7_sessionstart` | `fw_gw_sessionstart` |

## draft-continuous-run-loop/v5

| old | new |
|---|---|
| `hum_1_operator` | `hum_start_operator` |
| `agt_3_run` | `agt_end_run` |
| `agt_5_run` | `agt_end_run_2` |
| `hum_3_run` | `hum_end_run` |
| `agt_4_let` | `agt_3_let` |
| `fw_5_handover` | `fw_2_handover` |
| `fw_6_cross` | `fw_3_cross` |
| `hum_2_operator` | `hum_1_operator` |
| `fw_2_budget` | `fw_gw_budget` |
| `fw_3_stop` | `fw_gw_stop` |
| `fw_4_run` | `fw_gw_run` |
| `fw_7_sessionstart` | `fw_gw_sessionstart` |

## draft-exception-handling/v1

| old | new |
|---|---|
| `d_start` | `agt_start_session` |
| `d_end` | `agt_end_settled` |
| `d_sketch` | `agt_1_sketch` |

## draft-exception-handling/v2

| old | new |
|---|---|
| `agt_0_error` | `agt_start_error` |
| `fw_end_learned` | `fw_end_resolved` |
| `fw_1_diagnose` | `fw_1_healing` |
| `fw_4_suggest` | `fw_4_emit` |
| `agt_1_flag` | `agt_1_set` |
| `agt_2_fix` | `agt_2_apply` |
| `agt_3_resume` | `agt_3_status` |
| `agt_4_resolve` | `agt_4_fw` |
| `fw_gw_type` | `fw_gw_failure` |
| `fw_gw_join` | `fw_gw_fw` |

## draft-exception-handling/v3

| old | new |
|---|---|
| `agt_0_error` | `agt_start_error` |
| `fw_end_learned` | `fw_end_resolved` |
| `agt_1_flag` | `agt_1_set` |
| `fw_1_diagnose` | `fw_1_healing` |
| `fw_4_suggest` | `fw_4_emit` |
| `agt_2_fix` | `agt_2_apply` |
| `agt_3_resume` | `agt_3_status` |
| `agt_4_resolve` | `agt_4_fw` |
| `fw_gw_type` | `fw_gw_failure` |

## draft-inception-readiness/v1

| old | new |
|---|---|
| `agt_0_question` | `agt_start_question` |
| `agt_14_go` | `agt_end_build` |
| `agt_15_closed` | `agt_end_question` |
| `fw_2_filing_gate` | `fw_1_filing` |
| `agt_3_artifact` | `agt_2_create` |
| `agt_5_evaluate` | `agt_4_proposed` |
| `fw_8_putforward` | `fw_2_put` |
| `fw_10_record` | `fw_3_record` |
| `agt_12_children` | `agt_6_file` |
| `agt_13_archive` | `agt_5_archive` |
| `hum_7_dialogue` | `hum_1_operator` |
| `hum_9_decide` | `hum_2_operator` |
| `fw_6_readiness` | `fw_gw_proposed` |
| `agt_11_gw_outcome` | `agt_gw_decision` |
| `agt_16_handoff_tl` | `agt_link_handoff` |
| `agt_4_explore` | `agt_3_explore` |

## draft-inception-readiness/v2

| old | new |
|---|---|
| `agt_1_question` | `agt_start_question` |
| `agt_10_build` | `agt_end_build` |
| `agt_9_question` | `agt_end_question` |
| `agt_2_file` | `agt_1_file` |
| `fw_1_2204` | `fw_1_filing` |
| `agt_3_create` | `agt_2_create` |
| `agt_5_proposed` | `agt_4_proposed` |
| `fw_3_put` | `fw_2_put` |
| `fw_4_record` | `fw_3_record` |
| `agt_8_file` | `agt_6_file` |
| `agt_7_archive` | `agt_5_archive` |
| `fw_2_proposed` | `fw_gw_proposed` |
| `agt_6_decision` | `agt_gw_decision` |
| `agt_11_handoff` | `agt_link_handoff` |
| `agt_4_explore` | `agt_3_explore` |

## draft-knowledge-leveling/v1

| old | new |
|---|---|
| `d_start` | `agt_start_session` |
| `d_end` | `agt_end_settled` |
| `d_sketch` | `agt_1_sketch` |

## draft-knowledge-leveling/v2

| old | new |
|---|---|
| `agt_0_insight` | `agt_start_learning` |
| `agt_0_promote` | `agt_start_fw_3` |
| `agt_0_harvest` | `agt_start_fw_2` |
| `agt_0_consolidate` | `agt_start_fw` |
| `fw_end_captured` | `fw_end_learning` |
| `fw_end_already` | `fw_end_refused` |
| `fw_end_active` | `fw_end_practice` |
| `fw_end_harvest` | `fw_end_framework` |
| `fw_end_consolidate` | `fw_end_consolidation` |
| `agt_1_capture` | `agt_1_fw` |
| `fw_1_write` | `fw_4_write` |
| `fw_3_practice` | `fw_5_write` |
| `fw_4_harvest` | `fw_3_harvest` |
| `fw_5_consolidate` | `fw_1_cluster` |
| `fw_gw_ready` | `fw_gw_promotion` |

## draft-knowledge-leveling/v3

| old | new |
|---|---|
| `agt_0_insight` | `agt_start_learning` |
| `agt_0_promote` | `agt_start_fw_3` |
| `agt_0_harvest` | `agt_start_fw_2` |
| `agt_0_consolidate` | `agt_start_fw` |
| `fw_end_captured` | `fw_end_learning` |
| `fw_end_already` | `fw_end_refused` |
| `fw_end_active` | `fw_end_practice` |
| `fw_end_harvest` | `fw_end_framework` |
| `fw_end_consolidate` | `fw_end_consolidation` |
| `agt_1_capture` | `agt_1_fw` |
| `fw_1_write` | `fw_4_write` |
| `fw_3_practice` | `fw_5_write` |
| `fw_4_harvest` | `fw_3_harvest` |
| `fw_5_consolidate` | `fw_1_cluster` |
| `fw_gw_ready` | `fw_gw_promotion` |

## draft-knowledge-leveling/v4

| old | new |
|---|---|
| `agt_0_insight` | `agt_start_learning` |
| `agt_0_promote` | `agt_start_fw` |
| `agt_0_harvest` | `agt_start_fw_2` |
| `agt_0_consolidate` | `agt_start_fw_3` |
| `fw_end_captured` | `fw_end_learning` |
| `fw_end_already` | `fw_end_refused` |
| `fw_end_active` | `fw_end_practice` |
| `fw_end_harvest` | `fw_end_framework` |
| `fw_end_consolidate` | `fw_end_consolidation` |
| `agt_1_capture` | `agt_1_fw` |
| `fw_3_practice` | `fw_3_write` |
| `fw_5_consolidate` | `fw_5_cluster` |
| `fw_gw_ready` | `fw_gw_promotion` |

## draft-knowledge-leveling/v5

| old | new |
|---|---|
| `agt_0_insight` | `agt_start_organic` |
| `agt_0_bugfix` | `agt_start_bugfix` |
| `agt_0_healing` | `agt_start_healing` |
| `fw_end_already` | `fw_end_refused` |
| `fw_end_active` | `fw_end_practice` |
| `agt_1_capture` | `agt_1_fw` |
| `agt_2_fixlearned` | `agt_2_fw` |
| `fw_1_write` | `fw_1_append` |
| `fw_3_practice` | `fw_3_write` |
| `fw_gw_ready` | `fw_gw_promotion` |
| `fw_wait_dormant` | `fw_link_dormant` |

## draft-knowledge-leveling/v6

| old | new |
|---|---|
| `agt_3_organic` | `fw_start_organic` |
| `agt_1_bugfix` | `agt_start_bugfix` |
| `agt_2_healing` | `agt_start_healing` |
| `fw_7_refused` | `fw_end_refused` |
| `fw_8_practice` | `fw_end_practice` |
| `fw_5_count` | `fw_4_count` |
| `agt_4_write` | `agt_1_write` |
| `fw_6_promotion` | `fw_gw_promotion` |
| `fw_4_dormant` | `fw_link_dormant` |

## draft-knowledge-leveling/v7

| old | new |
|---|---|
| `fw_2_organic` | `fw_start_organic` |
| `fw_1_bugfix` | `fw_start_bugfix` |
| `agt_1_healing` | `agt_start_healing` |
| `agt_7_refused` | `agt_end_refused` |
| `agt_6_practice` | `agt_end_practice` |
| `fw_3_fw` | `fw_1_fw` |
| `fw_4_fw` | `fw_2_fw` |
| `agt_2_append` | `agt_1_append` |
| `agt_3_count` | `agt_2_count` |
| `agt_5_write` | `agt_3_write` |
| `agt_4_promotion` | `agt_gw_promotion` |
| `fw_5_dormant` | `fw_link_dormant` |

## draft-knowledge-leveling/v8

| old | new |
|---|---|
| `fw_2_organic` | `fw_start_organic` |
| `fw_1_bugfix` | `fw_start_bugfix` |
| `agt_1_healing` | `agt_start_healing` |
| `agt_7_refused` | `agt_end_refused` |
| `agt_6_practice` | `agt_end_practice` |
| `fw_3_fw` | `fw_1_fw` |
| `fw_4_fw` | `fw_2_fw` |
| `agt_2_append` | `agt_1_append` |
| `agt_3_count` | `agt_2_count` |
| `agt_5_write` | `agt_3_write` |
| `agt_4_promotion` | `agt_gw_promotion` |
| `fw_5_dormant` | `fw_link_dormant` |

## draft-t2584-scratch/v1

| old | new |
|---|---|
| `hum_1_handoff` | `hum_link_handoff` |

## draft-task-creation/v1

| old | new |
|---|---|
| `d_start` | `agt_start_session` |
| `d_end` | `agt_end_settled` |
| `d_sketch` | `agt_1_sketch` |

## draft-task-creation/v2

| old | new |
|---|---|
| `agt_0_intent` | `agt_start_work` |
| `hum_0_form` | `hum_start_operator` |
| `fw_end_ready` | `fw_end_task` |
| `agt_1_workon` | `agt_1_fw` |
| `fw_1_create` | `fw_1_instantiate` |
| `fw_2_id` | `fw_2_allocate` |
| `fw_3_recgate` | `fw_3_inception` |
| `fw_5_focus` | `fw_5_set` |
| `fw_6_estimator` | `fw_6_bvp` |
| `fw_7_g020` | `fw_7_020` |
| `agt_2_acs` | `agt_2_author` |
| `fw_gw_exists` | `fw_gw_existing` |
| `fw_gw_type` | `fw_gw_workflow` |

## draft-task-creation/v3

| old | new |
|---|---|
| `agt_0_intent` | `agt_start_work` |
| `hum_0_form` | `hum_start_operator` |
| `fw_end_ready` | `fw_end_task_2` |
| `fw_end_captured` | `fw_end_task` |
| `agt_1_workon` | `agt_1_fw` |
| `fw_1_create` | `fw_1_instantiate` |
| `fw_2_id` | `fw_2_allocate` |
| `fw_3_recgate` | `fw_3_inception` |
| `fw_5_focus` | `fw_5_set` |
| `fw_6_estimator` | `fw_6_bvp` |
| `fw_7_g020` | `fw_7_020` |
| `agt_2_acs` | `agt_2_author` |
| `fw_gw_exists` | `fw_gw_existing` |
| `fw_gw_type` | `fw_gw_workflow` |

## draft-task-creation/v4

| old | new |
|---|---|
| `agt_1_work` | `agt_start_work` |
| `hum_1_operator` | `hum_start_operator` |
| `fw_12_task` | `fw_end_task_2` |
| `fw_11_task` | `fw_end_task` |
| `agt_2_fw` | `agt_1_fw` |
| `fw_2_instantiate` | `fw_1_instantiate` |
| `fw_3_allocate` | `fw_2_allocate` |
| `fw_5_inception` | `fw_3_inception` |
| `fw_7_write` | `fw_4_write` |
| `fw_8_set` | `fw_5_set` |
| `fw_9_bvp` | `fw_6_bvp` |
| `fw_10_020` | `fw_7_020` |
| `agt_3_author` | `agt_2_author` |
| `fw_1_existing` | `fw_gw_existing` |
| `fw_4_workflow` | `fw_gw_workflow` |
| `fw_6_activation` | `fw_gw_activation` |

## draft-task-creation/v5

| old | new |
|---|---|
| `agt_1_work` | `agt_start_work` |
| `hum_1_operator` | `hum_start_operator` |
| `fw_12_task` | `fw_end_task_2` |
| `fw_11_task` | `fw_end_task` |
| `agt_2_fw` | `agt_1_fw` |
| `fw_2_instantiate` | `fw_1_instantiate` |
| `fw_3_allocate` | `fw_2_allocate` |
| `fw_5_inception` | `fw_3_inception` |
| `fw_7_write` | `fw_4_write` |
| `fw_8_set` | `fw_5_set` |
| `fw_9_bvp` | `fw_6_bvp` |
| `fw_10_020` | `fw_7_020` |
| `agt_3_author` | `agt_2_author` |
| `fw_1_existing` | `fw_gw_existing` |
| `fw_4_workflow` | `fw_gw_workflow` |
| `fw_6_activation` | `fw_gw_activation` |

## draft-trigger-handling/v1

| old | new |
|---|---|
| `fwk_1_cycle` | `fwk_start_observation` |
| `fwk_5_quiet` | `fwk_end_quiet` |
| `hum_4_acted` | `hum_end_acted` |
| `hum_5_parked` | `hum_end_parked` |
| `hum_7_dismissed` | `hum_end_dismissed` |
| `fwk_2_snapshot` | `fwk_1_collect` |
| `fwk_3_eval` | `fwk_2_evaluate` |
| `agt_2_diagnose` | `agt_1_diagnose` |
| `agt_4_propose_task` | `agt_3_propose` |
| `agt_5_propose_redesign` | `agt_2_propose` |
| `hum_1_triage` | `hum_1_operator` |
| `hum_3_act` | `hum_2_act` |
| `hum_6_dismiss` | `hum_3_dismiss` |
| `fwk_4_breach` | `fwk_gw_any` |
| `agt_3_outcome` | `agt_gw_diagnosis` |
| `hum_2_decision` | `hum_gw_triage` |
| `fwk_6_signal` | `fwk_link_emit` |
| `agt_6_handoff` | `agt_link_handoff` |
| `agt_1_pickup` | `agt_message_trigger` |

## draft-trigger-handling/v2

| old | new |
|---|---|
| `fwk_1_observation` | `fwk_start_observation` |
| `fwk_6_quiet` | `fwk_end_quiet` |
| `hum_5_acted` | `hum_end_acted` |
| `hum_7_parked` | `hum_end_parked` |
| `hum_6_dismissed` | `hum_end_dismissed` |
| `fwk_2_collect` | `fwk_1_collect` |
| `fwk_3_evaluate` | `fwk_2_evaluate` |
| `agt_2_diagnose` | `agt_1_diagnose` |
| `agt_5_propose` | `agt_3_propose` |
| `agt_4_propose` | `agt_2_propose` |
| `hum_3_act` | `hum_2_act` |
| `hum_4_dismiss` | `hum_3_dismiss` |
| `fwk_4_any` | `fwk_gw_any` |
| `agt_3_diagnosis` | `agt_gw_diagnosis` |
| `hum_2_triage` | `hum_gw_triage` |
| `fwk_5_emit` | `fwk_link_emit` |
| `agt_6_handoff` | `agt_link_handoff` |
| `agt_1_trigger` | `agt_message_trigger` |

## draft-trigger-handling/v3

| old | new |
|---|---|
| `fwk_1_observation` | `fwk_start_observation` |
| `fwk_6_quiet` | `fwk_end_quiet` |
| `hum_5_acted` | `hum_end_acted` |
| `hum_7_parked` | `hum_end_parked` |
| `hum_6_dismissed` | `hum_end_dismissed` |
| `fwk_2_collect` | `fwk_1_collect` |
| `fwk_3_evaluate` | `fwk_2_evaluate` |
| `agt_2_diagnose` | `agt_1_diagnose` |
| `agt_5_propose` | `agt_3_propose` |
| `agt_4_propose` | `agt_2_propose` |
| `hum_3_act` | `hum_2_act` |
| `hum_4_dismiss` | `hum_3_dismiss` |
| `fwk_4_any` | `fwk_gw_any` |
| `agt_3_diagnosis` | `agt_gw_diagnosis` |
| `hum_2_triage` | `hum_gw_triage` |
| `fwk_5_emit` | `fwk_link_emit` |
| `agt_6_handoff` | `agt_link_handoff` |
| `agt_1_trigger` | `agt_message_trigger` |

## draft-trigger-handling/v4

| old | new |
|---|---|
| `fwk_1_observation` | `fwk_start_observation` |
| `fwk_6_quiet` | `fwk_end_quiet` |
| `hum_5_acted` | `hum_end_acted` |
| `hum_7_parked` | `hum_end_parked` |
| `hum_6_dismissed` | `hum_end_dismissed` |
| `fwk_2_collect` | `fwk_1_collect` |
| `fwk_3_evaluate` | `fwk_2_evaluate` |
| `agt_2_diagnose` | `agt_1_diagnose` |
| `agt_5_propose` | `agt_3_propose` |
| `agt_4_propose` | `agt_2_propose` |
| `hum_3_act` | `hum_2_act` |
| `hum_4_dismiss` | `hum_3_dismiss` |
| `fwk_4_any` | `fwk_gw_any` |
| `agt_3_diagnosis` | `agt_gw_diagnosis` |
| `hum_2_triage` | `hum_gw_triage` |
| `fwk_5_emit` | `fwk_link_emit` |
| `agt_6_handoff` | `agt_link_handoff` |
| `agt_1_trigger` | `agt_message_trigger` |

## draft-trigger-handling/v5

| old | new |
|---|---|
| `fwk_1_observation` | `fwk_start_observation` |
| `fwk_6_quiet` | `fwk_end_quiet` |
| `hum_5_acted` | `hum_end_acted` |
| `hum_7_parked` | `hum_end_parked` |
| `hum_6_dismissed` | `hum_end_dismissed` |
| `fwk_2_collect` | `fwk_1_collect` |
| `fwk_3_evaluate` | `fwk_2_evaluate` |
| `agt_2_diagnose` | `agt_1_diagnose` |
| `agt_5_propose` | `agt_3_propose` |
| `agt_4_propose` | `agt_2_propose` |
| `hum_3_act` | `hum_2_act` |
| `hum_4_dismiss` | `hum_3_dismiss` |
| `fwk_4_any` | `fwk_gw_any` |
| `agt_3_diagnosis` | `agt_gw_diagnosis` |
| `hum_2_triage` | `hum_gw_triage` |
| `fwk_5_emit` | `fwk_link_emit` |
| `agt_6_handoff` | `agt_link_handoff` |
| `agt_1_trigger` | `agt_message_trigger` |

## draft-trigger-handling/v6

| old | new |
|---|---|
| `fwk_1_observation` | `fwk_start_observation` |
| `fwk_6_quiet` | `fwk_end_quiet` |
| `hum_5_acted` | `hum_end_acted` |
| `hum_7_parked` | `hum_end_parked` |
| `hum_6_dismissed` | `hum_end_dismissed` |
| `fwk_2_collect` | `fwk_1_collect` |
| `fwk_3_evaluate` | `fwk_2_evaluate` |
| `agt_2_diagnose` | `agt_1_diagnose` |
| `agt_5_propose` | `agt_3_propose` |
| `agt_4_propose` | `agt_2_propose` |
| `hum_3_act` | `hum_2_act` |
| `hum_4_dismiss` | `hum_3_dismiss` |
| `fwk_4_any` | `fwk_gw_any` |
| `agt_3_diagnosis` | `agt_gw_diagnosis` |
| `hum_2_triage` | `hum_gw_triage` |
| `fwk_5_emit` | `fwk_link_emit` |
| `agt_6_handoff` | `agt_link_handoff` |
| `agt_1_trigger` | `agt_message_trigger` |
