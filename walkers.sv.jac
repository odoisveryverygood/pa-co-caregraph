"""Graph walkers and deterministic state projections for Pa-Co CareGraph."""

import from models {
    ExtractedCandidate,
    BackendResponse,
    CandidateFactDTO,
    CareGapDTO,
    CareGraphDTO,
    ConflictDTO,
    DemoStateDTO,
    EncounterDTO,
    PatientDTO,
    PatientPlanDTO,
    PlanItemDTO,
    TranscriptChunkDTO,
    VerifiedFactDTO,
    CareNode,
    DemoSession,
    Patient,
    Encounter,
    TranscriptChunk,
    CandidateFact,
    VerifiedFact,
    ClinicianIdentity,
    MedicationInstruction,
    LabOrder,
    Referral,
    FollowUp,
    CareOwner,
    CareTask,
    CareGap,
    GapResolutionAudit,
    Conflict,
    PatientBrief,
    SessionOwns,
    HasPatient,
    HasEncounter,
    ContainsChunk,
    HasCandidate,
    ExtractedFrom,
    HasVerifiedFact,
    VerifiedFrom,
    VerifiedBy,
    HasClinician,
    Materializes,
    RequiresFollowUp,
    HasGap,
    HasTask,
    AssignedTo,
    DependsOn,
    HasAudit,
    Supersedes,
    Contradicts,
    HasConflict,
    HasBrief,
    VisibleToPatient,
    candidate_to_dto,
    verified_to_dto,
    gap_to_dto,
    conflict_to_dto,
    patient_to_dto,
    encounter_to_dto,
    transcript_to_dto,
    brief_to_plan,
}
import from extraction {
    SeedTranscriptChunk,
    SeedCandidateFact,
    deterministic_timestamp,
    prepared_transcript,
    prepared_candidates,
    prepared_contradiction_chunk,
    prepared_contradiction_candidate,
}

def failure_response(
    error_code: str, message: str, recoverable: bool, graph_version: int
) -> BackendResponse {
    return BackendResponse(
        success=False,
        error_code=error_code,
        message=message,
        recoverable=recoverable,
        current_graph_version=graph_version
    );
}

def success_response(graph_version: int, message: str = "") -> BackendResponse {
    return BackendResponse(
        success=True, message=message, current_graph_version=graph_version
    );
}

def find_session(session_id: str) -> DemoSession | None {
    sessions: list[DemoSession] = [root-->[?:DemoSession, id==session_id]];
    return sessions[0] if sessions else None;
}

def own_node(session: DemoSession, item: CareNode) {
    session +>:SessionOwns():+> item;
}

def candidate_sequence(candidate: CandidateFact) -> int {
    chunks: list[TranscriptChunk] = [candidate->:ExtractedFrom:->];
    return chunks[0].sequence if chunks else 0;
}

def active_gaps(session: DemoSession) -> list[CareGap] {
    return [
        gap
        for gap in [session->:HasGap:->]
        if not gap.resolved
    ];
}

def unresolved_conflicts(session: DemoSession) -> list[Conflict] {
    return [
        conflict
        for conflict in [session->:HasConflict:->]
        if not conflict.resolved
    ];
}

def fact_is_conflicted(session: DemoSession, fact_id: str) -> bool {
    for conflict in unresolved_conflicts(session) {
        if conflict.left_fact_id == fact_id or conflict.right_fact_id == fact_id {
            return True;
        }
    }
    return False;
}

def seed_transcript_graph(session: DemoSession) {
    patients: list[Patient] = [session->:HasPatient:->];
    if patients {
        return;
    }

    session.graph_version = 1;
    patient = Patient(
        session_id=session.id,
        id="patient-maya",
        display_name="Maya Rivera",
        preferred_language="Spanish",
        synthetic=True
    );
    own_node(session, patient);
    session +>:HasPatient():+> patient;

    encounter = Encounter(
        session_id=session.id,
        id="encounter-maya-001",
        occurred_at="2026-07-26T18:00:00Z",
        status="candidate_review"
    );
    own_node(session, encounter);
    patient +>:HasEncounter():+> encounter;

    for seed in prepared_transcript() {
        chunk = TranscriptChunk(
            session_id=session.id,
            id=seed.id,
            sequence=seed.sequence,
            speaker=seed.speaker,
            text=seed.text
        );
        own_node(session, chunk);
        encounter +>:ContainsChunk():+> chunk;
    }
}

def seed_prepared_candidate_graph(session: DemoSession) -> bool {
    patients: list[Patient] = [session->:HasPatient:->];
    if not patients {
        return False;
    }
    encounters: list[Encounter] = [patients[0]->:HasEncounter:->];
    if not encounters {
        return False;
    }
    encounter: Encounter = encounters[0];
    chunks: list[TranscriptChunk] = [encounter->:ContainsChunk:->];
    created_any: bool = False;
    for seed in prepared_candidates() {
        existing: list[CandidateFact] = [encounter->:HasCandidate:->[?:CandidateFact, id==seed.id]];
        if existing {
            continue;
        }
        source_chunks: list[TranscriptChunk] = [
            chunk
            for chunk in chunks
            if chunk.id == seed.source_chunk_id
        ];
        if not source_chunks {
            continue;
        }
        source_chunk: TranscriptChunk = source_chunks[0];
        candidate = CandidateFact(
            session_id=session.id,
            id=seed.id,
            category=seed.category,
            value=seed.value,
            confidence=seed.confidence,
            status="pending",
            source_chunk_id=seed.source_chunk_id,
            created_at=seed.created_at
        );
        own_node(session, candidate);
        encounter +>:HasCandidate():+> candidate;
        candidate +>:ExtractedFrom():+> source_chunk;
        created_any = True;
    }
    return created_any;
}

