# Jac 0.34.7 capability matrix

This matrix records capabilities actually probed on the Pa-Co development
machine. The installed compiler, bundled guides, and observed runtime behavior
are the compatibility authority for this repository.

Environment:

- Jac executable: `/Users/aradhyamishra/.local/bin/jac`
- Version: `jac 0.34.7 (Darwin arm64)`
- Platform: macOS arm64
- Service entry point: `main.jac`

Status meanings:

- **Yes**: compiled or ran successfully with the installed runtime.
- **Partial**: available but has a limitation or installed-version defect.
- **No**: unavailable or not reliable enough to use.

| Capability | 0.34.7 | Current use | Decision and proof |
|---|---|---:|---|
| Root-reachable persistent nodes | Yes | Yes | Keep as the canonical record. `jac guide jac-sv-persistence`; repeated `jac run` and server restart preserve `.jac/data`. |
| Typed edges | Yes | Yes | Expand usage. `jac guide jac-node-edge-patterns`; `jac check .`. |
| Endpoint-constrained edges | Yes | Yes | Use for every domain-to-domain relationship. Probe syntax: `edge Follows: Person --> Person {}` in the installed guide. |
| Root endpoint-constrained edge | Partial | No | `Root` is a runtime archetype, but the installed guide does not establish it as an edge endpoint declaration. Use a meaningful untyped `HasSession` root edge and type-filter its target. |
| Walker `has` state | Yes | Yes | Use for accumulated results, visited IDs, traces, and typed reports. |
| `visit`, `here`, `self` | Yes | Yes | Make all core graph operations use explicit visits. Proven by current walkers and `jac guide jac-walker-patterns`. |
| `report`, typed reports | Yes | Yes | Keep one structured `BackendResponse` report per walker. |
| `disengage`, `skip` | Yes | Yes | Keep for safe structured early termination. |
| Walker/node entry abilities | Yes | Walker only | Use walker-side typed entry abilities; node-side behavior is unnecessary for this domain. |
| Edge entry abilities | Partial | No | Installed guide requires visiting edge objects explicitly. Avoid edge abilities; record traversal in node entry abilities. |
| Multi-hop graph queries | Yes | Yes | Use only for read projections; state-changing clinical logic remains walker-driven. |
| Public walkers | Yes | No | Capability-test in isolation. Do not duplicate the stable `/function/*` contract with production `/walker/*` routes. |
| Private walkers | Yes | No | Verify in an isolated authenticated test; do not add login to the hackathon demo. |
| `def:pub` generated endpoints | Yes | Yes | Preserve all current paths. Real HTTP probe returned 200 for `/function/load_demo_encounter`. |
| Swagger/OpenAPI | Yes | Yes | `/docs` and `/openapi.json` returned 200; OpenAPI listed the public actions. |
| `jac start --faux` | Partial | No | It prints the endpoint table, then 0.34.7 raises `JFastApiServer.server_close` missing. Do not use it as a success gate. |
| Graph visualizer (`jac dot`, `/graph`) | Yes | No | Add smoke verification and judge instructions; do not commit generated DOT artifacts. |
| SQLite/local persistence | Yes | Yes | Use Jac-managed `.jac/data`; never add a second database. |
| Jac client codespace / `.cl.jac` | Yes | Frontend-owned | Document only. Backend work will not edit client files. |
| `sv import` / client `root spawn` bridge | Yes | Frontend-owned | Preserve typed function imports and avoid changing endpoint signatures. |
| JSX / React-style state / HMR | Yes | Frontend-owned | Out of backend scope. `jac start --dev` is supported. |
| `by llm()` | Yes | Yes | Keep optional and never on the deterministic path. |
| Typed `obj` AI returns | Yes | Yes | Required AI boundary; never return or accept graph nodes from an LLM. |
| String/int-based enums | Yes | No | Add string-based safety enums while preserving DTO wire strings. |
| `sem` | Yes | Yes | Expand to enums, important fields, and every LLM-visible declaration. |
| MockLLM | Yes | Yes | Remains the mandatory keyless AI test provider. |
| Structured-output retries | Yes | Implicit default | Configure exactly one correction retry. |
| Model configuration in `jac.toml` | Yes | Yes | Keep environment interpolation; never hardcode credentials. |
| Built-in local models | Yes | No | `jac model list` reports 2.5–5 GB downloads and no cached model. With about 17 GB free, do not download one for this pass. |
| Cloud providers | Yes | Optional | No recognized credential is configured. Do not create a paid key; live mode must fall back safely. |
| ModelPool | Yes | No | Intentionally omitted: no reliability or judging value for this deterministic demo. |
| Tool calling | Yes | No | Intentionally omitted: AI must not gain graph mutation tools. |
| AI-guided `visit ... by llm()` | No reliable proof | No | Intentionally omitted. Deterministic traversal is a safety boundary. |
| Jac test blocks | Yes | Yes | Preserve and expand the Jac-native suite. |
| Graph-isolated tests | Yes | Partial | Use unique session IDs for Jac tests and temporary base paths for endpoint tests. |
| `JacTestClient` | Yes | No | Add in-process generated-endpoint, auth-root, and reload tests. |
| `jac start --dev` / HMR | Yes | No | Document for development, but use non-HMR server for persistence tests. |
| Built-in authentication | Yes | No | Verify separately. Main demo remains anonymous synthetic data only. |
| Per-user roots | Yes | No | Prove isolation using two test users; do not claim application-level production authorization. |
| Runtime health endpoints | Yes | Yes | Verify `/healthz`, `/healthz/live`, and `/healthz/ready` where exposed. |
| Structural compiler queries | Yes | Audit only | `jac code map --text` listed current nodes, edges, walkers, and objects. |
| Jac database inspection | Yes | Audit only | `jac db` is available for ignored local state; no manual database code will be added. |

Official references:

- <https://docs.jaseci.org/reference/language/osp/>
- <https://docs.jaseci.org/tutorials/ai/structured-outputs/>
- <https://docs.jaseci.org/tutorials/fullstack/auth/>

Capabilities intentionally not implemented are not product promises.
