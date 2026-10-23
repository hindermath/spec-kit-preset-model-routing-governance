# Model Routing Governance

<!-- current-package: 0.1.6 -->

**Leserpfad / Reader path:** [Deutsch: Einstieg, Begriffe und Fehlerhilfe](docs/user-guide.md) · [English: start, terms and troubleshooting](docs/user-guide.EN.md).

Quellkandidat **v0.1.6**. Der [Release-Stand](https://github.com/hindermath/spec-kit-preset-model-routing-governance/releases) wird getrennt geprüft; ein Commit auf main ist noch keine Veröffentlichung oder Installation.

*Source candidate v0.1.6. The release page records actual publication separately; a main-branch commit is not publication or installation.*


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
implementierten Funktion. Im stabilen Resolver dieses Pakets gilt:

| Harness | Tatsächlich vorhandener Pfad / Implemented path |
|---|---|
| Codex | Strukturierte Metadaten und automatische Profile / structured metadata and automatic profiles |
| Antigravity (`agy`) | Namenskatalog und heuristische Zuordnung / name catalogue and heuristic mapping |
| Claude | Keine automatische Kandidatenprüfung oder Profilerzeugung / no automatic candidate validation or profile rendering |
| Copilot | Keine automatische Kandidatenprüfung oder Profilerzeugung / no automatic candidate validation or profile rendering |
| OpenCode | Policy-Kategorie, kein implementierter automatischer Resolverpfad / policy category, no implemented automatic resolver path |

*Policy categories do not prove implemented capabilities. Only Codex and
Antigravity have automatic selection/profile paths in this stable resolver.
Other harness labels must not be presented as working adapters.*

Codex verwendet die vorhandenen Default-/Beschreibungshinweise; Antigravity
verwendet vorhandene Namensmuster und vorgegebene Effort-Werte. Das sind
Heuristiken, kein unabhängiger Qualitäts-, Zugangs- oder Fähigkeitsnachweis.
Dieser Dokumentationspatch ändert diese Implementierung nicht.

*Codex uses existing default/description hints; Antigravity uses existing name
patterns and preset effort values. These are heuristics, not independent
quality, access or capability evidence. This documentation patch changes
none of that implementation.*

- `Enumerate`: strukturierte Modelle und Reasoning-Stufen, beispielsweise
  Codex `model/list`.
- `EnumerateNames`: Modellnamenliste plus Validierung, beispielsweise
  `agy models`.
- `ValidateCandidate`: ausdrücklich konfigurierte Kandidaten einzeln prüfen.
- `ConfiguredOnly`: keine belastbare Discovery; nur vorhandene Konfiguration
  verwenden.

Die letzten beiden Kategorien beschreiben Policy-Begriffe, nicht hier
implementierte Ausführungspfade. Bei diesen Harnessen die bestehende Grenze
melden; kein automatischer Wechsel und keine Behauptung einer erfolgreichen Prüfung.

*The last two categories are policy concepts, not implemented execution paths
in this release. Report the existing limit rather than switching harnesses or
claiming a successful check.*

Unbekannte oder mehrdeutige Zuordnungen blockieren. Es gibt keinen stillen
Fallback und keinen automatischen Anbieterwechsel.

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
configured-only adapters are reported honestly. Unknown or ambiguous mappings
fail closed, and no provider switch happens silently.

The second command in the invocation block refreshes, for example, a local
Codex binding only after explicit authorization.

## Installation

```bash
specify preset add --from https://github.com/hindermath/spec-kit-preset-model-routing-governance/archive/refs/tags/v0.1.6.zip --priority 61
```

License: MIT.
