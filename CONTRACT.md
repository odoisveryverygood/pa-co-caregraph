# Pa-Co CareGraph backend contract

Status: P0 contract for Jac 0.34.7. The frontend may depend on every type and
action documented here. Contract changes after frontend integration require a
documented migration note and coordination with the frontend owner.

## Ownership boundary

The backend owner controls:

- `main.jac`
- `jac.toml`
- `models.sv.jac`
- `extraction.sv.jac`
- `ai.sv.jac`
- `walkers.sv.jac`
- `patient_agent.sv.jac`
- `endpoints.sv.jac`
- `tests/`
- `CONTRACT.md`
- backend sections of `README.md`

The frontend owner controls `frontend.cl.jac`, `frontend.impl.jac`,
`components/`, `styles/`, frontend mock data, and frontend tests. Backend work
must not edit those paths.

## Implementation checklist

- [x] Define typed DTOs, graph nodes, and typed relationships.
- [x] Seed the deterministic Maya Rivera encounter without an AI dependency.
- [x] Implement ingest, verification, gap, resolution, plan, question, audit,
      and reset walkers.
- [x] Expose the ten required frontend actions, optional plan simplification,
      and the demo-only contradiction action.
- [x] Enforce patient-visibility, provenance, contradiction, and reset
      invariants.
- [x] Add at least twenty backend tests.
- [x] Run static checks, the complete test suite, and the P0 flow three times.
- [x] Add optional typed extraction, Spanish translation, simplification, and
      verified-fact question matching with deterministic fallbacks.
- [x] Validate AI modes with `MockLLM`, no credentials, simulated provider
      errors, simulated timeout, malformed output, and disabled AI.

## Common response envelope

Every frontend-callable action returns `BackendResponse`.

```text
BackendResponse
- success: bool
- error_code: str
- message: str
- recoverable: bool
- current_graph_version: int
- ai_status: AIStatusDTO | None
- extracted_candidates: list[ExtractedCandidate]
- demo_state: DemoStateDTO | None
- candidate_facts: list[CandidateFactDTO]
- verified_fact: VerifiedFactDTO | None
- care_graph: CareGraphDTO | None
- care_gaps: list[CareGapDTO]
- patient_plan: PatientPlanDTO | None
- patient_answer: PatientAnswerDTO | None
- conflicts: list[ConflictDTO]
```

On full success, `success` is `true`, `error_code` is empty, and the
action-specific field contains the result. A recovered optional-AI failure also
returns `success: true` because the deterministic result is usable, while
`recoverable: true`, `error_code`, and `ai_status.fallback_used` describe the
degraded AI attempt. On unrecovered failure, `success` is `false`. Unused
result fields are empty or `None`.

Jac clients receive the typed `BackendResponse` directly. Raw REST consumers
receive Jac's standard transport envelope and read the object at
`data.result`:

```json
{
  "ok": true,
  "type": "response",
  "data": {"result": {"success": true}, "reports": []},
  "error": null
}
```

## Required DTOs

