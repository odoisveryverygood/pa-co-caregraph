"""Typed DTOs and persistent graph schema for Pa-Co CareGraph."""

obj CandidateFactDTO {
    has id: str = "",
        category: str = "",
        value: str = "",
        source_chunk_id: str = "",
        source_text: str = "",
        confidence: float = 0.0,
        status: str = "",
        created_at: str = "";
}

obj VerifiedFactDTO {
    has id: str = "",
        category: str = "",
        value: str = "",
        source_chunk_id: str = "",
        source_text: str = "",
        verified_by: str = "",
        verified_at: str = "",
        visible_to_patient: bool = False;
}

obj CareGapDTO {
    has id: str = "",
        gap_type: str = "",
        message: str = "",
        related_fact_ids: list[str] = [],
        resolved: bool = False,
        resolution: str = "",
        owner: str = "",
        due_date: str = "";
}

obj PlanItemDTO {
    has kind: str = "",
        text: str = "",
        owner: str = "",
        due_date: str = "",
        status: str = "",
        source_fact_id: str = "";
}

obj PatientPlanDTO {
    has patient_id: str = "",
        language: str = "",
        medications: list[PlanItemDTO] = [],
        labs: list[PlanItemDTO] = [],
        referrals: list[PlanItemDTO] = [],
        follow_ups: list[PlanItemDTO] = [],
        checklist: list[str] = [],
        source_fact_ids: list[str] = [],
        generated_at: str = "";
}

obj PatientAnswerDTO {
    has answer: str = "",
        grounded: bool = False,
        source_fact_ids: list[str] = [],
        fallback_used: bool = False;
}

obj PatientDTO {
    has id: str = "",
        display_name: str = "",
        preferred_language: str = "",
        synthetic: bool = True;
}

obj EncounterDTO {
    has id: str = "",
        occurred_at: str = "",
        status: str = "";
}

obj TranscriptChunkDTO {
    has id: str = "",
        sequence: int = 0,
        speaker: str = "",
        text: str = "";
}

obj ConflictDTO {
    has id: str = "",
        left_fact_id: str = "",
        right_fact_id: str = "",
        conflict_type: str = "",
        explanation: str = "",
        resolved: bool = False,
        left_source_text: str = "",
        right_source_text: str = "";
}

obj CareGraphDTO {
    has patient: PatientDTO | None = None,
        encounter: EncounterDTO | None = None,
        transcript: list[TranscriptChunkDTO] = [],
        candidate_facts: list[CandidateFactDTO] = [],
        verified_facts: list[VerifiedFactDTO] = [],
        care_gaps: list[CareGapDTO] = [],
        patient_plan: PatientPlanDTO | None = None,
        conflicts: list[ConflictDTO] = [],
        graph_version: int = 0;
}

obj DemoStateDTO {
    has patient: PatientDTO | None = None,
        encounter: EncounterDTO | None = None,
        transcript: list[TranscriptChunkDTO] = [],
        candidate_facts: list[CandidateFactDTO] = [],
        verified_facts: list[VerifiedFactDTO] = [],
        care_gaps: list[CareGapDTO] = [],
        patient_plan: PatientPlanDTO | None = None,
        conflicts: list[ConflictDTO] = [],
        graph_version: int = 0;
}

obj BackendResponse {
    has success: bool = False,
        error_code: str = "",
        message: str = "",
        recoverable: bool = False,
        current_graph_version: int = 0,
        demo_state: DemoStateDTO | None = None,
        candidate_facts: list[CandidateFactDTO] = [],
        verified_fact: VerifiedFactDTO | None = None,
        care_graph: CareGraphDTO | None = None,
        care_gaps: list[CareGapDTO] = [],
        patient_plan: PatientPlanDTO | None = None,
        patient_answer: PatientAnswerDTO | None = None,
        conflicts: list[ConflictDTO] = [];
}

node CareNode {
    has session_id: str = "";
}

