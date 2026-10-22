# Native Harness-Pruefung / Native harness verification

## Deutsch

Die Offline-Fixtures pruefen den Selector und synthetische Records, nicht die
Herstellerprotokolle. `tests/test-installed-harness-contract.ps1` ruft nur Hilfe
und Version aller fuenf installierten CLIs auf. `CliSurfaceVerified` bedeutet
ausschliesslich: die erwarteten Schalter stehen in dieser CLI-Hilfe.
`nativeConformance=NotVerified` und `access=NotProbed` bleiben erhalten.

Am 22.10.2026 wurde ein realer CLI-Unterschied gefunden: Claude Code 2.1.304
listet `manual`, nicht `default`, als Permission-Modus. Der Adapter verwendet
jetzt `manual` und `--permission-prompts none`. Das genehmigt keine Werkzeuge;
unbeantwortete Berechtigungsfragen bleiben verweigert. MCP-, Hook-, Agent- und
Settings-Vorrang sowie effektive Rechte sind damit noch nicht live bewiesen.

Die erste echte CLI-Auditpruefung schlug bei allen fuenf CLIs vor deren Start
fehl: der Child-Runner entpackte ein JSON-Array mit einem Element wie
`["--version"]` zu einem Skalar. `ConvertFrom-Json -NoEnumerate` erhaelt jetzt
den Argumentvektor; eine eigene Regression prueft den Einzelargumentfall.

Der erste native Windows-CI-Lauf scheiterte am exakten Subprozess-Ausgabetest.
Der Runner trennte nur LF und behielt CR aus CRLF im Record. Er entfernt jetzt
nur den Zeilentrenner; eine explizite CRLF-Fixture erhaelt die strenge exakte
Record-Pruefung. Der erste rote Lauf bleibt als Fehlernachweis erhalten.

Native Modell-/Effort-/No-Fallback-Receipts sind fuer keinen der fuenf Adapter
belegt. Das synthetische Feld `fallbackOccurred` ist keine zugesicherte
Herstellerfunktion. Fehlende Metadaten blockieren weiterhin. Eine Protokoll-
anpassung benoetigt versionsgebundene Quellen und echte kontrollierte Proben;
keine erfundene Bestaetigung und keine Ableitung aus Assistententext.

Echte Proben, Preflights und der sechsfaellige Aufgabenvergleich benoetigen
separate Budget-/Kontingentfreigabe. Zuerst read-only und ohne Projektgeheimnisse
ausserhalb produktiver Runner pruefen. Keine Zusatzkaeufe, stillen Fallbacks,
Wiederholungen oder Providerwechsel. Ein Timeout begrenzt Laufzeit, nicht Kosten.

## English

Offline fixtures validate the selector and synthetic records, not vendor
protocols. `tests/test-installed-harness-contract.ps1` invokes only help and
version for the five installed CLIs. `CliSurfaceVerified` means only that
expected switches appear in that CLI's help. Native conformance remains
`NotVerified` and access remains `NotProbed`.

On 2026-10-22, Claude Code 2.1.304 help exposed a real mismatch: its permission
mode is `manual`, not `default`. The adapter now uses `manual` with
`--permission-prompts none`. This grants no tools; unanswered approvals stay
denied. Effective MCP, hook, agent and settings precedence is not live verified.

The first installed-CLI audit failed for all five before launching the CLIs:
single-element JSON arrays such as `["--version"]` were unwrapped into scalars.
`ConvertFrom-Json -NoEnumerate` now preserves them, with a dedicated regression.

The first native Windows CI failed the exact subprocess output assertion:
splitting only LF retained a CR in each CRLF record. The runner now removes
only the line delimiter, covered by an explicit CRLF fixture with exact record
assertions. The original failed run remains part of the evidence.

Native model, effort and no-fallback receipts remain unverified for all five
adapters. The synthetic `fallbackOccurred` field is not a promised vendor
feature. Missing metadata still blocks. Version-bound protocol evidence and
controlled real probes are required; assistant text is never identity proof.

Real probes, preflights and the six-case corpus require separate budget/quota
approval. Start read-only without project secrets outside production runners.
No purchases, silent fallback, retries or provider changes. A timeout limits
wall time, not monetary spend.

## Quellen und Auswirkung / Sources and impact

- [Codex App Server](https://learn.chatgpt.com/docs/app-server)
- [Claude model configuration](https://code.claude.com/docs/en/model-config)
- Installed CLI `--version` and `--help`; exact metadata hashes in the audit output.

Documentation Impact: `UpdateRequired`. Owner: Thorsten Hindermann.
Audience: maintainers, pilot operators. Reader path: dynamic routing guide →
this verification note → offline CLI audit → separate budget approval.
Canonical source: this preset repository. DE/EN in this document. Reevaluate
on CLI, permissions, protocol or adapter changes. No installation/runtime sync
is performed by the test. CLI surface checks are not semantic or live review.
