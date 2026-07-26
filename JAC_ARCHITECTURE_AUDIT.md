# Jac architecture red-team audit

Audit baseline: commit `865677e` on `backend-jac`, Jac 0.34.7.

## Current topology

The current graph persists from `Root -> DemoSession`. A typed
`SessionOwns` edge connects the session to every care node for reset. Domain
edges connect patient, encounter, evidence, verified facts, specialized
obligations, tasks, gaps, conflicts, briefs, and questions.

The model already enforces important foundations:

- transcript chunks and candidates are persistent nodes;
- candidate provenance uses `ExtractedFrom`;
- accepted facts use `VerifiedFrom` and `VerifiedBy`;
- rejection creates no `VerifiedFact`;
- specialized obligations are persistent;
- gaps, tasks, resolution audits, conflicts, briefs, and questions persist;
- reset deletes only nodes connected to the selected synthetic session;
- no mutable module-level list or dictionary stores clinical graph state.

## Feature audit

| Feature | Source of truth | Current traversal | Responsible walker/action | Red-team finding |
|---|---|---|---|---|
| Session | `DemoSession` reachable from root | Root query by session ID | All walkers | Sound, but root edge is generic and not judge-visible as `HasSession`. |
| Patient/encounter | `Patient -> HasEncounter -> Encounter` | Domain edges | Ingest/projections | Sound. |
| Transcript | `Encounter -> ContainsChunk -> TranscriptChunk` | Domain edges | Ingest/projections | Sound and ordered, but initialization silently returns if a patient already exists instead of detecting mismatched seed state. |
| Candidates | `Encounter -> HasCandidate -> CandidateFact -> ExtractedFrom -> TranscriptChunk` | Domain edges for DTOs; session ownership scan for verification | Ingest/proposal/verification | Provenance is sound, but verification should navigate through patient and encounter. |
| Verification | `VerifiedFact`, candidate status, verifier fields | `SessionOwns` candidate scan | `VerificationWalker` | Only this walker promotes facts, but no persistent decision event or forward `PromotedTo` path exists. |
| Specialized obligation | Lab/follow-up/medication/referral nodes | Generic `Materializes` edge | Verification and downstream walkers | Generic target weakens the domain model; replace clinical reads with four explicit typed relationships. |
| Care gaps | `CareGap` nodes | Session-wide ownership scans of obligation types | `CareGapWalker` | Results are topology-derived, not fixed constants, but traversal does not demonstrate patient/encounter/verified-obligation navigation. |
| Resolution | Gap fields, specialized node fields, task, owner, audit node | Gap edge plus ownership lookup | `GapResolutionWalker` | Audited, but related resources are found by string ID and ownership scan; task-to-obligation topology should be authoritative. |
| Patient plan | `PatientBrief` plus embedded DTO lists and checklist strings | Ownership scan of all verified facts | `PatientPlanWalker` | Approved-only filtering works, but individual checklist items are not nodes and cannot be traversed backward. |
| Patient answer | Fields on `PatientQuestion` | Ownership scan of verified facts | `PatientQuestionWalker` | Grounded and safe, but answer is not its own node and the blood-test matcher is over-specialized. |
| Evidence audit | `Conflict` plus direct `Contradicts` edge | Ownership scan of all facts/candidates | `EvidenceAuditWalker` | Both statements persist, but a `Conflict` is not connected to both evidence nodes and stale patient outputs are not invalidated. |
| Reset | `SessionOwns` ownership boundary | Session ownership traversal | `ResetDemoWalker` | Correctly scoped; retain this single use of the ownership index. |
| Optional AI | Plain typed objects and status DTOs | No graph mutation in AI functions | AI helpers + proposal walker | Boundary is sound. Add enum typing, stronger injection validation, and explicit malformed mock mode. |

## Mutable collection classification

No collection below is a second persistent clinical record.

| Collection | Classification | Decision |
|---|---|---|
| Prepared transcript/candidate lists | Hardcoded synthetic input fixture | Keep. They seed the deterministic demonstration; they are not computed output. |
| AI allow-list and prohibited phrase lists | Validation policy | Keep and extend for instruction injection. |
| Walker `facts`, plan item, source-ID, trace, and visited-ID lists | Legitimate temporary walker state | Keep typed and reset per spawn. |
| DTO lists assembled by `build_demo_state`/`build_care_graph` | Serialization projection | Keep, but derive only from domain topology. |
| `SessionOwns` outgoing node collection | Graph ownership index | Keep only for session-scoped deletion and ownership assertions. |
| Question `allowed_fact_ids` | Request-scoped allow-list | Keep; validate every ID through current-session topology. |
| Candidate duplicate keys | Temporary validation lookup | Keep in-memory for one model response. |
| `PatientBrief` embedded plan lists | Persistent output snapshot | Keep for contract compatibility, but add canonical checklist item nodes and mark stale snapshots non-current. |

## Hardcoding assessment

- The Maya transcript, five candidates, expected administrative gaps, and
  later four-week contradiction are intentional deterministic demo fixtures.
- Gap responses are not fixed return constants; they are derived from absent
  fields on persisted obligations. The upgrade will derive them from absent
  relationships as well.
- Patient plan text is deterministic formatting of graph fields, which is
  legitimate. It must remain source-bound.
- The current blood-test question branch checks literal `"blood"` and emits a
  fixed noun phrase. Replace it with category-aware matching and answer
  assembly using the stored test name, due window, and assigned task owner.
- Spanish deterministic text is an approved fallback fixture, not an AI claim.

## Security and persistence findings

- `def:pub` actions run anonymous requests on Jac's shared guest root. A
  `session_id` is a logical demo partition, not an authorization credential.
- Built-in private roots are supported but are not used by the main demo.
- Jac's development server warns about bootstrap admin credentials and a test
  JWT secret. The application must remain local and synthetic and must not be
  represented as production-secure or HIPAA-compliant.
- `.jac/`, databases, logs, secrets, and private/real patient paths are ignored.
- Schema changes require cleaning or migrating ignored local graph data. This
  repository has only deterministic synthetic runtime state, so back up and
  rebuild it rather than pretending to provide a production data migration.

## Required corrections

1. Use `SessionOwns` only for ownership/reset.
2. Add explicit relationship types for specialized obligations and output
   provenance.
3. Persist verification/resolution events, checklist items, and answers.
4. Make care-gap, plan, question, audit, and provenance operations visibly
   traverse the domain topology.
5. Instrument trace steps at actual traversal abilities.
6. Invalidate stale patient outputs when supporting graph state changes.
7. Preserve every existing public request signature and response field.