node DemoSession {
    has id: str = "",
        synthetic: bool = True,
        graph_version: int = 1;
}

node Patient(CareNode) {
    has id: str = "",
        display_name: str = "",
        preferred_language: str = "",
        synthetic: bool = True;
}

node Encounter(CareNode) {
    has id: str = "",
        occurred_at: str = "",
        status: str = "";
}

node TranscriptChunk(CareNode) {
    has id: str = "",
        sequence: int = 0,
        speaker: str = "",
        text: str = "";
}

node CandidateFact(CareNode) {
    has id: str = "",
        category: str = "",
        value: str = "",
        confidence: float = 0.0,
        status: str = "pending",
        source_chunk_id: str = "",
        created_at: str = "";
}

node VerifiedFact(CareNode) {
    has id: str = "",
        category: str = "",
        value: str = "",
        verified_by: str = "",
        verified_at: str = "",
        visible_to_patient: bool = False,
        source_chunk_id: str = "",
        source_text: str = "";
}

node ClinicianIdentity(CareNode) {
    has id: str = "";
}

node MedicationInstruction(CareNode) {
    has id: str = "",
        instruction_text: str = "",
        timing_text: str = "",
        active: bool = True,
        source_fact_id: str = "";
}

node LabOrder(CareNode) {
    has id: str = "",
        test_name: str = "",
        due_window: str = "",
        owner: str = "",
        status: str = "",
        source_fact_id: str = "";
}

node Referral(CareNode) {
    has id: str = "",
        destination: str = "",
        owner: str = "",
        status: str = "",
        source_fact_id: str = "";
}

node FollowUp(CareNode) {
    has id: str = "",
        period_text: str = "",
        appointment_date: str = "",
        owner: str = "",
        status: str = "",
        source_fact_id: str = "";
}

node CareOwner(CareNode) {
    has id: str = "",
        display_name: str = "";
}

node CareTask(CareNode) {
    has id: str = "",
        task_type: str = "",
        title: str = "",
        owner: str = "",
        due_date: str = "",
        status: str = "";
}

node CareGap(CareNode) {
    has id: str = "",
        gap_type: str = "",
        message: str = "",
        related_fact_ids: list[str] = [],
        resolved: bool = False,
        resolution: str = "",
        owner: str = "",
        due_date: str = "";
}

node GapResolutionAudit(CareNode) {
    has id: str = "",
        gap_id: str = "",
        resolution: str = "",
        owner: str = "",
        due_date: str = "",
        recorded_at: str = "";
}

node Conflict(CareNode) {
    has id: str = "",
        left_fact_id: str = "",
        right_fact_id: str = "",
        conflict_type: str = "",
        explanation: str = "",
        resolved: bool = False,
        left_source_text: str = "",
        right_source_text: str = "";
}

node PatientBrief(CareNode) {
    has id: str = "",
        patient_id: str = "",
        language: str = "",
        medications: list[PlanItemDTO] = [],
        labs: list[PlanItemDTO] = [],
        referrals: list[PlanItemDTO] = [],
        follow_ups: list[PlanItemDTO] = [],
        checklist: list[str] = [],
        source_fact_ids: list[str] = [],
        approved_only: bool = True,
        created_at: str = "";
}

node PatientQuestion(CareNode) {
    has id: str = "",
        question: str = "",
        answer: str = "",
        grounded: bool = False,
        source_fact_ids: list[str] = [],
        fallback_used: bool = False,
        created_at: str = "";
}

