# Jac architecture upgrade plan

This implementation plan is the decision record for the production-shaped
backend upgrade. It does not authorize deployment or real patient data.

## Rollback and checkpoints

- Clean rollback commit: `865677e`.
- Audit/characterization checkpoint: created before schema changes.
- Canonical-topology checkpoint: created after graph/walker/provenance tests.
- Final commit: `upgrade Pa-Co to production-shaped Jac-native architecture`.
- Push only `origin/backend-jac`; never rewrite or merge history.

Before schema edits, copy ignored `.jac/data` to a temporary backup, then
rebuild it from the deterministic synthetic seed. No tracked file or external
database is involved.

## Target topology

```text
Root -HasSession-> DemoSession -HasPatient-> Patient -HasEncounter-> Encounter
Encounter -ContainsChunk-> TranscriptChunk
Encounter -HasCandidate-> CandidateFact -ExtractedFrom-> TranscriptChunk
CandidateFact -PromotedTo-> VerifiedFact -VerifiedFrom-> CandidateFact
Encounter -HasVerifiedFact-> VerifiedFact
VerifiedFact -RepresentsLabOrder/FollowUp/Medication/Referral-> obligation
Encounter -HasTask-> CareTask -DependsOn-> VerifiedFact
CareTask -AssignedTo-> CareOwner
Encounter -HasGap-> CareGap -ResolvedBy-> GapResolutionEvent
Patient -HasBrief-> PatientBrief -HasChecklistItem-> ChecklistItem
ChecklistItem -SupportedBy-> VerifiedFact
Patient -HasQuestion-> PatientQuestion -HasAnswer-> PatientAnswer
PatientAnswer -AnsweredFrom-> VerifiedFact
Encounter -HasConflict-> Conflict -ConflictEvidence(role)-> VerifiedFact
```

Every `CareNode` also retains `SessionOwns` solely for reset and an explicit
`session_id` defense-in-depth assertion.

## Implementation sequence

1. Add string-backed enums, additive DTO fields, output/provenance DTOs, event
   and output nodes, and endpoint-constrained domain edges.
2. Rewrite projections to traverse patient/encounter relationships and expose a
   session-scoped relationship DTO list.
3. Rewrite ingest and verification with mismatch detection, decision events,
   explicit obligation edges, and per-obligation tasks.
4. Rewrite gap detection/resolution, plan, question, audit, provenance, and
   reset as real walkers with actual traversal traces.
5. Keep the 12 public `def:pub` signatures stable and add only
   `trace_provenance(output_id, session_id)`.
6. Harden AI validation, add enum-typed results where compatible, configure one
   output retry, and add diagnostic malformed-mock mode.
7. Verify generated HTTP routes, restart persistence, graph visualization,
   logical session isolation, and private-root capability.
8. Run every prior test plus the expanded suite and twenty full acceptance
   cycles before final documentation and push.

## Backward compatibility

- Existing public action names, parameter order, defaults, DTO field names, and
  safe fallback text remain unchanged.
- New DTO fields have safe defaults and are additive.
- Raw REST consumers continue reading the typed result from
  `data.result` inside Jac's generated transport envelope.
- Existing frontend-owned files are never edited.

## Intentionally omitted

- production login in the hackathon flow;
- HIPAA/compliance claims;
- cloud deployment;
- real patient ingestion;
- local-model download or newly created paid API key;
- ModelPool, tools, AI graph mutation, and AI-guided traversal;
- automated clinical conflict resolution;
- a second server, ORM, or database.
