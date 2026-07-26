"""Graph-grounded patient questions with a deterministic safe fallback."""

import from models {
    BackendResponse,
    PatientAnswerDTO,
    DemoSession,
    VerifiedFact,
    LabOrder,
    FollowUp,
    CareTask,
    PatientQuestion,
    SessionOwns,
    Materializes,
    HasTask,
    DependsOn,
    HasQuestion,
    AnsweredFrom,
}
import from extraction { deterministic_timestamp }
import from walkers {
    failure_response,
    success_response,
    find_session,
    own_node,
    fact_is_conflicted,
}

glob SAFE_FALLBACK: str = (
         "This is not recorded in your approved care plan. "
         "Please contact your clinic."
     );

walker PatientQuestionWalker {
    has session_id: str = "demo-default",
        question: str = "",
        restrict_to_fact_ids: bool = False,
        allowed_fact_ids: list[str] = [],
        ai_matching_used: bool = False,
        answer: str = "",
        grounded: bool = False,
        source_fact_ids: list[str] = [],
        reports: list[BackendResponse] = [];

    can locate with Root entry {
        session: DemoSession | None = find_session(self.session_id);
        if session is None {
            report failure_response(
                "DEMO_NOT_LOADED",
                "Load the synthetic encounter before asking a question.",
                True,
                0
            );
            disengage;
        }
        if not self.question.strip() {
            report failure_response(
                "INVALID_QUESTION",
                "question must not be empty.",
                True,
                session.graph_version
            );
            disengage;
        }
        visit session;
    }

    can scan with DemoSession entry {
        visit [here->:SessionOwns:->[?:VerifiedFact]];
    }

    can answer_from_fact with VerifiedFact entry {
        if self.grounded {
            skip;
        }
        session: DemoSession | None = find_session(self.session_id);
        if (
            session is None
            or not here.visible_to_patient
            or fact_is_conflicted(session, here.id)
            or (self.restrict_to_fact_ids and here.id not in self.allowed_fact_ids)
        ) {
            skip;
        }

        normalized: str = self.question.lower();
        if (
            here.category == "lab_order"
            and "blood" in normalized
            and ("when" in normalized or "test" in normalized)
        ) {
            labs: list[LabOrder] = [here->:Materializes:->[?:LabOrder]];
            tasks: list[CareTask] = [here<-:DependsOn:<-];
            resolved_tasks: list[CareTask] = [
                task
                for task in tasks
                if task.status == "resolved" and task.owner.strip()
            ];
            if labs and resolved_tasks and labs[0].due_window.strip() {
                self.answer = (
                    f"Your blood test is due {labs[0].due_window} and is "
                    f"assigned to {resolved_tasks[0].owner}."
                );
                self.grounded = True;
                self.source_fact_ids = [here.id];
            }
        } elif (
            here.category == "follow_up"
            and (
                "follow" in normalized
                or "return" in normalized
                or "appointment" in normalized
            )
        ) {
            follow_ups: list[FollowUp] = [here->:Materializes:->[?:FollowUp]];
            if follow_ups and follow_ups[0].appointment_date.strip() {
                self.answer = (
                    "Your follow-up is scheduled for "
                    f"{follow_ups[0].appointment_date}."
                );
                self.grounded = True;
                self.source_fact_ids = [here.id];
            }
        }
    }

    can finish with DemoSession exit {
        fallback_used: bool = not self.grounded;
        if fallback_used {
            self.answer = SAFE_FALLBACK;
            self.source_fact_ids = [];
        }

        here.graph_version += 1;
        question_node = PatientQuestion(
            session_id=here.id,
            id=f"question-{here.id}-{here.graph_version}",
            question=self.question,
            answer=self.answer,
            grounded=self.grounded,
            source_fact_ids=self.source_fact_ids,
            fallback_used=fallback_used,
            created_at=deterministic_timestamp(here.graph_version)
        );
        own_node(here, question_node);
        here +>:HasQuestion():+> question_node;
        for fact_id in self.source_fact_ids {
            facts: list[VerifiedFact] = [here->:SessionOwns:->[?:VerifiedFact, id==fact_id]];
            if facts {
                question_node +>:AnsweredFrom():+> facts[0];
            }
        }

        response = success_response(
            here.graph_version,
            (
                "Question answered from approved graph evidence."
                    if self.grounded
                    else "No approved graph evidence answered the question."
            )
        );
        response.patient_answer = PatientAnswerDTO(
            answer=self.answer,
            grounded=self.grounded,
            source_fact_ids=self.source_fact_ids,
            fallback_used=fallback_used,
            ai_matching_used=self.ai_matching_used
        );
        report response;
    }
}