```text
ExtractedCandidate
- category: str
- value: str
- source_text: str
- source_chunk_id: str
- confidence: float
- patient_visible_candidate: bool

AIStatusDTO
- requested: bool
- used: bool
- fallback_used: bool
- mode: str
- diagnostic_code: str
- diagnostic_message: str

CandidateFactDTO
- id: str
- category: str
- value: str
- source_chunk_id: str
- source_text: str
- confidence: float
- status: str
- created_at: str

VerifiedFactDTO
- id: str
- category: str
- value: str
- source_chunk_id: str
- source_text: str
- verified_by: str
- verified_at: str
- visible_to_patient: bool

CareGapDTO
- id: str
- gap_type: str
- message: str
- related_fact_ids: list[str]
- resolved: bool
- resolution: str
- owner: str
- due_date: str

PlanItemDTO
- kind: str
- text: str
- owner: str
- due_date: str
- status: str
- source_fact_id: str

PatientPlanDTO
- patient_id: str
- language: str
- medications: list[PlanItemDTO]
- labs: list[PlanItemDTO]
- referrals: list[PlanItemDTO]
- follow_ups: list[PlanItemDTO]
- checklist: list[str]
- source_fact_ids: list[str]
- generated_at: str
- ai_enhanced: bool
- translation_fallback_used: bool
- simplification_fallback_used: bool

PatientAnswerDTO
- answer: str
- grounded: bool
- source_fact_ids: list[str]
- fallback_used: bool
- ai_matching_used: bool

PatientDTO
- id: str
- display_name: str
- preferred_language: str
- synthetic: bool

EncounterDTO
- id: str
- occurred_at: str
- status: str

TranscriptChunkDTO
- id: str
- sequence: int
- speaker: str
- text: str

ConflictDTO
- id: str
- left_fact_id: str
- right_fact_id: str
- conflict_type: str
- explanation: str
- resolved: bool
- left_source_text: str
- right_source_text: str

CareGraphDTO
- patient: PatientDTO | None
- encounter: EncounterDTO | None
- transcript: list[TranscriptChunkDTO]
- candidate_facts: list[CandidateFactDTO]
- verified_facts: list[VerifiedFactDTO]
- care_gaps: list[CareGapDTO]
- patient_plan: PatientPlanDTO | None
- conflicts: list[ConflictDTO]
- graph_version: int

DemoStateDTO
- patient: PatientDTO | None
- encounter: EncounterDTO | None
- transcript: list[TranscriptChunkDTO]
- candidate_facts: list[CandidateFactDTO]
- verified_facts: list[VerifiedFactDTO]
- care_gaps: list[CareGapDTO]
- patient_plan: PatientPlanDTO | None
- conflicts: list[ConflictDTO]
- graph_version: int
```

## Callable actions

All actions accept an optional `session_id: str = "demo-default"`. This keeps
two synthetic browser/test sessions isolated while preserving a zero-config
default for the demo UI.

### `load_demo_encounter`

Inputs:

```text
session_id: str = "demo-default"
ai_mode: str = "disabled"
```

Output: `BackendResponse.demo_state`. It contains Maya Rivera, five ordered
transcript chunks, five pending candidate facts, and no verified facts.

`ai_mode` is `disabled`, `live`, or `mock`. `disabled` preserves the original
deterministic ingest. `live` invokes typed `by llm()` extraction only for a
fresh synthetic session. `mock` is the keyless deterministic `MockLLM` path
used in tests. AI proposals are schema- and provenance-validated and persisted
only as pending candidates. Any AI failure loads the five prepared candidates.

Possible errors: `INVALID_SESSION_ID`, `AI_MODE_INVALID`,
`AI_SESSION_ALREADY_INITIALIZED`. Recovered AI diagnostic codes include
`AI_CREDENTIALS_MISSING`, `AI_TIMEOUT`, `AI_PROVIDER_ERROR`,
`AI_MALFORMED_OUTPUT`, `AI_EMPTY_OUTPUT`, `AI_UNSUPPORTED_CATEGORY`,
`AI_SOURCE_CHUNK_NOT_FOUND`, `AI_SOURCE_EVIDENCE_MISSING`,
`AI_INVALID_CONFIDENCE`, `AI_PROHIBITED_MEDICAL_CONTENT`, and
`AI_DUPLICATE_CANDIDATE`.

Example request:

```json
{"session_id": "demo-default", "ai_mode": "disabled"}
```

Example response:

```json
{
  "success": true,
  "current_graph_version": 1,
  "demo_state": {
    "patient": {
      "id": "patient-maya",
      "display_name": "Maya Rivera",
      "preferred_language": "Spanish",
      "synthetic": true
    },
    "candidate_facts": [
      {
        "id": "candidate-lab",
        "category": "lab_order",
        "value": "blood test; due this week",
        "source_chunk_id": "chunk-1",
        "source_text": "We will order a blood test to be completed this week.",
        "confidence": 1.0,
        "status": "pending",
        "created_at": "2026-07-26T18:00:01Z"
      }
    ],
    "graph_version": 1
  }
}
```

Changes graph state: yes, only when the named synthetic session does not yet
exist.

### `get_candidate_facts`

Inputs:

```text
session_id: str = "demo-default"
```

Output: `BackendResponse.candidate_facts`, ordered by source transcript
sequence.

Possible errors: `DEMO_NOT_LOADED`.

Example request:

```json
{"session_id": "demo-default"}
```

Example response:

```json
{
  "success": true,
  "current_graph_version": 1,
  "candidate_facts": [
    {
      "id": "candidate-lab",
      "category": "lab_order",
      "value": "blood test; due this week",
      "source_chunk_id": "chunk-1",
      "source_text": "We will order a blood test to be completed this week.",
      "confidence": 1.0,
      "status": "pending",
      "created_at": "2026-07-26T18:00:01Z"
    }
  ]
}
```

Changes graph state: no.

### `verify_fact`

Inputs:

```text
fact_id: str
decision: str  # "accept" or "reject"
clinician_id: str
session_id: str = "demo-default"
```

Output: `BackendResponse.verified_fact` for an accepted fact. For a rejection,
the field is `None` and the candidate status is returned through a subsequent
state read.

Possible errors: `DEMO_NOT_LOADED`, `FACT_NOT_FOUND`, `INVALID_DECISION`,
`INVALID_CLINICIAN_ID`, `FACT_ALREADY_DECIDED`.

Example request:

```json
{
  "fact_id": "candidate-lab",
  "decision": "accept",
  "clinician_id": "clinician-1",
  "session_id": "demo-default"
}
```

Example response:

```json
{
  "success": true,
  "current_graph_version": 2,
  "verified_fact": {
    "id": "verified-candidate-lab",
    "category": "lab_order",
    "value": "blood test; due this week",
    "source_chunk_id": "chunk-1",
    "source_text": "We will order a blood test to be completed this week.",
    "verified_by": "clinician-1",
    "verified_at": "2026-07-26T18:00:02Z",
    "visible_to_patient": true
  }
}
```

Changes graph state: yes. Only `VerificationWalker` can create the verified
record and specialized care node.

### `get_care_graph`

Inputs:

```text
session_id: str = "demo-default"
```

Output: `BackendResponse.care_graph`.

Possible errors: `DEMO_NOT_LOADED`.

Example request:

```json
{"session_id": "demo-default"}
```

Example response:

```json
{
  "success": true,
  "current_graph_version": 4,
  "care_graph": {
    "patient": {"id": "patient-maya", "display_name": "Maya Rivera"},
    "candidate_facts": [],
    "verified_facts": [],
    "care_gaps": [],
    "conflicts": [],
    "graph_version": 4
  }
}
```

Changes graph state: no.

### `run_care_gap_check`

Inputs:

```text
session_id: str = "demo-default"
```

Output: `BackendResponse.care_gaps`, containing unresolved documentation gaps
only.

Possible errors: `DEMO_NOT_LOADED`, `NO_VERIFIED_FACTS`.

Example request:

```json
{"session_id": "demo-default"}
```

Example response:

```json
{
  "success": true,
  "current_graph_version": 6,
  "care_gaps": [
    {
      "id": "gap-lab-owner-verified-candidate-lab",
      "gap_type": "lab_owner_missing",
      "message": "The blood test does not have a responsible owner.",
      "related_fact_ids": ["verified-candidate-lab"],
      "resolved": false,
      "resolution": "",
      "owner": "",
      "due_date": ""
    },
    {
      "id": "gap-follow-up-date-verified-candidate-follow-up",
      "gap_type": "follow_up_date_missing",
      "message": "The follow-up period is recorded but no appointment date is scheduled.",
      "related_fact_ids": ["verified-candidate-follow-up"],
      "resolved": false,
      "resolution": "",
      "owner": "",
      "due_date": ""
    }
  ]
}
```