def seed_session_graph(session: DemoSession, include_candidates: bool = True) {
    seed_transcript_graph(session);
    if include_candidates {
        _ = seed_prepared_candidate_graph(session);
    }
}

def add_contradiction_candidate(session: DemoSession) -> bool {
    existing: list[CandidateFact] = [session->:SessionOwns:->[?:CandidateFact, id=="candidate-follow-up-4-weeks"]];
    if existing {
        return False;
    }

    patients: list[Patient] = [session->:HasPatient:->];
    if not patients {
        return False;
    }
    encounters: list[Encounter] = [patients[0]->:HasEncounter:->];
    if not encounters {
        return False;
    }
    encounter = encounters[0];
    chunk_seed: SeedTranscriptChunk = prepared_contradiction_chunk();
    chunk = TranscriptChunk(
        session_id=session.id,
        id=chunk_seed.id,
        sequence=chunk_seed.sequence,
        speaker=chunk_seed.speaker,
        text=chunk_seed.text
    );
    own_node(session, chunk);
    encounter +>:ContainsChunk():+> chunk;

    candidate_seed: SeedCandidateFact = prepared_contradiction_candidate();
    candidate = CandidateFact(
        session_id=session.id,
        id=candidate_seed.id,
        category=candidate_seed.category,
        value=candidate_seed.value,
        confidence=candidate_seed.confidence,
        status="pending",
        source_chunk_id=candidate_seed.source_chunk_id,
        created_at=candidate_seed.created_at
    );
    own_node(session, candidate);
    encounter +>:HasCandidate():+> candidate;
    candidate +>:ExtractedFrom():+> chunk;
    session.graph_version += 1;
    return True;
}

def latest_plan(session: DemoSession) -> PatientPlanDTO | None {
    briefs: list[PatientBrief] = [session->:SessionOwns:->[?:PatientBrief]];
    if not briefs {
        return None;
    }
    return brief_to_plan(briefs[-1]);
}

def build_demo_state(session: DemoSession) -> DemoStateDTO {
    patient_dto: PatientDTO | None = None;
    encounter_dto: EncounterDTO | None = None;
    transcript_dtos: list[TranscriptChunkDTO] = [];
    candidate_dtos: list[CandidateFactDTO] = [];
    verified_dtos: list[VerifiedFactDTO] = [];
    gap_dtos: list[CareGapDTO] = [];
    conflict_dtos: list[ConflictDTO] = [];

    patients: list[Patient] = [session->:HasPatient:->];
    if patients {
        patient_dto = patient_to_dto(patients[0]);
        encounters: list[Encounter] = [patients[0]->:HasEncounter:->];
        if encounters {
            encounter = encounters[0];
            encounter_dto = encounter_to_dto(encounter);

            chunks: list[TranscriptChunk] = [encounter->:ContainsChunk:->];
            chunks.sort(key=lambda (chunk: TranscriptChunk) { chunk.sequence; });
            transcript_dtos = [transcript_to_dto(chunk) for chunk in chunks];

            candidates: list[CandidateFact] = [encounter->:HasCandidate:->];
            candidates.sort(
                key=lambda (candidate: CandidateFact) { candidate_sequence(candidate); }
            );
            candidate_dtos = [candidate_to_dto(candidate) for candidate in candidates];

            verified: list[VerifiedFact] = [encounter->:HasVerifiedFact:->];
            verified_dtos = [verified_to_dto(fact) for fact in verified];
        }
    }

    gap_dtos = [gap_to_dto(gap) for gap in active_gaps(session)];
    conflict_dtos = [
        conflict_to_dto(conflict) for conflict in unresolved_conflicts(session)
    ];
    return DemoStateDTO(
        patient=patient_dto,
        encounter=encounter_dto,
        transcript=transcript_dtos,
        candidate_facts=candidate_dtos,
        verified_facts=verified_dtos,
        care_gaps=gap_dtos,
        patient_plan=latest_plan(session),
        conflicts=conflict_dtos,
        graph_version=session.graph_version
    );
}

def build_care_graph(session: DemoSession) -> CareGraphDTO {
    state: DemoStateDTO = build_demo_state(session);
    return CareGraphDTO(
        patient=state.patient,
        encounter=state.encounter,
        transcript=state.transcript,
        candidate_facts=state.candidate_facts,
        verified_facts=state.verified_facts,
        care_gaps=state.care_gaps,
        patient_plan=state.patient_plan,
        conflicts=state.conflicts,
        graph_version=state.graph_version
    );
}

def link_lab_to_follow_up(session: DemoSession) {
    labs: list[LabOrder] = [session->:SessionOwns:->[?:LabOrder]];
    follow_ups: list[FollowUp] = [session->:SessionOwns:->[?:FollowUp]];
    if not labs or not follow_ups {
        return;
    }
    for lab in labs {
        linked: list[FollowUp] = [lab->:RequiresFollowUp:->];
        if not linked {
            lab +>:RequiresFollowUp():+> follow_ups[0];
        }
    }
}