edge SessionOwns: DemoSession --> CareNode {}
edge HasPatient: DemoSession --> Patient {}
edge HasEncounter: Patient --> Encounter {}
edge ContainsChunk: Encounter --> TranscriptChunk {}
edge HasCandidate: Encounter --> CandidateFact {}
edge ExtractedFrom: CandidateFact --> TranscriptChunk {}
edge HasVerifiedFact: Encounter --> VerifiedFact {}
edge VerifiedFrom: VerifiedFact --> CandidateFact {}
edge VerifiedBy: VerifiedFact --> ClinicianIdentity {}
edge HasClinician: DemoSession --> ClinicianIdentity {}
edge Materializes: VerifiedFact --> CareNode {}
edge RequiresFollowUp: LabOrder --> FollowUp {}
edge HasGap: DemoSession --> CareGap {}
edge HasTask: DemoSession --> CareTask {}
edge AssignedTo: CareTask --> CareOwner {}
edge DependsOn: CareTask --> VerifiedFact {}
edge HasAudit: CareGap --> GapResolutionAudit {}
edge Supersedes: VerifiedFact --> VerifiedFact {}
edge Contradicts: VerifiedFact --> VerifiedFact {}
edge HasConflict: DemoSession --> Conflict {}
edge HasBrief: Patient --> PatientBrief {}
edge VisibleToPatient: VerifiedFact --> PatientBrief {}
edge HasQuestion: DemoSession --> PatientQuestion {}
edge AnsweredFrom: PatientQuestion --> VerifiedFact {}

def candidate_to_dto(candidate: CandidateFact) -> CandidateFactDTO {
    source_text: str = "";
    source_chunks: list[TranscriptChunk] = [candidate->:ExtractedFrom:->];
    if source_chunks {
        source_text = source_chunks[0].text;
    }
    return CandidateFactDTO(
        id=candidate.id,
        category=candidate.category,
        value=candidate.value,
        source_chunk_id=candidate.source_chunk_id,
        source_text=source_text,
        confidence=candidate.confidence,
        status=candidate.status,
        created_at=candidate.created_at
    );
}

def verified_to_dto(fact: VerifiedFact) -> VerifiedFactDTO {
    return VerifiedFactDTO(
        id=fact.id,
        category=fact.category,
        value=fact.value,
        source_chunk_id=fact.source_chunk_id,
        source_text=fact.source_text,
        verified_by=fact.verified_by,
        verified_at=fact.verified_at,
        visible_to_patient=fact.visible_to_patient
    );
}

def gap_to_dto(gap: CareGap) -> CareGapDTO {
    return CareGapDTO(
        id=gap.id,
        gap_type=gap.gap_type,
        message=gap.message,
        related_fact_ids=gap.related_fact_ids,
        resolved=gap.resolved,
        resolution=gap.resolution,
        owner=gap.owner,
        due_date=gap.due_date
    );
}

def conflict_to_dto(conflict: Conflict) -> ConflictDTO {
    return ConflictDTO(
        id=conflict.id,
        left_fact_id=conflict.left_fact_id,
        right_fact_id=conflict.right_fact_id,
        conflict_type=conflict.conflict_type,
        explanation=conflict.explanation,
        resolved=conflict.resolved,
        left_source_text=conflict.left_source_text,
        right_source_text=conflict.right_source_text
    );
}

def patient_to_dto(patient: Patient) -> PatientDTO {
    return PatientDTO(
        id=patient.id,
        display_name=patient.display_name,
        preferred_language=patient.preferred_language,
        synthetic=patient.synthetic
    );
}

def encounter_to_dto(encounter: Encounter) -> EncounterDTO {
    return EncounterDTO(
        id=encounter.id, occurred_at=encounter.occurred_at, status=encounter.status
    );
}

def transcript_to_dto(chunk: TranscriptChunk) -> TranscriptChunkDTO {
    return TranscriptChunkDTO(
        id=chunk.id, sequence=chunk.sequence, speaker=chunk.speaker, text=chunk.text
    );
}

def brief_to_plan(brief: PatientBrief) -> PatientPlanDTO {
    return PatientPlanDTO(
        patient_id=brief.patient_id,
        language=brief.language,
        medications=brief.medications,
        labs=brief.labs,
        referrals=brief.referrals,
        follow_ups=brief.follow_ups,
        checklist=brief.checklist,
        source_fact_ids=brief.source_fact_ids,
        generated_at=brief.created_at
    );
}
