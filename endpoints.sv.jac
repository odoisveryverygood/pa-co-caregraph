"""Stable Jac-native public actions consumed by the Pa-Co frontend."""

import from models {
    BackendResponse,
    CandidateFact,
    DemoSession,
    VerifiedFact,
    SessionOwns,
}
import from walkers {
    ConsultationIngestWalker,
    VerificationWalker,
    CareGapWalker,
    GapResolutionWalker,
    PatientPlanWalker,
    EvidenceAuditWalker,
    ResetDemoWalker,
    failure_response,
    find_session,
    build_demo_state,
    build_care_graph,
}
import from patient_agent { PatientQuestionWalker }

def first_response(reports: list[BackendResponse], operation: str) -> BackendResponse {
    if reports {
        return reports[0];
    }
    return failure_response(
        "WALKER_NO_RESPONSE",
        f"{operation} completed without a structured response.",
        True,
        0
    );
}

def:pub load_demo_encounter(session_id: str = "demo-default") -> BackendResponse {
    result = root spawn ConsultationIngestWalker(session_id=session_id);
    return first_response(result.reports, "load_demo_encounter");
}

def:pub get_candidate_facts(session_id: str = "demo-default") -> BackendResponse {
    session: DemoSession | None = find_session(session_id);
    if session is None {
        return failure_response(
            "DEMO_NOT_LOADED",
            "Load the synthetic encounter before reading candidates.",
            True,
            0
        );
    }
    state = build_demo_state(session);
    return BackendResponse(
        success=True,
        message="Candidate facts loaded.",
        current_graph_version=session.graph_version,
        candidate_facts=state.candidate_facts
    );
}

def:pub verify_fact(
    fact_id: str, decision: str, clinician_id: str, session_id: str = "demo-default"
) -> BackendResponse {
    result = root spawn VerificationWalker(
        session_id=session_id,
        fact_id=fact_id,
        decision=decision,
        clinician_id=clinician_id
    );
    return first_response(result.reports, "verify_fact");
}

def:pub get_care_graph(session_id: str = "demo-default") -> BackendResponse {
    session: DemoSession | None = find_session(session_id);
    if session is None {
        return failure_response(
            "DEMO_NOT_LOADED",
            "Load the synthetic encounter before reading the care graph.",
            True,
            0
        );
    }
    return BackendResponse(
        success=True,
        message="Care graph loaded.",
        current_graph_version=session.graph_version,
        care_graph=build_care_graph(session)
    );
}

def:pub run_care_gap_check(session_id: str = "demo-default") -> BackendResponse {
    result = root spawn CareGapWalker(session_id=session_id);
    return first_response(result.reports, "run_care_gap_check");
}

def:pub resolve_gap(
    gap_id: str,
    resolution: str,
    owner: str,
    due_date: str,
    session_id: str = "demo-default"
) -> BackendResponse {
    result = root spawn GapResolutionWalker(
        session_id=session_id,
        gap_id=gap_id,
        resolution=resolution,
        owner=owner,
        due_date=due_date
    );
    return first_response(result.reports, "resolve_gap");
}

def:pub generate_patient_plan(
    language: str, session_id: str = "demo-default"
) -> BackendResponse {
    result = root spawn PatientPlanWalker(session_id=session_id, language=language);
    return first_response(result.reports, "generate_patient_plan");
}

def:pub ask_patient_question(
    question: str, session_id: str = "demo-default"
) -> BackendResponse {
    result = root spawn PatientQuestionWalker(session_id=session_id, question=question);
    return first_response(result.reports, "ask_patient_question");
}

def:pub run_evidence_audit(session_id: str = "demo-default") -> BackendResponse {
    result = root spawn EvidenceAuditWalker(session_id=session_id);
    return first_response(result.reports, "run_evidence_audit");
}

def:pub reset_demo(session_id: str = "demo-default") -> BackendResponse {
    result = root spawn ResetDemoWalker(session_id=session_id);
    return first_response(result.reports, "reset_demo");
}

def:pub add_demo_contradiction(session_id: str = "demo-default") -> BackendResponse {
    session: DemoSession | None = find_session(session_id);
    if session is None {
        return failure_response(
            "DEMO_NOT_LOADED",
            "Load the synthetic encounter before adding the contradiction.",
            True,
            0
        );
    }
    base_follow_up: list[VerifiedFact] = [session->:SessionOwns:->[?:VerifiedFact, id=="verified-candidate-follow-up"]];
    if not base_follow_up {
        return failure_response(
            "BASE_FOLLOW_UP_NOT_VERIFIED",
            "Accept the prepared two-week follow-up before the audit demo.",
            True,
            session.graph_version
        );
    }
    existing: list[CandidateFact] = [session->:SessionOwns:->[?:CandidateFact, id=="candidate-follow-up-4-weeks"]];
    if existing {
        return failure_response(
            "CONTRADICTION_ALREADY_ADDED",
            "The prepared four-week statement already exists.",
            False,
            session.graph_version
        );
    }

    ingest_result = root spawn ConsultationIngestWalker(
        session_id=session_id, include_contradiction=True
    );
    ingest_response: BackendResponse = first_response(
        ingest_result.reports, "add_demo_contradiction.ingest"
    );
    if not ingest_response.success {
        return ingest_response;
    }

    verification_result = root spawn VerificationWalker(
        session_id=session_id,
        fact_id="candidate-follow-up-4-weeks",
        decision="accept",
        clinician_id="demo-clinician"
    );
    return first_response(verification_result.reports, "add_demo_contradiction.verify");
}