walker ConsultationIngestWalker {
    has session_id: str = "demo-default",
        include_contradiction: bool = False,
        reports: list[BackendResponse] = [];

    can locate with Root entry {
        if not self.session_id.strip() {
            report failure_response(
                "INVALID_SESSION_ID", "session_id must not be empty.", True, 0
            );
            disengage;
        }
        visit [root-->[?:DemoSession, id==self.session_id]] else {
            fresh = root ++> DemoSession(
                id=self.session_id, synthetic=True, graph_version=1
            );
            visit fresh;
        }
    }

    can ingest with DemoSession entry {
        seed_session_graph(here);
        if self.include_contradiction {
            if not add_contradiction_candidate(here) {
                report failure_response(
                    "CONTRADICTION_ALREADY_ADDED",
                    "The prepared four-week statement already exists.",
                    False,
                    here.graph_version
                );
                disengage;
            }
        }
        state: DemoStateDTO = build_demo_state(here);
        response = success_response(
            here.graph_version, "Synthetic consultation loaded."
        );
        response.demo_state = state;
        response.candidate_facts = state.candidate_facts;
        report response;
    }
}

walker AIConsultationIngestWalker {
    has session_id: str = "demo-ai",
        reports: list[BackendResponse] = [];

    can locate with Root entry {
        if not self.session_id.strip() {
            report failure_response(
                "INVALID_SESSION_ID", "session_id must not be empty.", True, 0
            );
            disengage;
        }
        existing: list[DemoSession] = [root-->[?:DemoSession, id==self.session_id]];
        if existing {
            candidates: list[CandidateFact] = [existing[0]->:SessionOwns:->[?:CandidateFact]];
            verified: list[VerifiedFact] = [existing[0]->:SessionOwns:->[?:VerifiedFact]];
            if candidates or verified {
                report failure_response(
                    "AI_SESSION_ALREADY_INITIALIZED",
                    (
                        "Use a fresh synthetic session id for optional AI "
                        "ingestion so existing graph state is never overwritten."
                    ),
                    True,
                    existing[0].graph_version
                );
                disengage;
            }
            visit existing[0];
        } else {
            fresh = root ++> DemoSession(
                id=self.session_id, synthetic=True, graph_version=1
            );
            visit fresh;
        }
    }

    can ingest_transcript_only with DemoSession entry {
        seed_session_graph(here, include_candidates=False);
        state: DemoStateDTO = build_demo_state(here);
        response = success_response(
            here.graph_version,
            "Synthetic transcript loaded for optional typed extraction."
        );
        response.demo_state = state;
        report response;
    }
}

def canonical_candidate_id(candidate: ExtractedCandidate) -> str {
    if candidate.category == "lab_order" {
        return "candidate-lab";
    }
    if candidate.category == "follow_up" {
        return "candidate-follow-up";
    }
    if candidate.category == "medication_instruction" {
        return "candidate-medication";
    }
    if candidate.category == "referral" {
        return "candidate-referral";
    }
    if candidate.category == "language_preference" {
        return "candidate-language";
    }
    return f"candidate-{candidate.source_chunk_id}";
}

def candidate_created_at(candidate: ExtractedCandidate) -> str {
    if candidate.source_chunk_id == "chunk-1" {
        return "2026-07-26T18:00:01Z";
    }
    if candidate.source_chunk_id == "chunk-2" {
        return "2026-07-26T18:00:02Z";
    }
    if candidate.source_chunk_id == "chunk-3" {
        return "2026-07-26T18:00:03Z";
    }
    if candidate.source_chunk_id == "chunk-4" {
        return "2026-07-26T18:00:04Z";
    }
    if candidate.source_chunk_id == "chunk-5" {
        return "2026-07-26T18:00:05Z";
    }
    return "2026-07-26T18:00:06Z";
}

walker CandidateProposalWalker {
    has session_id: str = "demo-ai",
        proposals: list[ExtractedCandidate] = [],
        created_any: bool = False,
        reports: list[BackendResponse] = [];

    can locate with Root entry {
        session: DemoSession | None = find_session(self.session_id);
        if session is None {
            report failure_response(
                "DEMO_NOT_LOADED",
                "Load the synthetic transcript before adding proposals.",
                True,
                0
            );
            disengage;
        }
        visit session;
    }

    can add_pending_candidates with DemoSession entry {
        patients: list[Patient] = [here->:HasPatient:->];
        encounters: list[Encounter] = (
            [patients[0]->:HasEncounter:->] if patients else []
        );
        if not encounters {
            report failure_response(
                "ENCOUNTER_NOT_FOUND",
                "The synthetic encounter is missing.",
                False,
                here.graph_version
            );
            disengage;
        }
        encounter: Encounter = encounters[0];
        chunks: list[TranscriptChunk] = [encounter->:ContainsChunk:->];

        for proposal in self.proposals {
            duplicates: list[CandidateFact] = [
                candidate
                for candidate in [encounter->:HasCandidate:->]
                if (
                    candidate.category == proposal.category
                    and candidate.value == proposal.value
                    and candidate.source_chunk_id == proposal.source_chunk_id
                )
            ];
            if duplicates {
                continue;
            }
            source_chunks: list[TranscriptChunk] = [
                chunk
                for chunk in chunks
                if (
                    chunk.id == proposal.source_chunk_id
                    and proposal.source_text in chunk.text
                )
            ];
            if not source_chunks {
                report failure_response(
                    "AI_SOURCE_EVIDENCE_MISSING",
                    "A proposal lost transcript provenance before persistence.",
                    True,
                    here.graph_version
                );
                disengage;
            }

            base_id: str = canonical_candidate_id(proposal);
            id_collisions: list[CandidateFact] = [encounter->:HasCandidate:->[?:CandidateFact, id==base_id]];
            candidate_id: str = (
                f"{base_id}-{proposal.source_chunk_id}" if id_collisions else base_id
            );
            candidate = CandidateFact(
                session_id=here.id,
                id=candidate_id,
                category=proposal.category,
                value=proposal.value,
                confidence=proposal.confidence,
                status="pending",
                source_chunk_id=proposal.source_chunk_id,
                created_at=candidate_created_at(proposal)
            );
            own_node(here, candidate);
            encounter +>:HasCandidate():+> candidate;
            candidate +>:ExtractedFrom():+> source_chunks[0];
            self.created_any = True;
        }

        if self.created_any {
            here.graph_version += 1;
        }
        state: DemoStateDTO = build_demo_state(here);
        response = success_response(
            here.graph_version,
            "Validated proposals were stored only as pending candidate facts."
        );
        response.demo_state = state;
        response.candidate_facts = state.candidate_facts;
        response.extracted_candidates = self.proposals;
        report response;
    }
}

