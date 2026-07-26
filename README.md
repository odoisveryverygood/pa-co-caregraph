# Pa-Co CareGraph

Pa-Co CareGraph is a Jac-native verified continuity-of-care graph that turns synthetic consultation information into clinician-approved, traceable patient follow-up plans.

The deterministic Jac backend is ready for frontend integration. Frontend
development is proceeding separately.

## Backend status

The P0 backend runs entirely on Jac 0.34.7. It ingests a deterministic synthetic
consultation, exposes candidate facts for clinician review, promotes only
accepted facts into a persistent care graph, detects documentation gaps,
records audited resolutions, builds an approved-only patient brief, answers
questions from graph evidence, and preserves contradictory statements for
review.

No model API or credential is required for the reliable demo. Optional typed
AI can propose unverified candidates, translate or simplify an approved brief,
and match questions to an allow-list of verified fact IDs. Every optional path
is validated and falls back deterministically. The backend does not diagnose,
recommend medication, change dosage, determine treatment safety, perform
emergency triage, or invent missing facts.

The exact frontend contract, typed response objects, errors, and payload
examples are in [CONTRACT.md](CONTRACT.md).

## Run the backend

Prerequisite:

```bash
jac --version
```

The required version is `jac 0.34.7`. Start the API-only service:

```bash
jac start main.jac --no-client
```

The service is available at <http://localhost:8000>, Swagger at
<http://localhost:8000/docs>, and health status at
<http://localhost:8000/healthz>.

## Verify the backend

Run static checks and the complete backend suite:

```bash
jac check .
jac clean --data --force
jac test -d tests/
```

Run the full P0 acceptance flow three consecutive times:

```bash
jac clean --data --force
jac run tests/p0_demo.jac
```

Run the complete flow with AI enabled through Jac `MockLLM`, AI disabled,
missing live credentials, and mock output:

```bash
jac clean --data --force
env -u OPENAI_API_KEY -u ANTHROPIC_API_KEY -u GOOGLE_API_KEY \
  -u PA_CO_AI_API_KEY -u BYLLM_DEFAULT_MODEL \
  PA_CO_AI_MODEL=gpt-4o-mini jac run tests/ai_modes_demo.jac
```

The acceptance script resets each synthetic session, verifies four facts,
rejects the language candidate, detects and resolves the two prepared gaps,
generates a brief, answers the blood-test question, creates the four-week
contradiction, audits it, and confirms both follow-up statements remain.

## Graph schema

The graph is rooted by a synthetic `DemoSession`; every owned node also has a
`SessionOwns` link so reset can remove only that session's demonstration data.

```text
Root
└── DemoSession
    ├── Patient ──HasEncounter──> Encounter
    │                              ├──ContainsChunk──> TranscriptChunk
    │                              ├──HasCandidate───> CandidateFact
    │                              └──HasVerifiedFact> VerifiedFact
    ├── CareGap
    ├── CareTask ──AssignedTo────> CareOwner
    │             └─DependsOn────> VerifiedFact
    ├── Conflict
    └── PatientQuestion ─AnsweredFrom─> VerifiedFact

CandidateFact ─ExtractedFrom─> TranscriptChunk
VerifiedFact  ─VerifiedFrom──> CandidateFact
VerifiedFact  ─VerifiedBy────> ClinicianIdentity
VerifiedFact  ─Materializes──> LabOrder | FollowUp | MedicationInstruction | Referral
LabOrder      ─RequiresFollowUp─> FollowUp
VerifiedFact  ─Contradicts─────> VerifiedFact
VerifiedFact  ─VisibleToPatient> PatientBrief
```

Persistent domain nodes are defined in `models.sv.jac`. Candidate provenance is
immutable in the public interface, and `VerifiedFact` construction exists only
inside `VerificationWalker`.

## Walkers

- `ConsultationIngestWalker` creates the prepared chunks and source-linked
  candidates idempotently.
- `VerificationWalker` is the sole promotion boundary. Rejection never creates
  a verified node; repeated acceptance returns the existing verified fact.
- `CareGapWalker` performs documentation-completeness checks and persists each
  unique gap once.
- `GapResolutionWalker` validates required resolution fields, updates the
  relevant care node, creates a task/owner relationship, and appends an audit
  record.
- `PatientPlanWalker` traverses approved, patient-visible, non-conflicting
  facts only and stores a sourced `PatientBrief`.
- `PatientQuestionWalker` answers only through verified nodes and resolved
  tasks. Unknown questions use the exact safe fallback.
- `EvidenceAuditWalker` detects duplicates, unverified attempted changes,
  superseded facts, and contradictory follow-up periods without choosing a
  clinical winner.
- `ResetDemoWalker` deletes only nodes owned by the named synthetic session and
  recreates the exact prepared state.

## Public actions

The frontend-callable Jac functions are:

```text
load_demo_encounter(session_id="demo-default", ai_mode="disabled")
get_candidate_facts(session_id="demo-default")
verify_fact(fact_id, decision, clinician_id, session_id="demo-default")
get_care_graph(session_id="demo-default")
run_care_gap_check(session_id="demo-default")
resolve_gap(gap_id, resolution, owner, due_date, session_id="demo-default")
generate_patient_plan(language, session_id="demo-default", ai_mode="disabled")
simplify_patient_plan(session_id="demo-default", ai_mode="live")
ask_patient_question(question, session_id="demo-default", ai_mode="disabled")
run_evidence_audit(session_id="demo-default")
reset_demo(session_id="demo-default")
add_demo_contradiction(session_id="demo-default")
```

Jac exposes these at `POST /function/<action>` for raw REST consumers. Jac
clients should import and call them as typed server functions.

## Frontend integration

From a client-owned Jac module:

```jac
sv import from endpoints {
    load_demo_encounter,
    get_candidate_facts,
    verify_fact,
    get_care_graph,
    run_care_gap_check,
    resolve_gap,
    generate_patient_plan,
    simplify_patient_plan,
    ask_patient_question,
    run_evidence_audit,
    reset_demo,
    add_demo_contradiction,
}
sv import from models {
    BackendResponse,
    CandidateFactDTO,
    CareGraphDTO,
    PatientPlanDTO,
}
```

Calls from client async handlers must be awaited, for example:

```jac
response: BackendResponse = await load_demo_encounter();
```

Use the default session for the shared demo or pass a stable per-browser
`session_id`. Treat `BackendResponse.success` as the branch point and display
`message` for a recoverable failure. Do not reconstruct graph rules or
candidate promotion in frontend code.

## Deterministic fallback and optional AI seam

`extraction.sv.jac` contains the five prepared facts and the later
contradiction. The default P0 path never calls a model. `ai.sv.jac` contains
Jac 0.34.7-compatible typed `by llm()` functions and deterministic
`MockLLM` providers.

Live AI is opt-in:

```bash
export PA_CO_AI_MODEL="gpt-4o-mini"
export OPENAI_API_KEY="<provider key>"
```

`PA_CO_AI_API_KEY` is also supported by `jac.toml`. For another provider, set
the model plus its standard variable (`ANTHROPIC_API_KEY` or
`GOOGLE_API_KEY`). `BYLLM_DEFAULT_MODEL` overrides the configured model.
Ollama and installed Jac local models do not require a key.

The checked-in settings use temperature `0.0`, at most one typed-output
correction retry, a 1200-token output cap, and an eight-second request timeout.
Never place a key in `jac.toml`, source, tests, or `.env.example`.

AI extraction receives only synthetic chunk IDs, speakers, and transcript
text. Results are checked for required fields, category allow-list, source
existence, verbatim evidence, confidence range, prohibited medical behavior,
and duplicates. Deterministic code can then store them only as pending
`CandidateFact` nodes. `VerificationWalker` remains the sole promotion path.

Translation and simplification operate only on an approved English
`PatientBrief`; dates, numbers, structure, and source IDs are validated.
Question AI returns verified IDs only. Deterministic code retrieves those
nodes and composes the answer.

Fallback behavior:

- extraction failure loads the five prepared pending candidates;
- translation/simplification failure returns approved English unchanged;
- provider failure during question matching uses deterministic graph matching;
- an unknown or unverified returned ID is denied and uses the exact safe
  fallback;
- credentials, provider exceptions, timeout, malformed/empty output, and
  validation failures never crash the demo.

## Known limitations

- Only the prepared synthetic Maya Rivera encounter is implemented.
- The backend has no production identity, authorization, or real-patient-data
  ingestion; it must not be used with protected health information.
- English and Spanish are supported; deterministic Spanish remains available
  with AI disabled, and validated AI translation is optional.
- Conflict resolution is intentionally manual and not part of P0.
- Due dates are P0 strings rather than timezone-aware clinical scheduling
  objects.

## Safety boundaries

- Candidate, pending, and rejected facts never enter patient-facing output.
- Every patient checklist item and grounded answer includes verified source fact
  IDs.
- Contradictions create `Conflict` nodes and preserve both source statements.
- Unknown patient questions return: “This is not recorded in your approved care
  plan. Please contact your clinic.”
- Reset is restricted to synthetic sessions and cannot traverse unrelated
  graph roots.

## Backend files

- `main.jac`
- `jac.toml`
- `models.sv.jac`
- `extraction.sv.jac`
- `ai.sv.jac`
- `walkers.sv.jac`
- `patient_agent.sv.jac`
- `endpoints.sv.jac`
- `tests/backend_tests.jac`
- `tests/p0_demo.jac`
- `tests/ai_tests.jac`
- `tests/ai_modes_demo.jac`
- `CONTRACT.md`
- backend sections of `README.md`

Because a Git commit cannot contain its own hash without changing that hash,
the exact verified backend commit is reported in the handoff. At any checkout,
obtain the current hash with:

```bash
git rev-parse HEAD
```