Changes graph state: yes only when a newly detected gap is persisted. Repeated
checks are idempotent.

### `resolve_gap`

Inputs:

```text
gap_id: str
resolution: str
owner: str
due_date: str
session_id: str = "demo-default"
```

Output: `BackendResponse.demo_state` with the updated specialized node, task,
gap, and audit history reflected.

Possible errors: `DEMO_NOT_LOADED`, `GAP_NOT_FOUND`, `GAP_ALREADY_RESOLVED`,
`INVALID_RESOLUTION`, `INVALID_OWNER`, `INVALID_DUE_DATE`.

Example request:

```json
{
  "gap_id": "gap-lab-owner-verified-candidate-lab",
  "resolution": "Assigned blood-test coordination",
  "owner": "clinic-lab-team",
  "due_date": "this week",
  "session_id": "demo-default"
}
```

Example response:

```json
{
  "success": true,
  "current_graph_version": 7,
  "demo_state": {
    "care_gaps": [],
    "graph_version": 7
  }
}
```

Changes graph state: yes. Resolution is append-audited; provenance is never
replaced.

### `generate_patient_plan`

Inputs:

```text
language: str
session_id: str = "demo-default"
ai_mode: str = "disabled"
```

Output: `BackendResponse.patient_plan`.

When `ai_mode` is `live` or `mock` and `language` is Spanish, deterministic
code first persists an approved English `PatientBrief`; AI translates only its
text projection. Dates, numbers, checklist count, and source IDs are validated.
Translation failure returns that approved English plan with
`translation_fallback_used: true`.

Possible errors: `DEMO_NOT_LOADED`, `INVALID_LANGUAGE`, `UNSUPPORTED_LANGUAGE`,
`NO_VISIBLE_FACTS`, `ACTIVE_CARE_GAPS`, `AI_MODE_INVALID`. Recovered AI
failures are reported through `ai_status`.

Example request:

```json
{"language": "Spanish", "session_id": "demo-default", "ai_mode": "mock"}
```

Example response:

```json
{
  "success": true,
  "patient_plan": {
    "patient_id": "patient-maya",
    "language": "English",
    "medications": [],
    "labs": [
      {
        "kind": "lab",
        "text": "Complete the blood test this week.",
        "owner": "clinic-lab-team",
        "due_date": "this week",
        "status": "ordered",
        "source_fact_id": "verified-candidate-lab"
      }
    ],
    "referrals": [],
    "follow_ups": [],
    "checklist": [
      "Complete the blood test this week. [source: verified-candidate-lab]"
    ],
    "source_fact_ids": ["verified-candidate-lab"],
    "generated_at": "2026-07-26T18:00:08Z"
  }
}
```

Changes graph state: yes. A `PatientBrief` is persisted using approved,
patient-visible, non-conflicting facts only. An optional translation is a
validated response projection and cannot alter verified graph nodes or source
IDs.

### `simplify_patient_plan`

Inputs:

```text
session_id: str = "demo-default"
ai_mode: str = "live"
```

Output: `BackendResponse.patient_plan`.

This action generates an approved English brief, then optionally simplifies
only its text. It preserves structure, dates, numbers, obligations, and source
IDs. On failure it returns approved English unchanged with
`simplification_fallback_used: true`.

Possible errors: `AI_MODE_INVALID`, `DEMO_NOT_LOADED`, `NO_VISIBLE_FACTS`,
`ACTIVE_CARE_GAPS`. Recovered provider, timeout, credential, or validation
failures appear in `ai_status`.

Example request:

```json
{"session_id": "demo-default", "ai_mode": "mock"}
```