walker VerificationWalker {
    has session_id: str = "demo-default",
        fact_id: str = "",
        decision: str = "",
        clinician_id: str = "",
        reports: list[BackendResponse] = [];

    can locate_session with Root entry {
        session: DemoSession | None = find_session(self.session_id);
        if session is None {
            report failure_response(
                "DEMO_NOT_LOADED",
                "Load the synthetic encounter before verifying facts.",
                True,
                0
            );
            disengage;
        }
        if self.decision.lower() not in ["accept", "reject"] {
            report failure_response(
                "INVALID_DECISION",
                "decision must be 'accept' or 'reject'.",
                True,
                session.graph_version
            );
            disengage;
        }
        if not self.clinician_id.strip() {
            report failure_response(
                "INVALID_CLINICIAN_ID",
                "clinician_id must not be empty.",
                True,
                session.graph_version
            );
            disengage;
        }
        visit session;
    }

    can locate_candidate with DemoSession entry {
        visit [here->:SessionOwns:->[?:CandidateFact, id==self.fact_id]] else {
            report failure_response(
                "FACT_NOT_FOUND",
                f"Candidate fact '{self.fact_id}' was not found.",
                True,
                here.graph_version
            );
            disengage;
        }
    }

    can decide with CandidateFact entry {
        session: DemoSession | None = find_session(self.session_id);
        if session is None {
            report failure_response(
                "DEMO_NOT_LOADED", "The synthetic session no longer exists.", True, 0
            );
            disengage;
        }
        normalized_decision: str = self.decision.lower();

        if here.status == "accepted" {
            if normalized_decision == "accept" {
                existing: list[VerifiedFact] = [here<-:VerifiedFrom:<-];
                response = success_response(
                    session.graph_version,
                    "Candidate was already accepted; no duplicate was created."
                );
                if existing {
                    response.verified_fact = verified_to_dto(existing[0]);
                }
                report response;
                disengage;
            }
            report failure_response(
                "FACT_ALREADY_DECIDED",
                "An accepted candidate cannot later be rejected.",
                False,
                session.graph_version
            );
            disengage;
        }

        if here.status == "rejected" {
            if normalized_decision == "reject" {
                report success_response(
                    session.graph_version,
                    "Candidate was already rejected; no graph change was made."
                );
            } else {
                report failure_response(
                    "FACT_ALREADY_DECIDED",
                    "A rejected candidate cannot later be accepted.",
                    False,
                    session.graph_version
                );
            }
            disengage;
        }

        if normalized_decision == "reject" {
            here.status = "rejected";
            session.graph_version += 1;
            report success_response(
                session.graph_version,
                "Candidate rejected; no verified record was created."
            );
            disengage;
        }

        source_chunks: list[TranscriptChunk] = [here->:ExtractedFrom:->];
        encounters: list[Encounter] = [here<-:HasCandidate:<-];
        if not source_chunks or not encounters {
            report failure_response(
                "PROVENANCE_MISSING",
                "The candidate cannot be verified without its source chunk.",
                False,
                session.graph_version
            );
            disengage;
        }

        clinicians: list[ClinicianIdentity] = [session->:HasClinician:->[?:ClinicianIdentity, id==self.clinician_id]];
        clinician: ClinicianIdentity;
        if clinicians {
            clinician = clinicians[0];
        } else {
            clinician = ClinicianIdentity(session_id=session.id, id=self.clinician_id);
            own_node(session, clinician);
            session +>:HasClinician():+> clinician;
        }

        session.graph_version += 1;
        verified = VerifiedFact(
            session_id=session.id,
            id=f"verified-{here.id}",
            category=here.category,
            value=here.value,
            verified_by=self.clinician_id,
            verified_at=deterministic_timestamp(session.graph_version),
            visible_to_patient=True,
            source_chunk_id=here.source_chunk_id,
            source_text=source_chunks[0].text
        );
        own_node(session, verified);
        encounters[0] +>:HasVerifiedFact():+> verified;
        verified +>:VerifiedFrom():+> here;
        verified +>:VerifiedBy():+> clinician;

        if here.category == "lab_order" {
            lab_parts: list[str] = here.value.split(";");
            test_name: str = lab_parts[0].strip();
            due_window: str = (
                lab_parts[1].strip().removeprefix("due ").strip()
                    if len(lab_parts) > 1
                    else ""
            );
            lab = LabOrder(
                session_id=session.id,
                id=f"lab-{verified.id}",
                test_name=test_name,
                due_window=due_window,
                owner="",
                status="ordered",
                source_fact_id=verified.id
            );
            own_node(session, lab);
            verified +>:Materializes():+> lab;
        } elif here.category == "follow_up" {
            period: str = here.value.removeprefix("return in ").strip();
            follow_up = FollowUp(
                session_id=session.id,
                id=f"follow-up-{verified.id}",
                period_text=period,
                appointment_date="",
                owner="clinic follow-up team",
                status="pending",
                source_fact_id=verified.id
            );
            own_node(session, follow_up);
            verified +>:Materializes():+> follow_up;
        } elif here.category == "medication_instruction" {
            medication = MedicationInstruction(
                session_id=session.id,
                id=f"medication-{verified.id}",
                instruction_text=source_chunks[0].text,
                timing_text="Follow the timing on the existing prescription.",
                active=True,
                source_fact_id=verified.id
            );
            own_node(session, medication);
            verified +>:Materializes():+> medication;
        } elif here.category == "referral" {
            referral = Referral(
                session_id=session.id,
                id=f"referral-{verified.id}",
                destination=here.value,
                owner="clinic referral team",
                status="referred",
                source_fact_id=verified.id
            );
            own_node(session, referral);
            verified +>:Materializes():+> referral;
        }

        here.status = "accepted";
        link_lab_to_follow_up(session);
        response = success_response(
            session.graph_version,
            "Candidate accepted and promoted by VerificationWalker."
        );
        response.verified_fact = verified_to_dto(verified);
        report response;
    }
}

