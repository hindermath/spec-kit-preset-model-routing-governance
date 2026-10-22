# Dynamisches Phasen-Routing / Dynamic phase routing

[Native Pruefung und Grenzen / Native verification and limits](native-verification.md)

## Deutsch

**Unveroeffentlichter Entwicklungsstand.** Die getaggten Pakete und installierten
Kopien bleiben unveraendert. Diese Anleitung beschreibt Schema 3.0 im Quellbranch,
nicht rueckwirkend Release 0.1.5. Owner: Thorsten Hindermann.

### Sicherer Einstieg

Ein Harness ist die lokale Agenten-CLI. Eine Phase ist ein abgegrenzter Auftrag
mit eigenem Prozess und Ergebnisnachweis. Ein Inventar beschreibt bekannte
Modelle, nicht deren Qualitaet oder einen erfolgreichen Kontozugang.

1. Einen Harness ausdruecklich benennen. Mit `-Action Status -Discover` nur
   Metadaten lesen; weder Modellnamen noch Modellfamilien werden erraten.
2. Die lokale Schema-3-Vorlage ausfuellen. Konto-, Provider- und Projekt-
   Konfiguration als explizite Dateihashes binden; niemals Zugangsdaten in
   Profile oder Git kopieren. Alle wirksamen Einstellungen inklusive Env-/Gateway-
   und Agent-Overrides muessen durch die gebundenen lokalen Kontextdateien
   abgedeckt sein. Ist diese Abdeckung unbekannt, keine Lauf-Freigabe erteilen.
3. Je Modell/Effort-Kombination eine gepruefte Eignungsbewertung mit Reviewer,
   Quelldatei, SHA-256, Pruefdatum und Ablaufdatum eintragen. Inventar-Metadaten
   ebenso quellenbinden. Neue Modelle ohne Bewertung sind nicht geeignet.
4. Policy und den konkreten Kandidatenpool lokal abnehmen. `catalogSha256`,
   `contextSha256` und `candidatesSha256` mit den exportierten reinen
   Hilfsfunktionen aus dem Modul berechnen. Diese Hashes sind Integritaets-
   bindungen, keine digitale Unterschrift und keine eigenstaendige Autoritaet.
5. Explizite Phasenanforderungen als JSON an `Preview` uebergeben. Vor einem
   persistenten Refresh Vorschau pruefen; danach sind `-InputConfig`,
   `-ApproveLocalRefresh` und eine ausdrueckliche lokale Freigabe erforderlich.

```bash
bash scripts/resolve-model-routing.sh -Action Preview -Harness Codex -ConfigPath /local/routing.json -RequirementsPath /local/phase.json -RoutingRoot /project/.specify/presets -ProjectRoot /project -OutputFormat Json
```

Windows: `pwsh -NoProfile -File scripts/resolve-model-routing.ps1` mit denselben
Parametern. Die Pfade sind Platzhalter. Befehle aus dem kanonischen Quellbranch
oder einem spaeter ausdruecklich installierten neuen Paket verwenden; eine
vorhandene zentrale Kopie kann noch den alten Vertrag besitzen.

```json
{
  "schemaVersion": "1.0",
  "command": "speckit.plan",
  "role": "frontier-reasoning",
  "complexity": "normal",
  "risk": "normal",
  "contextTokens": 8192,
  "capabilities": ["coding"]
}
```

### Auswahlregeln

Die staerkste deklarierte Command-Rolle bleibt verbindlich. Die Klassen sind
`simple`, `normal`, `challenging`; das Risiko ist `low`, `normal`, `high`.
Fehlende Angaben blockieren statt eine leichte Aufgabe zu unterstellen.
Frontier/Review haben mindestens normale Komplexitaet; hohes Risiko sowie
Security/Architektur verlangen `challenging`. Frontier und anspruchsvolle
Aufgaben verlangen mindestens Effort `high`, normale Aufgaben `medium`,
einfache Modellarbeit `low`. Ein Anbieter muss diese Stufe nachweislich
unterstuetzen; bei OpenCode wird die konkrete Variante zusaetzlich gebunden.

