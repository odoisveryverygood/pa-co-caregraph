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
- [x] Expose the ten required frontend actions plus the demo-only contradiction
      action.
- [x] Enforce patient-visibility, provenance, contradiction, and reset
      invariants.
- [x] Add at least twenty backend tests.
- [x] Run static checks, the complete test suite, and the P0 flow three times.

## Common response envelope

Every frontend-callable action returns `BackendResponse`.

```text
BackendResponse
- success: bool
- error_code: str
- message: str
- recoverable: bool
- current_graph_version: int
- demo_state: DemoStateDTO | None
- candidate_facts: list[CandidateFactDTO]
- verified_fact: VerifiedFactDTO | None
- care_graph: CareGraphDTO | None
- care_gaps: list[CareGapDTO]
- patient_plan: PatientPlanDTO | None
- patient_answer: PatientAnswerDTO | None
- conflicts: list[ConflictDTO]
```

On success, `success` is `true`, `error_code` is empty, and the action-specific
field contains the result. On failure, `success` is `false`, `error_code` and
`message` are populated, `recoverable` states whether corrected input can be
retried, and `current_graph_version` is included whenever a demo session was
found. Unused result fields are empty or `None`.

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

PatientAnswerDTO
- answer: str
- grounded: bool
- source_fact_ids: list[str]
- fallback_used: bool

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
```

Output: `BackendResponse.demo_state`. It contains Maya Rivera, five ordered
transcript chunks, five pending candidate facts, and no verified facts.

Possible errors: `INVALID_SESSION_ID`.

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
```

Output: `BackendResponse.patient_plan`.

Possible errors: `DEMO_NOT_LOADED`, `INVALID_LANGUAGE`, `NO_VISIBLE_FACTS`,
`ACTIVE_CARE_GAPS`.

Example request:

```json
{"language": "English", "session_id": "demo-default"}
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
patient-visible, non-conflicting facts only.

### `ask_patient_question`

Inputs:

```text
question: str
session_id: str = "demo-default"
```

Output: `BackendResponse.patient_answer`.

Possible errors: `DEMO_NOT_LOADED`, `INVALID_QUESTION`.

Example request:

```json
{"question": "When is my blood test?", "session_id": "demo-default"}
```

Example response:

```json
{
  "success": true,
  "patient_answer": {
    "answer": "Your blood test is due this week and is assigned to clinic-lab-team.",
    "grounded": true,
    "source_fact_ids": ["verified-candidate-lab"],
    "fallback_used": false
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
- The P0 flow uses no model provider and requires no API key.