def ensure_gap(
    session: DemoSession, gap_id: str, gap_type: str, message: str, related_fact_id: str
) -> bool {
    existing: list[CareGap] = [session->:HasGap:->[?:CareGap, id==gap_id]];
    if existing {
        return False;
    }
    gap = CareGap(
        session_id=session.id,
        id=gap_id,
        gap_type=gap_type,
        message=message,
        related_fact_ids=[related_fact_id],
        resolved=False
    );
    own_node(session, gap);
    session +>:HasGap():+> gap;
    return True;
}

walker CareGapWalker {
    has session_id: str = "demo-default",
        created_any: bool = False,
        reports: list[BackendResponse] = [];

    can locate with Root entry {
        session: DemoSession | None = find_session(self.session_id);
        if session is None {
            report failure_response(
                "DEMO_NOT_LOADED",
                "Load the synthetic encounter before checking care gaps.",
                True,
                0
            );
            disengage;
        }
        visit session;
    }

    can scan with DemoSession entry {
        visit [here->:SessionOwns:->[?:LabOrder]];
        visit [here->:SessionOwns:->[?:FollowUp]];
        visit [here->:SessionOwns:->[?:Referral]];
        visit [here->:SessionOwns:->[?:MedicationInstruction]];
        visit [here->:SessionOwns:->[?:CareTask]];
    }

    can check_lab with LabOrder entry {
        if not here.owner.strip() {
            session = find_session(self.session_id);
            if session is not None {
                self.created_any = ensure_gap(
                    session,
                    f"gap-lab-owner-{here.source_fact_id}",
                    "lab_owner_missing",
                    "The blood test does not have a responsible owner.",
                    here.source_fact_id
                )
                or self.created_any;
            }
        }
    }

    can check_follow_up with FollowUp entry {
        if not here.appointment_date.strip() {
            session = find_session(self.session_id);
            if session is not None {
                self.created_any = ensure_gap(
                    session,
                    f"gap-follow-up-date-{here.source_fact_id}",
                    "follow_up_date_missing",
                    (
                        "The follow-up period is recorded but no appointment "
                        "date is scheduled."
                    ),
                    here.source_fact_id
                )
                or self.created_any;
            }
        }
    }

    can check_referral with Referral entry {
        if not here.owner.strip() {
            session = find_session(self.session_id);
            if session is not None {
                self.created_any = ensure_gap(
                    session,
                    f"gap-referral-owner-{here.source_fact_id}",
                    "referral_owner_missing",
                    "The referral does not have a responsible owner.",
                    here.source_fact_id
                )
                or self.created_any;
            }
        }
    }

    can check_medication with MedicationInstruction entry {
        if (not here.instruction_text.strip() or not here.timing_text.strip()) {
            session = find_session(self.session_id);
            if session is not None {
                self.created_any = ensure_gap(
                    session,
                    f"gap-medication-documentation-{here.source_fact_id}",
                    "medication_documentation_missing",
                    (
                        "The approved medication instruction is missing "
                        "documentation fields."
                    ),
                    here.source_fact_id
                )
                or self.created_any;
            }
        }
    }

    can check_task with CareTask entry {
        if here.status != "resolved" and not here.owner.strip() {
            session = find_session(self.session_id);
            if session is not None {
                self.created_any = ensure_gap(
                    session,
                    f"gap-task-owner-{here.id}",
                    "task_owner_missing",
                    "An unresolved care task does not have an owner.",
                    here.id
                )
                or self.created_any;
            }
        }
    }

    can finish with DemoSession exit {
        if self.created_any {
            here.graph_version += 1;
        }
        gaps: list[CareGapDTO] = [gap_to_dto(gap) for gap in active_gaps(here)];
        response = success_response(
            here.graph_version, "Documentation completeness check completed."
        );
        response.care_gaps = gaps;
        report response;
    }
}

