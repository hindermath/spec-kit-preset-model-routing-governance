# Model Routing Governance

<!-- current-package: 0.2.3 -->

Paketkennung: **v0.2.3**. [Vorbereitung und Veröffentlichungsgrenze](docs/release-0.2.3-validation.md). Die Release-Seite und der externe Archivnachweis belegen die Veröffentlichung, nicht dieser Vorbereitungsstand. Frühere Versionsnachweise unten bleiben historisch.

<span lang="en">Package identity: v0.2.3. The release page and external archive evidence prove publication, not this preparation snapshot. Earlier version records below remain historical.</span>

[Release-Abschluss und Verbesserungsprofil / Publication closeout and improvement profile](docs/release-0.1.6-validation.md).

Der unten verlinkte Basispaket-Nachweis bleibt historisch; dieses Paket nimmt die Quellenkorrekturen als neue Version auf.

<span lang="en">The linked base-package evidence remains historical; this package includes the source corrections as a new version.</span>

**Leserpfad / Reader path:** [Deutsch: Einstieg, Begriffe und Fehlerhilfe](docs/user-guide.md) · [English: start, terms and troubleshooting](docs/user-guide.EN.md).

Historisches Basispaket **v0.1.6**. Der [Release-Stand](https://github.com/hindermath/spec-kit-preset-model-routing-governance/releases) wird getrennt geprüft; ein Commit auf main ist noch keine Veröffentlichung oder Installation.

*Historical base package v0.1.6. The release page records actual publication separately; a main-branch commit is not publication or installation.*


Patch **0.1.6** liefert die verbesserte zweisprachige Einstiegs- und
Kompositionsdokumentation. Verhalten und Berechtigungsgrenzen bleiben erhalten.
[Release-Nachweis / Release record](docs/release-0.1.6-validation.md).

*Patch 0.1.6 packages the improved bilingual getting-started and composition
guide. Behavior and authority boundaries remain unchanged.*

Version `0.1.6` removes a stale version-specific diagnostic from an unsupported
harness path. Generated agent instructions, bilingual documentation,
PowerShell 7 validation, and all routing and authority semantics remain
unchanged from 0.1.3.

## Deutsch

### Einstieg und Ablauf / Getting Started and Workflow

Voraussetzung: initialisiertes Zielprojekt, Spec Kit `>=0.8.3`, PowerShell 7
und ein benannter Harness, also die lokale Agenten-Integration. Beginne nach
Installation mit `$speckit-model-routing-status`. Falls eine Bindung fehlt
oder veraltet ist, Vorschlag prüfen, genau einen lokalen Refresh ausdrücklich
genehmigen und danach Status wiederholen. `Blocked` ist kein Auftrag zum
Anbieterwechsel; ein Feature-Lauf benötigt einen eigenen Auftrag.

*Prerequisites: an initialized target project, Spec Kit >=0.8.3, PowerShell 7
and an identified local harness. After installation start with status. Inspect
missing/stale binding proposals, explicitly authorize one local refresh, then
repeat status. Blocked is not provider-switch authority; feature execution
needs a separate instruction.*

Das [Manifest](preset.yml) registriert eigene Commands und separate
Policy-/Profilvorlagen, keine automatischen Plan-/Tasks-Wrapper.
Vorlagen sind Startpunkte, keine installierte persönliche Modellliste.
Das separate Agent-Guidance-Addendum wird nicht allein durch Registrierung
in jede Agenten-Datei übernommen. Modelle, Reasoning und Verfügbarkeit
bleiben lokal; Zugangsdaten nie in Git aufnehmen.

*The [manifest](preset.yml) registers standalone commands and policy/profile
starters, not automatic Plan/Tasks wrappers. Templates are not an installed
personal model inventory. Registering the separate agent-guidance addendum
does not prove inclusion in every agent file. Models, reasoning and
availability stay local; never commit credentials.*

Kleinere Prioritätszahlen haben höhere Auflösungspriorität. Andere Presets
oder Projekt-Overrides können gleichnamige Starter ersetzen. Priorität ist
keine Ausführungsreihenfolge; die stärkste deklarierte Routing-Rolle folgt
einer eigenen fachlichen Regel. Eigene Kombinationen separat prüfen.

*Lower numbers mean higher resolution precedence. Presets or local overrides
may replace same-name starters. Priority is not execution order; strongest-role
routing is a separate rule. Validate custom combinations separately.*

Leserpfad / Reader path: [Installation](#installation) → [Rollen](#rollen) →
[Harness-Fähigkeiten](#harness-fähigkeiten) → [Aufrufe](#aufrufe) →
[English](#english). Fehlende Tools oder mehrdeutige Discovery klären, keinen
Fallback erfinden. / Resolve reported tool/discovery blockers without guessing.

Neue Adapter / New adapters: [Deutsch](docs/automatic-discovery.md) · [English](docs/automatic-discovery.EN.md). **v0.2.3 ist ein Entwicklungskandidat / is a development candidate.** Kein Release, keine Installation oder Verteilung / no release, installation or rollout.

Read-only Installationsprüfung / Read-only installation checks:

```bash
specify preset info model-routing-governance
specify preset resolve model-routing-policy-template
specify preset resolve model-routing-profiles-template
```

`model-routing-governance` ordnet Spec-Kit-Arbeiten stabilen Rollen zu und
bindet diese Rollen auf jedem Rechner an tatsächlich verfügbare Modelle. Das
Preset ist öffentlich optional und wird mit Priorität `61` nach Agent Parity
(`60`) und vor Intake Authoring (`64`) installiert.

Das Remote-Repository enthält keine persönliche Modellliste. Berechtigungen,
Abonnements und Modellverfügbarkeit unterscheiden sich zwischen Rechnern und
Konten. Deshalb werden nur Rollen, Adapter und Auswahlregeln versioniert. Die
konkrete Bindung liegt lokal außerhalb des Projekt-Repositories.

### Rollen

| Rolle | Zweck |
|---|---|
| `frontier-reasoning` | Spezifikation, Klärung, Planung und Analyse |
| `long-running-implementation` | lange Implementierungsphasen |
| `coding-review` | Reviews und Retrospektiven |
| `fast-mechanical` | Status-, Read- und Next-Abfragen |
| `script-only` | deterministische Prüfungen ohne Modell |

### Harness-Fähigkeiten

Die Policy nennt Adapter-Kategorien; eine Kategorie ist kein Nachweis einer
implementierten Funktion. Im Entwicklungskandidaten dieses Pakets gilt:

| Harness | Tatsächlich vorhandener Pfad / Implemented path |
|---|---|
| Codex | Strukturierte Metadaten und automatische Profile / structured metadata and automatic profiles |
| Antigravity (`agy`) | Namenskatalog und heuristische Zuordnung / name catalogue and heuristic mapping |
| Claude | SDK-Modellliste und automatische Profile / SDK model list and automatic profiles |
| Copilot | SDK-Modellliste mit Policy-Prüfung / SDK model list with policy checks |
| OpenCode | Lokale Server-Metadaten, expliziter Provider / local server metadata, explicit provider |

*Policy categories do not prove implemented capabilities. All five harnesses have automatic paths in this candidate. New adapters have explicit prerequisites and conservative selection rules; see the adapter guide.*

Codex verwendet die vorhandenen Default-/Beschreibungshinweise; Antigravity
verwendet vorhandene Namensmuster und vorgegebene Effort-Werte. Das sind
Heuristiken, kein unabhängiger Qualitäts-, Zugangs- oder Fähigkeitsnachweis.
Codex und Antigravity behalten diese Implementierung unverändert. Die neuen Adapter sind in [Automatische Adapter](docs/automatic-discovery.md) mit Voraussetzungen und Grenzen beschrieben.

*Codex uses existing default/description hints; Antigravity uses existing name
patterns and preset effort values. These are heuristics, not independent
quality, access or capability evidence. Codex and Antigravity retain that implementation unchanged. See [automatic adapters](docs/automatic-discovery.EN.md) for the new paths.*

- `Enumerate`: strukturierte Modelle und Reasoning-Stufen, beispielsweise
  Codex `model/list`.
- `EnumerateNames`: Modellnamenliste plus Validierung, beispielsweise
  `agy models`.
- `ValidateCandidate`: ausdrücklich konfigurierte Kandidaten einzeln prüfen.
- `ConfiguredOnly`: keine belastbare Discovery; nur vorhandene Konfiguration
  verwenden.

Die letzten beiden Kategorien bleiben reservierte Policy-Begriffe. Die drei
neuen Adapter verwenden `Enumerate` mit den dokumentierten Voraussetzungen.
Fehlende Voraussetzungen blockieren; kein automatischer Anbieterwechsel.

*The last two categories remain reserved policy concepts. The three new
adapters use Enumerate with documented prerequisites. Missing prerequisites
block discovery without a provider switch.*

Die neuen Adapter verwenden Fähigkeitsfilter und deklarierte Präferenzstufen
für Claude-, GPT-, o-Serien- und Gemini-Modelle. Sonstige geeignete Modelle
können eindeutig oder über `-FrontierModel`/`-FastModel` gewählt werden.
Mehrdeutige Stufen und fehlende Fähigkeiten blockieren. Ein Modell darf mehrere
Rollen übernehmen. Keine stille Ersatzwahl bei Fehlern und kein Anbieterwechsel.

*New adapters use capability filters and declared preference tiers for Claude,
GPT, o-series and Gemini. Other capable models can be selected uniquely or with
exact model parameters. Ambiguous tiers and missing capabilities block. One
model may serve multiple roles. No silent error fallback or provider switch.*

### Aufrufe

```text
$speckit-model-routing-status
$speckit-model-routing-refresh
```

Der zweite Befehl aktualisiert beispielsweise eine lokale Codex-Bindung erst
nach ausdrücklicher Autorisierung.

Das Statuskommando ist read-only. Refresh schreibt ausschließlich die lokale
Konfigurationsdatei. Beide Commands erteilen keine Spec-Kit-, Git- oder
Remote-Autorität.

Status und Refresh lesen Discovery-Metadaten. Refresh führt den in Profilen
beschriebenen Modellzugangs-Preflight nicht aus. Ein späterer Runner-Preflight
kann trotz read-only-Sandbox Modellkontingent verbrauchen. Die eigenen
Ausführungs- und Kontingentgrenzen des Laufs gelten weiterhin.

*Status and refresh read discovery metadata. Refresh does not execute the
model-access preflight described in generated profiles. A later runner preflight
can consume model quota even in a read-only sandbox; applicable run and quota
authority remains required.*

## English

`model-routing-governance` maps Spec Kit work to stable roles and binds those
roles to models that are actually available on each machine. The public preset
is optional and uses priority `61`, after Agent Parity (`60`) and before Intake
Authoring (`64`).

The remote repository never stores personal model availability. Only roles,
adapters, and selection rules are versioned. Concrete bindings remain local.
Structured enumeration, name-only enumeration, candidate validation, and
configured-only adapters are reported honestly. Missing capabilities and
ambiguous mappings fail closed. New adapters support broad role selection;
Codex and Antigravity remain unchanged. No provider switch happens silently.

The second command in the invocation block refreshes, for example, a local
Codex binding only after explicit authorization.

## Installation

DE: Der folgende Befehl zeigt das spätere Release-Ziel. Kandidat v0.2.3 ist
noch nicht veröffentlicht; in diesem PR wird nichts installiert.

EN: The following command shows the future release target. Candidate v0.2.3
has not been published; this PR performs no installation.

```bash
specify preset add --from https://github.com/hindermath/spec-kit-preset-model-routing-governance/archive/refs/tags/v0.2.3.zip --priority 61
```

License: MIT.
