"""Small browser adapter for Jac generated-function endpoints."""


def unwrapBackendEnvelope(payload: any) -> dict[str, any] {
    envelope: any = payload;
    if isinstance(payload, list) and len(payload) > 0 {
        envelope = payload[0];
    }
    if isinstance(envelope, dict) and "data" in envelope {
        data: any = envelope["data"];
        if isinstance(data, dict) and "result" in data {
            return data["result"];
        }
    }
    if isinstance(envelope, dict) and "result" in envelope {
        return envelope["result"];
    }
    return envelope;
}


def:pub callBackendAction(action: str, payload: dict[str, any]) -> any {
    return fetch(
        "/function/" + action,
        {
            "method": "POST",
            "headers": {"Content-Type": "application/json"},
            "body": JSON.stringify(payload)
        }
    ).then(lambda (response: any) {
        if not response.ok {
            raise Error("Backend request failed with HTTP " + str(response.status));
        }
        return response.json();
    }).then(unwrapBackendEnvelope);
}


def:pub callDocumentIngest(form: any) -> any {
    return fetch(
        "/function/ingest_document_image",
        {"method": "POST", "body": form}
    ).then(lambda (response: any) {
        if not response.ok {
            raise Error("Document request failed with HTTP " + str(response.status));
        }
        return response.json();
    }).then(unwrapBackendEnvelope);
}