walker GapResolutionWalker {
    has session_id: str = "demo-default",
        gap_id: str = "",
        resolution: str = "",
        owner: str = "",
        due_date: str = "",
        reports: list[BackendResponse] = [];

    can locate_session with Root entry {
        session: DemoSession | None = find_session(self.session_id);
        if session is None {
            report failure_response(
                "DEMO_NOT_LOADED",
                "Load the synthetic encounter before resolving gaps.",
                True,
                0
            );
            disengage;
        }
        if not self.resolution.strip() {
            report failure_response(
                "INVALID_RESOLUTION",
                "resolution must not be empty.",
                True,
                session.graph_version
            );
            disengage;
        }
        if not self.owner.strip() {
            report failure_response(
                "INVALID_OWNER", "owner must not be empty.", True, session.graph_version
            );
            disengage;
        }
        if not self.due_date.strip() {
            report failure_response(
                "INVALID_DUE_DATE",
                "due_date must not be empty.",
                True,
                session.graph_version
            );
            disengage;
        }
        visit session;
    }

    can locate_gap with DemoSession entry {
        visit [here->:HasGap:->[?:CareGap, id==self.gap_id]] else {
            report failure_response(
                "GAP_NOT_FOUND",
                f"Care gap '{self.gap_id}' was not found.",
                True,
                here.graph_version
            );
            disengage;
        }
    }

    can resolve with CareGap entry {
        session: DemoSession | None = find_session(self.session_id);
        if session is None {
            report failure_response(
                "DEMO_NOT_LOADED", "The synthetic session no longer exists.", True, 0
            );
            disengage;
        }
        if here.resolved {
            report failure_response(
                "GAP_ALREADY_RESOLVED",
                "The care gap is already resolved.",
                False,
                session.graph_version
            );
            disengage;
        }

        related_id: str = here.related_fact_ids[0] if here.related_fact_ids else "";
        related_facts: list[VerifiedFact] = [session->:SessionOwns:->[?:VerifiedFact, id==related_id]];
        related_fact: VerifiedFact | None = related_facts[0] if related_facts else None;

        if related_fact is not None {
            if here.gap_type == "lab_owner_missing" {
                labs: list[LabOrder] = [related_fact->:Materializes:->[?:LabOrder]];
                if labs {
                    labs[0].owner = self.owner;
                }
            } elif here.gap_type == "follow_up_date_missing" {
                follow_ups: list[FollowUp] = [related_fact->:Materializes:->[?:FollowUp]];
                if follow_ups {
                    follow_ups[0].appointment_date = self.due_date;
                    follow_ups[0].owner = self.owner;
                    follow_ups[0].status = "scheduled";
                }
            } elif here.gap_type == "referral_owner_missing" {
                referrals: list[Referral] = [related_fact->:Materializes:->[?:Referral]];
                if referrals {
                    referrals[0].owner = self.owner;
                }
            } elif here.gap_type == "medication_documentation_missing" {
                medications: list[MedicationInstruction] = [related_fact->:Materializes:->[?:MedicationInstruction]];
                if medications {
                    medications[0].timing_text = self.resolution;
                }
            }
        }

        owners: list[CareOwner] = [session->:SessionOwns:->[?:CareOwner, id==self.owner]];
        care_owner: CareOwner;
        if owners {
            care_owner = owners[0];
        } else {
            care_owner = CareOwner(
                session_id=session.id, id=self.owner, display_name=self.owner
            );
            own_node(session, care_owner);
        }

        tasks: list[CareTask] = [session->:HasTask:->[?:CareTask, id==f"task-{here.id}"]];
        task: CareTask;
        if tasks {
            task = tasks[0];
            task.owner = self.owner;
            task.due_date = self.due_date;
            task.status = "resolved";
        } else {
            task = CareTask(
                session_id=session.id,
                id=f"task-{here.id}",
                task_type=here.gap_type,
                title=self.resolution,
                owner=self.owner,
                due_date=self.due_date,
                status="resolved"
            );
            own_node(session, task);
            session +>:HasTask():+> task;
            task +>:AssignedTo():+> care_owner;
            if related_fact is not None {
                task +>:DependsOn():+> related_fact;
            }
        }

        session.graph_version += 1;
        audit = GapResolutionAudit(
            session_id=session.id,
            id=f"audit-{here.id}-{session.graph_version}",
            gap_id=here.id,
            resolution=self.resolution,
            owner=self.owner,
            due_date=self.due_date,
            recorded_at=deterministic_timestamp(session.graph_version)
        );
        own_node(session, audit);
        here +>:HasAudit():+> audit;

        here.resolved = True;
        here.resolution = self.resolution;
        here.owner = self.owner;
        here.due_date = self.due_date;

        response = success_response(
            session.graph_version, "Care gap resolved with an append-only audit record."
        );
        response.demo_state = build_demo_state(session as DemoSession);
        response.care_gaps = [
            gap_to_dto(gap) for gap in active_gaps(session as DemoSession)
        ];
        report response;
    }
}

def checklist_text(text: str, source_fact_id: str) -> str {
    return f"{text} [source: {source_fact_id}]";
}

def localized_due_window(due_window: str, language: str) -> str {
    if language.lower() == "spanish" and due_window == "this week" {
        return "esta semana";
    }
    return due_window;
}

