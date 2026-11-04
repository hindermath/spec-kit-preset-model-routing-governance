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
PowerShell-Discovery, 137 additive Adapter-/Legacy-Paritätsprüfungen, 119
Auswahlprüfungen, Ergebnistransport, sieben Node-/SDK-/HTTP-Tests,
Dokumentations- und Release-Verträge, PSScriptAnalyzer 1.25.0, `git diff
--check` und Gitleaks. Die OpenCode-Fixture prüft beide Reasoning-Formen:
`--variant` und `provider/model#variant`.

EN: The deterministic suite passed on macOS on 2026-11-04: Bash and PowerShell
discovery, 137 additive adapter/legacy parity checks, 119 selection checks,
result transport, seven Node/SDK/HTTP tests, documentation and release
contracts, PSScriptAnalyzer 1.25.0, `git diff --check`, and Gitleaks. The
OpenCode fixture covers both reasoning forms: `--variant` and
`provider/model#variant`.

Der einmalige sequenzielle Live-Test wurde innerhalb der 120-Sekunden-Grenze je
Harness beendet; es gab keinen Retry oder Fallback.

| Harness | Automatische Bindung | Live-Ergebnis |
|---|---|---|
| `agy` | `claude-opus-5-5-high`, `high` | `FAILED`: Discovery 2,992 s und Preflight 4,508 s bestanden; die 5,466-s-Aufgabe wurde durch die Headless-`command`-Berechtigung verweigert. Exitcode 0, aber kein Projekt. |
| Claude | `opus`, `high` | `BLOCKED`: Discovery ca. 3 s; Preflight ca. 1 s fehlgeschlagen. Der temporäre Berichtsrunner verdeckte stdout/stderr beim Fehlerbericht; kein Projekt und kein Retry. |
| Codex | `gpt-6.1-sol`, `high` | `PASS`: Discovery 4,258 s, Preflight 7,214 s, Aufgabe 59,089 s; Agent-Exitcode 0. Genau ein Projekt, keine `PackageReference`, Build/Run erfolgreich, Ausgabe exakt `MODEL_ROUTING_OK`. |
| Copilot | keine Bindung | `BLOCKED`: Discovery ca. 10 s; der SDK-/CLI-Kontrollpfad meldete keine authentifizierte GitHub-Host-Verbindung. Kein Preflight und kein Projekt. |
| OpenCode | keine Bindung im ausgeführten Stand | `BLOCKED`: Discovery ca. 5 s; OpenCode 2.2.5 bietet `provider/model#variant` statt `--variant`. Der Kandidat unterstützt diese Form nun deterministisch, wurde aber gemäß No-Retry-Regel nicht erneut live ausgeführt. |

EN: The single sequential live run completed inside the 120-second limit per
harness with no retry or fallback. Only Codex passed external verification.
The other four results remain real fail-closed evidence. Therefore candidate
0.2.4 is **not live-accepted** and remains local.

Preparation is not publication evidence. No tag, release page, archive,
installation, Home sync or rollout is created by this candidate.

[Strukturierte Vorbereitung / Structured preparation](release-0.2.4-preparation.json).