Nur nachweislich geeignete Kandidaten werden verglichen. Der kleinste lokal
abgenommene `preferenceRank` gewinnt; gleicher Rang erfordert Klaerung. Der
Rang ist eine dokumentierte Ressourcen-/Effizienzpraeferenz, keine erfundene
Preiszahl, Modellgroesse oder allgemeine Benchmark-Rangliste. Bewertung und
Policy muessen diese Praeferenz fachlich tragen. Verbrauch und Laufzeit werden
nicht geschaetzt oder ohne vergleichbare Nachweise zusammengezahlt.

Das Inventar gilt maximal 24 Stunden; eine strengere lokale TTL ist moeglich.
Zukunftsdatum, Harness-Version, Kontext-, Policy-, Kandidaten- oder Katalogdrift
invalidieren die Auswahl. Ein Modellwechsel beginnt immer einen neuen Prozess.

### Adapter und ehrliche Nachweisgrenzen

| Harness | Inventar | Ausfuehrungsbindung |
|---|---|---|
| Codex | `model/list`, strukturierte Efforts | Explizites Modell/Effort; keine Default-/Beschreibungstext-Auswahl |
| Claude | Lokal gepruefte Kandidaten | Explizites Modell/Effort, kein angeforderter Fallback; vorhandene Policy bleibt bindend |
| Copilot | Lokal gepruefte Kandidaten | Explizites Modell/Effort; Agent-Overrides im Kontext abdecken |
| agy | `agy models` liefert nur IDs | Efforts nicht aus Namen erfinden; zusaetzlicher gepruefter Nachweis erforderlich |
| OpenCode | Projektbezogene lokale Kandidaten | `provider/model#variant`; optional und ohne automatische Provider-Einrichtung |

**Die Adapter-/Identity-Fixtures sind synthetisch.** Sie beweisen weder, dass
die aktuell installierten CLIs alle verlangten nativen Modell-/Effort-Felder
ausgeben, noch einen echten Modellzugang. Insbesondere reichen Codex-
`thread.started` ohne Modell/Effort und Claude-Resultate ohne Init-Metadaten
nicht aus. Der erwartete native Kontroll-Record muss zusaetzlich explizit
`fallbackOccurred: false` bestaetigen. Dieses Feld ist Teil des strikten
Adapter-Konformitaetsvertrags, keine Behauptung ueber heute verfuegbare
CLI-Ausgaben. Solche Versionen ohne Nachweis blockieren. Vor einer operativen
Freigabe sind native Output-Konformitaet und Zugang je Harness separat zu
belegen. Erst danach darf die gepruefte Kandidaten-Evidence die Faehigkeit
`native-model-effort-acknowledgement` deklarieren; ohne sie blockiert der Runner
bereits vor dem kostenpflichtigen Preflight. Kein Feld darf aus einem Prompt, Assistant-Text oder Exitcode erfunden
werden. Das kann einen weiteren versionsgebundenen Adapter erfordern.

Genau ein Preflight ist auf 120 Sekunden begrenzt; keine Wiederholung und kein
Fallback. Eine dynamische Phase hat eine separate Grenze von 3600 Sekunden.
Diese Grenzen gelten nicht rueckwirkend fuer statische Altprofile. Vor dem
Bearbeitungsprozess wird die Auswahl nach dem Preflight erneut validiert.
Executor-Erfolg verlangt native Identitaetsbestaetigung UND die bisherigen
semantischen Ergebnis-/Evidence-Gates. Kein natives Receipt aus einer vom
Modell geschriebenen Datei akzeptieren. Der Runner startet keine laufende
Chat-Sitzung mit einem anderen Modell neu.

### Status und Migration

| Exitcode | Status | Naechste Aktion |
|---|---|---|
| 0 | `Aligned` | Vorschlag passt; Zugang/Execution sind damit nicht freigegeben |
| 2 | `RefreshRequired` | Inventar/Altprofil explizit aktualisieren bzw. migrieren |
| 3 | `Blocked` | Vertrags-, Kontext- oder Toolfehler beheben |
| 4 | `NeedsClarification` | Anforderungen, Eignung oder Prioritaet klaeren |
| 5 | `NotConfigured` | Optionales OpenCode bewusst unkonfiguriert lassen oder separat einrichten |