Example response:

```json
{
  "success": true,
  "ai_status": {
    "requested": true,
    "used": true,
    "fallback_used": false,
    "mode": "mock"
  },
  "patient_plan": {
    "language": "English",
    "ai_enhanced": true,
    "source_fact_ids": ["verified-candidate-lab"],
    "checklist": [
      "Get the blood test this week. [source: verified-candidate-lab]"
    ]
  }
}
```

Changes graph state: yes only because the approved English `PatientBrief` is
created first. AI cannot mutate that brief or any verified graph record.

### `ask_patient_question`

Inputs:

```text
question: str
session_id: str = "demo-default"
ai_mode: str = "disabled"
```

Output: `BackendResponse.patient_answer`.

With AI enabled, the model receives only approved, patient-visible,
non-conflicting fact references and may return IDs only. Deterministic code
validates those IDs, retrieves the graph nodes, and constructs the factual
answer. Provider failure falls back to deterministic matching. An
unverified/unknown returned ID is rejected and produces the exact safe
fallback.

Possible errors: `DEMO_NOT_LOADED`, `INVALID_QUESTION`, `AI_MODE_INVALID`.
Recovered matching failures appear in `ai_status`.

Example request:

```json
{
  "question": "When is my blood test?",
  "session_id": "demo-default",
  "ai_mode": "mock"
}
```

Example response:

```json
{
  "success": true,
  "patient_answer": {
    "answer": "Your blood test is due this week and is assigned to clinic-lab-team.",
    "grounded": true,
    "source_fact_ids": ["verified-candidate-lab"],
    "fallback_used": false,
    "ai_matching_used": true
  }
}
```

Unknown-answer example:

```json
{
  "success": true,
  "patient_answer": {
    "answer": "This is not recorded in your approved care plan. Please contact your clinic.",
    "grounded": false,
    "source_fact_ids": [],
    "fallback_used": true
  }
}
```

Changes graph state: yes. The question and its verified evidence links are
stored for auditability; no medical knowledge is consulted.

### `run_evidence_audit`

Inputs:

```text
session_id: str = "demo-default"
```

Output: `BackendResponse.conflicts`.

Possible errors: `DEMO_NOT_LOADED`, `NO_VERIFIED_FACTS`.

Example request:

```json
{"session_id": "demo-default"}
```

Example response:

```json
{
  "success": true,
  "conflicts": [
    {
      "id": "conflict-verified-candidate-follow-up-verified-candidate-follow-up-4-weeks",
      "left_fact_id": "verified-candidate-follow-up",
      "right_fact_id": "verified-candidate-follow-up-4-weeks",
      "conflict_type": "contradictory_follow_up_period",
      "explanation": "Two approved follow-up periods differ; neither was overwritten.",
      "resolved": false,
      "left_source_text": "Please return in two weeks so we can review the results.",
      "right_source_text": "Please return in four weeks so we can review the results."
    }
  ]
}
```

Changes graph state: yes only when a new `Conflict` is persisted. Repeated
audits are idempotent and never pick a clinically correct side.

### `reset_demo`

Inputs:

```text
session_id: str = "demo-default"
```

Output: `BackendResponse.demo_state` containing the exact prepared initial
state.

Possible errors: `INVALID_SESSION_ID`, `NON_SYNTHETIC_SESSION`.

Example request:

```json
{"session_id": "demo-default"}
```

Example response:

```json
{
  "success": true,
  "current_graph_version": 1,
  "demo_state": {
    "patient": {"id": "patient-maya", "display_name": "Maya Rivera"},
    "candidate_facts": [
      {"id": "candidate-lab", "status": "pending"},
      {"id": "candidate-follow-up", "status": "pending"},
      {"id": "candidate-medication", "status": "pending"},
      {"id": "candidate-referral", "status": "pending"},
      {"id": "candidate-language", "status": "pending"}
    ],
    "verified_facts": [],
    "care_gaps": [],
    "conflicts": [],
    "graph_version": 1
  }
}
```