walker PatientPlanWalker {
    has session_id: str = "demo-default",
        language: str = "English",
        medications: list[PlanItemDTO] = [],
        labs: list[PlanItemDTO] = [],
        referrals: list[PlanItemDTO] = [],
        follow_ups: list[PlanItemDTO] = [],
        checklist: list[str] = [],
        source_fact_ids: list[str] = [],
        reports: list[BackendResponse] = [];

    can locate with Root entry {
        session: DemoSession | None = find_session(self.session_id);
        if session is None {
            report failure_response(
                "DEMO_NOT_LOADED",
                "Load the synthetic encounter before generating a plan.",
                True,
                0
            );
            disengage;
        }
        if not self.language.strip() {
            report failure_response(
                "INVALID_LANGUAGE",
                "language must not be empty.",
                True,
                session.graph_version
            );
            disengage;
        }
        visit session;
    }

    can start with DemoSession entry {
        gaps: list[CareGap] = active_gaps(here);
        if gaps {
            report failure_response(
                "ACTIVE_CARE_GAPS",
                "Resolve active documentation gaps before generating the plan.",
                True,
                here.graph_version
            );
            disengage;
        }
        visit [here->:SessionOwns:->[?:VerifiedFact]];
    }

    can collect with VerifiedFact entry {
        session: DemoSession | None = find_session(self.session_id);
        if (
            session is None
            or not here.visible_to_patient
            or fact_is_conflicted(session, here.id)
        ) {
            skip;
        }

        source_id: str = here.id;
        if here.category == "lab_order" {
            lab_nodes: list[LabOrder] = [here->:Materializes:->[?:LabOrder]];
            if lab_nodes {
                lab = lab_nodes[0];
                due: str = localized_due_window(lab.due_window, self.language);
                text: str = (
                    f"Complete the {lab.test_name} {due}."
                        if self.language.lower() != "spanish"
                        else f"Complete el análisis de sangre {due}."
                );
                self.labs.append(
                    PlanItemDTO(
                        kind="lab",
                        text=text,
                        owner=lab.owner,
                        due_date=lab.due_window,
                        status=lab.status,
                        source_fact_id=source_id
                    )
                );
                self.checklist.append(checklist_text(text, source_id));
                self.source_fact_ids.append(source_id);
            }
        } elif here.category == "follow_up" {
            follow_nodes: list[FollowUp] = [here->:Materializes:->[?:FollowUp]];
            if follow_nodes {
                follow = follow_nodes[0];
                text = (
                    (
                        f"Return in {follow.period_text}; appointment: "
                        f"{follow.appointment_date}."
                    )
                        if self.language.lower() != "spanish"
                        else (
                            f"Regrese en {follow.period_text}; cita: "
                            f"{follow.appointment_date}."
                        )
                );
                self.follow_ups.append(
                    PlanItemDTO(
                        kind="follow_up",
                        text=text,
                        owner=follow.owner,
                        due_date=follow.appointment_date,
                        status=follow.status,
                        source_fact_id=source_id
                    )
                );
                self.checklist.append(checklist_text(text, source_id));
                self.source_fact_ids.append(source_id);
            }
        } elif here.category == "medication_instruction" {
            medication_nodes: list[MedicationInstruction] = [here->:Materializes:->[?:MedicationInstruction]];
            if medication_nodes {
                medication = medication_nodes[0];
                text = (
                    medication.instruction_text
                        if self.language.lower() != "spanish"
                        else (
                            "Continúe su medicamento actual exactamente como "
                            "aparece en su receta existente."
                        )
                );
                self.medications.append(
                    PlanItemDTO(
                        kind="medication",
                        text=text,
                        owner="patient",
                        due_date=medication.timing_text,
                        status="active" if medication.active else "inactive",
                        source_fact_id=source_id
                    )
                );
                self.checklist.append(checklist_text(text, source_id));
                self.source_fact_ids.append(source_id);
            }
        } elif here.category == "referral" {
            referral_nodes: list[Referral] = [here->:Materializes:->[?:Referral]];
            if referral_nodes {
                referral = referral_nodes[0];
                text = (
                    f"Your referral is to a {referral.destination}."
                        if self.language.lower() != "spanish"
                        else (
                            "Su remisión es a un consejero comunitario de " "nutrición."
                        )
                );
                self.referrals.append(
                    PlanItemDTO(
                        kind="referral",
                        text=text,
                        owner=referral.owner,
                        due_date="",
                        status=referral.status,
                        source_fact_id=source_id
                    )
                );
                self.checklist.append(checklist_text(text, source_id));
                self.source_fact_ids.append(source_id);
            }
        }
    }

    can finish with DemoSession exit {
        if not self.source_fact_ids {
            report failure_response(
                "NO_VISIBLE_FACTS",
                "No approved, patient-visible facts are available.",
                True,
                here.graph_version
            );
            disengage;
        }

        patients: list[Patient] = [here->:HasPatient:->];
        if not patients {
            report failure_response(
                "PATIENT_NOT_FOUND",
                "The synthetic patient is missing.",
                False,
                here.graph_version
            );
            disengage;
        }
        here.graph_version += 1;
        brief = PatientBrief(
            session_id=here.id,
            id=f"brief-{here.id}-{here.graph_version}",
            patient_id=patients[0].id,
            language=self.language,
            medications=self.medications,
            labs=self.labs,
            referrals=self.referrals,
            follow_ups=self.follow_ups,
            checklist=self.checklist,
            source_fact_ids=self.source_fact_ids,
            approved_only=True,
            created_at=deterministic_timestamp(here.graph_version)
        );
        own_node(here, brief);
        patients[0] +>:HasBrief():+> brief;
        for fact_id in self.source_fact_ids {
            facts: list[VerifiedFact] = [here->:SessionOwns:->[?:VerifiedFact, id==fact_id]];
            if facts {
                facts[0] +>:VisibleToPatient():+> brief;
            }
        }

        plan: PatientPlanDTO = brief_to_plan(brief);
        response = success_response(
            here.graph_version, "Patient brief generated from approved graph evidence."
        );
        response.patient_plan = plan;
        report response;
    }
}