Alte Schema-1/1.1/2-Profile bleiben im autonomen Legacy-Pfad lesbar; der neue
Resolver deutet sie nicht um. Die automatische alte Default-/Namensheuristik
wurde im Entwicklungsbranch entfernt. Schema 3 benoetigt eine neue ausdrueckliche
Policy; alte Auswahl bedeutet keine neue dynamische Laufberechtigung.

### Pruefung

`tests/test-model-routing-discovery.sh` und der PowerShell-Partner pruefen den
Auswahlkern, negative Faelle, isolierten Refresh und read-only Preview ohne
Inferenz. `test-preset-routing-coverage.ps1` prueft alle 14 kanonischen Quellen.
[Evaluationsaufgaben](evaluation-cases.json) bilden den spaeteren Vergleich ab.
Keine Qualitaets-/Kostenueberlegenheit ohne genehmigte echte Vergleichslaeufe.
Native Linux-/Windows-Gates bleiben offen, solange sie nicht ausgefuehrt sind.

## English

This is unreleased schema-3 development, not a retroactive change to v0.1.5.
Choose one explicit harness. Status/Preview never infer or write. Discovery is
not suitability or access proof. Bind all effective account, provider, project,
environment/gateway and agent configuration through explicit local file hashes;
unknown coverage prevents execution approval. Never copy secrets into profiles.

Supply reviewed, hash-bound, dated and expiring inventory/suitability evidence.
Approve the local policy and candidate pool explicitly. Compute catalog,
context and candidate hashes through the module's pure helpers; hashes prove
integrity, not identity or permission. Preview one explicit phase before an
authorized Refresh using InputConfig, ApproveLocalRefresh and WhatIf first.

Roles remain unchanged. Require explicit complexity (simple/normal/challenging),
risk (low/normal/high), context size and capabilities. Strongest command role
wins. Frontier/review require at least normal complexity; high risk and security/
architecture require challenging. Frontier/challenging require at least high
effort, normal medium, simple model work low. Verify actual effort support and
OpenCode variants. Select the unique lowest approved preference rank among
fully suitable candidates; ties need clarification. Ranks are reviewed local
resource preferences, not invented prices, model sizes or universal benchmarks.

Inventory expires after at most 24 hours; future dates, harness version changes
and context/policy/candidate/catalog drift invalidate selection. No automatic
provider, account or subscription switching. Every phase uses a new process.
One access preflight is bounded to 120 seconds; a separate dynamic phase limit
is 3600 seconds. Revalidate after preflight. Legacy static paths retain their
existing limits. Missing native model/effort acknowledgement blocks; assistant
text, requested arguments and zero exit codes are not native identity evidence.

Adapter output/identity fixtures are synthetic. Native control metadata must
explicitly acknowledge fallbackOccurred=false; this is a strict adapter
conformance contract, not a claim that today's CLIs emit that field.
Real CLI output conformance and
access are separate gates and may require a further version-specific adapter.
Without reviewed `native-model-effort-acknowledgement` capability evidence, the
runner blocks before spending an access probe. No live five-harness execution
or quality/cost advantage is claimed. Codex uses
structured discovery, agy names only plus separately verified effort evidence,
Claude/Copilot configured reviewed candidates, OpenCode project/provider/model/
variant configuration. No auto approval or silent fallback is introduced.

Exit codes: 0 Aligned (selection only), 2 RefreshRequired, 3 Blocked,
4 NeedsClarification, 5 NotConfigured for optional OpenCode. Old profiles remain
readable on the legacy runner path, never silently migrated. Development removes
the old automatic default/name heuristic. Templates are not executable personal
model inventories. Use the command example above with real local paths.

Run the paired discovery tests and the fourteen-source coverage test. Evaluate
the linked task corpus only under separately approved inference budgets. Native
Linux/Windows checks, release, merge, runtime sync, pilots, fleet rollout and
community submissions remain separately authorized stages.
