"""Screen 2 state when too few facts have been accepted."""


def:pub ClinicalInsightsIncomplete -> JsxElement {
    return
        <section className="panel insights-incomplete" aria-labelledby="incomplete-heading">
            <p className="eyebrow">More verification required</p>
            <h2 id="incomplete-heading">
                Verify the encounter details before reviewing clinical insights.
            </h2>
            <p>
                Accept the main symptom and at least two additional candidate
                facts on Screen 1. Rejected and unresolved facts will not be
                treated as verified information.
            </p>

            <div className="insights-incomplete__sections">
                <div>
                    <h3>Possible Conditions</h3>
                    <span>Waiting for verified details</span>
                </div>
                <div>
                    <h3>Clinical Questions to Ask</h3>
                    <span>Waiting for verified details</span>
                </div>
                <div>
                    <h3>Potential Warning Signs</h3>
                    <span>Waiting for verified details</span>
                </div>
            </div>
        </section>;
}