def ensure_conflict(session: DemoSession, spec: ConflictDTO) -> bool {
    existing: list[Conflict] = [session->:HasConflict:->[?:Conflict, id==spec.id]];
    if existing {
        return False;
    }
    conflict = Conflict(
        session_id=session.id,
        id=spec.id,
        left_fact_id=spec.left_fact_id,
        right_fact_id=spec.right_fact_id,
        conflict_type=spec.conflict_type,
        explanation=spec.explanation,
        resolved=False,
        left_source_text=spec.left_source_text,
        right_source_text=spec.right_source_text
    );
    own_node(session, conflict);
    session +>:HasConflict():+> conflict;
    return True;
}

walker EvidenceAuditWalker {
    has session_id: str = "demo-default",
        facts: list[VerifiedFact] = [],
        created_any: bool = False,
        reports: list[BackendResponse] = [];

    can locate with Root entry {
        session: DemoSession | None = find_session(self.session_id);
        if session is None {
            report failure_response(
                "DEMO_NOT_LOADED",
                "Load the synthetic encounter before running an audit.",
                True,
                0
            );
            disengage;
        }
        visit session;
    }

    can scan with DemoSession entry {
        visit [here->:SessionOwns:->[?:VerifiedFact]];
    }

    can collect with VerifiedFact entry {
        self.facts.append(here);
    }

    can finish with DemoSession exit {
        for left_index in range(len(self.facts)) {
            for right_index in range(left_index + 1, len(self.facts)) {
                left: VerifiedFact = self.facts[left_index];
                right: VerifiedFact = self.facts[right_index];
                if left.category != right.category {
                    continue;
                }

                if left.value == right.value {
                    self.created_any = ensure_conflict(
                        here,
                        ConflictDTO(
                            id=f"duplicate-{left.id}-{right.id}",
                            left_fact_id=left.id,
                            right_fact_id=right.id,
                            conflict_type="duplicate_verified_fact",
                            explanation=(
                                "Two approved facts duplicate the same " "instruction."
                            ),
                            left_source_text=left.source_text,
                            right_source_text=right.source_text
                        )
                    )
                    or self.created_any;
                } elif left.category == "follow_up" {
                    self.created_any = ensure_conflict(
                        here,
                        ConflictDTO(
                            id=f"conflict-{left.id}-{right.id}",
                            left_fact_id=left.id,
                            right_fact_id=right.id,
                            conflict_type=("contradictory_follow_up_period"),
                            explanation=(
                                "Two approved follow-up periods differ; "
                                "neither was overwritten."
                            ),
                            left_source_text=left.source_text,
                            right_source_text=right.source_text
                        )
                    )
                    or self.created_any;
                    linked: list[VerifiedFact] = [left->:Contradicts:->];
                    if right not in linked {
                        left +>:Contradicts():+> right;
                    }
                }
            }
        }

        candidates: list[CandidateFact] = [here->:SessionOwns:->[?:CandidateFact]];
        for candidate in candidates {
            if candidate.status != "pending" {
                continue;
            }
            for fact in self.facts {
                if (
                    candidate.category == fact.category
                    and candidate.value != fact.value
                ) {
                    self.created_any = ensure_conflict(
                        here,
                        ConflictDTO(
                            id=(f"unverified-change-{fact.id}-" f"{candidate.id}"),
                            left_fact_id=fact.id,
                            right_fact_id=candidate.id,
                            conflict_type="unverified_attempted_change",
                            explanation=(
                                "An unverified attempted change differs "
                                "from an approved fact and was not applied."
                            ),
                            left_source_text=fact.source_text,
                            right_source_text=(candidate_to_dto(candidate).source_text)
                        )
                    )
                    or self.created_any;
                }
            }
        }

        for fact in self.facts {
            superseded: list[VerifiedFact] = [fact->:Supersedes:->];
            for older in superseded {
                self.created_any = ensure_conflict(
                    here,
                    ConflictDTO(
                        id=f"superseded-{fact.id}-{older.id}",
                        left_fact_id=fact.id,
                        right_fact_id=older.id,
                        conflict_type="superseded_instruction",
                        explanation=(
                            "A fact is explicitly superseded; both records " "remain."
                        ),
                        left_source_text=fact.source_text,
                        right_source_text=older.source_text
                    )
                )
                or self.created_any;
            }
        }

        if self.created_any {
            here.graph_version += 1;
        }
        conflicts: list[ConflictDTO] = [
            conflict_to_dto(conflict) for conflict in unresolved_conflicts(here)
        ];
        response = success_response(
            here.graph_version,
            "Evidence audit completed without selecting a clinical winner."
        );
        response.conflicts = conflicts;
        report response;
    }
}

walker ResetDemoWalker {
    has session_id: str = "demo-default",
        reports: list[BackendResponse] = [];

    can reset with Root entry {
        if not self.session_id.strip() {
            report failure_response(
                "INVALID_SESSION_ID", "session_id must not be empty.", True, 0
            );
            disengage;
        }

        sessions: list[DemoSession] = [root-->[?:DemoSession, id==self.session_id]];
        for session in sessions {
            if not session.synthetic {
                report failure_response(
                    "NON_SYNTHETIC_SESSION",
                    "ResetDemoWalker can reset synthetic sessions only.",
                    False,
                    session.graph_version
                );
                disengage;
            }
            owned: list[CareNode] = [session->:SessionOwns:->];
            for item in owned {
                del item;
            }
            del session;
        }

        fresh = root ++> DemoSession(
            id=self.session_id, synthetic=True, graph_version=1
        );
        seed_session_graph(fresh);
        state: DemoStateDTO = build_demo_state(fresh);
        response = success_response(
            fresh.graph_version,
            "Synthetic demo reset to the exact prepared initial state."
        );
        response.demo_state = state;
        response.candidate_facts = state.candidate_facts;
        report response;
    }
}
