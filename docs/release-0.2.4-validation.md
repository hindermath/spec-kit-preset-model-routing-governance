# v0.2.4: Discovery-Kompatibilität / Discovery compatibility

DE: Dieser lokale, unveröffentlichte Kandidat ergänzt aktuelle `agy`-Namen,
normalisiert begrenzte Claude-CLI-Hilfe, bindet bei Copilot den tatsächlich
erkannten Reasoning-Schalter und liest die OpenCode-2.2.5-API vor dem
Legacy-Fallback. Codex-Verhalten und historische `agy`-Auflösungen bleiben
unverändert. Mehrdeutige oder unbekannte Ergebnisse blockieren weiterhin.

EN: This local, unpublished candidate adds current `agy` names, normalizes
bounded Claude CLI help, binds Copilot's actually detected reasoning flag and
reads the OpenCode 2.2.5 API before the legacy fallback. Codex behavior and
historical `agy` resolution remain unchanged. Ambiguous or unknown results
still fail closed.

Documentation Impact **UpdateRequired**, owner Thorsten Hindermann. Canonical
sources are the resolver, additive adapters, transport tests, paired discovery
guides and this record. Reader path: README → paired user guide → paired
automatic-discovery guide → this validation record. Audience: preset operators
and maintainers. German first with equivalent English; CEFR B2 and applicable
WCAG 2.2 AA. Distribution class: local source candidate. Home sync is not
required or authorized. Re-evaluate on SDK, CLI or OpenCode API drift.

## Lokale Prüfung / Local verification

DE: Die deterministische Suite bestand am 2026-11-04 unter macOS: Bash- und
PowerShell-Discovery, 193 additive Adapter-/Legacy-Paritätsprüfungen, 119
Auswahlprüfungen, Ergebnistransport, sieben Node-/SDK-/HTTP-Tests,
Dokumentations- und Release-Verträge, PSScriptAnalyzer 1.25.0, `git diff
--check` und Gitleaks. Die OpenCode-Fixture prüft beide Reasoning-Formen:
`--variant` und `provider/model#variant`.

EN: The deterministic suite passed on macOS on 2026-11-04: Bash and PowerShell
discovery, 193 additive adapter/legacy parity checks, 119 selection checks,
result transport, seven Node/SDK/HTTP tests, documentation and release
contracts, PSScriptAnalyzer 1.25.0, `git diff --check`, and Gitleaks. The
OpenCode fixture covers both reasoning forms: `--variant` and
`provider/model#variant`.

DE: Der ausdrücklich angeforderte Folgelauf verwendete ausschließlich die
vorhandenen interaktiven CLI-Anmeldungen. API-Key-Umgebungsvariablen wurden für
die Kindprozesse entfernt. Gepinnte SDKs dienten nur der lokalen
Katalogabfrage. Während des Laufs wurden reale CLI-Transportgrenzen korrigiert:
Claude-MCP-Argumentende, Copilot-JSONL, JSON-kodierte Harnessargumente,
OpenCode-Varianten und geerbtes `PWD`. Die folgende Tabelle enthält den jeweils
abschließenden grünen Lauf; jeder blieb einschließlich Discovery, Preflight und
Aufgabe unter 120 Sekunden.

EN: The explicitly requested follow-up used only existing interactive CLI
sign-ins. API-key environment variables were removed from child processes.
Pinned SDKs served only local catalogue discovery. Real CLI transport limits
were corrected during the run: Claude MCP argument termination, Copilot JSONL,
JSON-encoded harness arguments, OpenCode variants, and inherited `PWD`. The
table records each final green run; discovery, preflight and task stayed below
120 seconds per harness.

| Harness | Bindung | Live-Ergebnis |
|---|---|---|
| `agy` | automatisch `claude-opus-5-5-high`, `high` | `PASS`: Discovery 2,736 s, Preflight 4,514 s, Aufgabe 53,399 s; Agent-Exitcode 0, externe Abnahme grün. Die `command(*)`-Freigabe galt nur sitzungsgebunden im temporären Sandboxlauf. |
| Claude | automatisch `opus`, `high` | `PASS`: Discovery 3,591 s, Preflight 4,757 s, Aufgabe 93,792 s; Agent-Exitcode 0, externe Abnahme grün. Authentifizierung: `claude.ai`. |
| Codex | automatisch `gpt-6.1-sol`, `high` | `PASS`: Discovery 4,283 s, Preflight 5,978 s, Aufgabe 48,320 s; Agent-Exitcode 0, externe Abnahme grün. |
| Copilot | exakter Test-Override `claude-opus-5.5`, `high`; Fast `claude-haiku-5.5` | `PASS`: Discovery 4,368 s, Preflight 6,957 s, Aufgabe 45,364 s; Agent-Exitcode 0, externe Abnahme grün. Die SDK-Katalogabfrage nutzte die interaktive Copilot-CLI-Anmeldung. Der Override löst die absichtlich fail-closed Mehrdeutigkeit von vier Opus-Versionen nur für diesen Test. |
| OpenCode | exakter Test-Override `openai/gpt-6.1-terra`, `high`; Fast `openai/gpt-6-luna` | `PASS`: Discovery 1,357 s, Preflight 3,550 s, Aufgabe 101,295 s; Agent-Exitcode 0, externe Abnahme grün. OpenCode 2.2.5 nutzte `provider/model#variant` und die interaktive Provideranmeldung. |

All five final runs contain exactly one C# project, no `PackageReference`, a
successful `dotnet build --no-restore`, exit code 0 and normalized output
exactly `MODEL_ROUTING_OK`. Candidate 0.2.4 is therefore **locally
live-accepted**. This does not authorize delivery.

Preparation is not publication evidence. No tag, release page, archive,
installation, Home sync or rollout is created by this candidate.

[Strukturierte Vorbereitung / Structured preparation](release-0.2.4-preparation.json).