Changes graph state: yes. Only nodes owned by the named synthetic demo session
are removed and recreated.

## Demo-only backend action

### `add_demo_contradiction`

This action exists for the deterministic acceptance demo. It adds the prepared
four-week doctor statement and candidate, then invokes `VerificationWalker`
with a synthetic demo clinician. It never edits the existing two-week fact.

Inputs:

```text
session_id: str = "demo-default"
```

Output: `BackendResponse.verified_fact` for
`verified-candidate-follow-up-4-weeks`.

Possible errors: `DEMO_NOT_LOADED`, `BASE_FOLLOW_UP_NOT_VERIFIED`,
`CONTRADICTION_ALREADY_ADDED`.

Example request:

```json
{"session_id": "demo-default"}
```

Example response:

```json
{
  "success": true,
  "current_graph_version": 10,
  "verified_fact": {
    "id": "verified-candidate-follow-up-4-weeks",
    "category": "follow_up",
    "value": "return in four weeks",
    "source_chunk_id": "chunk-6",
    "source_text": "Please return in four weeks so we can review the results.",
    "verified_by": "demo-clinician",
    "verified_at": "2026-07-26T18:00:10Z",
    "visible_to_patient": true
  }
}
```

Changes graph state: yes, through deterministic ingest and
`VerificationWalker` only.

## Optional AI configuration and fallback contract

AI is off by default. No key is required for the reliable demo.

```bash
export PA_CO_AI_MODEL="gpt-4o-mini"
export OPENAI_API_KEY="<provider key>"
```

`PA_CO_AI_API_KEY` may be used instead of the provider-specific variable
because `jac.toml` maps it to `[byllm.model].api_key`. For Anthropic or Google,
set `PA_CO_AI_MODEL` plus `ANTHROPIC_API_KEY` or `GOOGLE_API_KEY`.
`BYLLM_DEFAULT_MODEL` overrides the configured model. Ollama (`ollama/...`) and
installed Jac local models (`local:...`) require no API key.

The checked-in `jac.toml` sets temperature `0.0`, output limit `1200`, and a
request timeout of eight seconds. Typed calls use one corrective output retry.
Keys remain environment-only and must never be placed in Git.

For a frontend-callable action, use:

```text
ai_mode="disabled"  deterministic path, no model call
ai_mode="live"      configured provider, validated fallback on every failure
ai_mode="mock"      deterministic Jac MockLLM, tests/demo only
```

AI extraction failure still returns five pending prepared candidates. AI
translation/simplification failure returns the approved English plan. AI
question-matching failure uses deterministic matching; an invalid returned ID
is denied and yields the exact safe fallback. In every recovered case the
top-level result remains usable and `ai_status` records a non-sensitive
diagnostic code.

## Safety invariants

- Candidate facts are never patient-visible.
- Rejected and pending candidates never enter patient plans or answers.
- Only `VerificationWalker` promotes candidates.
- Transcript source text and source-chunk links are immutable.
- Patient-facing output traverses approved, visible graph nodes only.
- Every patient-facing checklist entry and grounded answer carries source fact
  IDs.
- Unknown answers use exactly: “This is not recorded in your approved care
  plan. Please contact your clinic.”
- Contradictions preserve both statements and create a `Conflict`.
- No deterministic or optional AI pathway diagnoses, recommends medication,
  changes dosage, declares treatment safe, performs emergency triage, or fills
  missing medical facts.
- LLM functions return plain typed objects, never graph nodes.
- Only deterministic code can persist validated AI output, and it can persist
  extraction output only as `CandidateFact(status="pending")`.
- Question matching sends only verified allow-list references and never lets a
  model write the answer.
- Translation and simplification preserve source IDs outside the model.
- The deterministic P0 flow uses no model provider and requires no API key.
