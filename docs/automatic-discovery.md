# Automatische Adapter: Entwicklungskandidat 0.2.0

[English](automatic-discovery.EN.md) · [Nutzungsleitfaden](user-guide.md)

Dieser Kandidat ergänzt Claude, Copilot und OpenCode. Die bisherigen
Codex-/Antigravity-Regeln, Profile und Aufrufe bleiben erhalten. Es gibt keinen
Release-, Installations- oder Rollout-Auftrag. Die Beispiele gelten erst für
die geprüfte Kandidatenquelle; sie ändern keine installierten Presets.

## Voraussetzungen und Status

PowerShell 7 und die ausgewählte CLI müssen vorhanden sein. Für Claude und
Copilot wird zusätzlich Node.js benötigt. Gib mit `-SdkModulePath` den absoluten
JavaScript-Einstieg einer bereits installierten, vertrauenswürdigen offiziellen
SDK-Version an: `@anthropic-ai/claude-agent-sdk` oder `@github/copilot-sdk`.
Dieser Pfad wird als Code importiert; niemals eine Datei aus untrusted Quellen
oder einen Modellvorschlag dafür übernehmen. Kein automatisches npm/npx,
keine SDK-, CLI- oder Preset-Installation.

```text
bash scripts/resolve-model-routing.sh -Action Status -Harness Claude -SdkModulePath /absolute/sdk/entry.mjs
bash scripts/resolve-model-routing.sh -Action Status -Harness Copilot -SdkModulePath /absolute/sdk/entry.js
```

Unter Windows denselben Resolver mit `pwsh -NoProfile -File
scripts/resolve-model-routing.ps1` und den gleichen Parametern aufrufen.
Die Beispiele enthalten Platzhalter, keine funktionierenden SDK-Pfade.

Claude liest `supportedModels()` über einen ruhenden Streaming-Eingang. Es
wird kein Nutzerprompt gesendet. Persistenz, optionale Settings, Tools und MCP
werden für diesen Metadatenpfad deaktiviert. Copilot startet nur den
SDK-Steuerprozess mit der ausgewählten installierten CLI und liest
`listModels()`; keine Inferenz-Session wird angelegt. Unpassende SDK-/CLI-
Schnittstellen blockieren. Der SDK-Unterprozess hat ein Limit von 25 Sekunden.

OpenCode verwendet einen **bereits laufenden** lokalen Server. Benenne den
verbundenen Provider ausdrücklich; der Resolver startet keinen Server und
ändert keine Serverkonfiguration:

```text
bash scripts/resolve-model-routing.sh -Action Status -Harness OpenCode -OpenCodeServerUrl http://127.0.0.1:4096 -OpenCodeProvider anthropic
```

Die URL darf nur einen HTTP-Ursprung mit `127.0.0.1` oder `[::1]` enthalten.
Pfade, Zugangsdaten, Query, Fragment und Redirects sind gesperrt. Der Resolver
liest ausschließlich `GET /provider`, ohne Proxy. Optional übernimmt er
`OPENCODE_SERVER_PASSWORD` und `OPENCODE_SERVER_USERNAME` aus der Umgebung;
Standard-Benutzer ist `opencode`. Zugangsdaten niemals in URL oder Git ablegen.
HTTP-Antworten sind auf 4 MiB und zeitlich begrenzt. Kein Cache-Refresh.

`Status` und `Refresh` führen keine Modellinferenz aus. Der Resolver schreibt
bei Status keine Profile oder Projektdateien. Die gestarteten Hersteller-CLIs
können eigene Logs, Caches oder Anmeldemetadaten pflegen; vollständige
Nullschreibwerte im Home-Verzeichnis werden nicht zugesichert. Claude liest
auf diesem Pfad keine optionalen lokalen Settings; das ist keine vollständige
Nachbildung einer individuell angepassten interaktiven Sitzung.

## Auswahl und Ergebnisse

Die versionierte Quelle `scripts/adapters/selection-policy.json` filtert zuerst
bestätigte Fähigkeiten und verwendet danach deklarierte Präferenzstufen.
Die Reihenfolge ist eine betriebliche Heuristik, kein Benchmark oder
anbieterübergreifender Qualitätsnachweis. Weder Listenposition noch eine höhere
Versionsnummer allein entscheiden. Codex und `agy` bleiben unverändert.

| Rolle | Automatische Präferenzstufen, in Reihenfolge |
|---|---|
| Drei anspruchsvolle Rollen | `opus` → Claude Opus → GPT ohne mini/nano → o-Serie → Gemini Pro → `sonnet` → Claude Sonnet → genau ein sonstiges geeignetes Modell |
| `fast-mechanical` | `haiku` → Claude Haiku → GPT mini/nano → Gemini Flash → `sonnet` → Claude Sonnet → gewähltes Frontier-Modell wiederverwenden |

Die erste nicht leere Stufe muss genau einen geeigneten Kandidaten enthalten.
Mehrere Versionen derselben Stufe blockieren mit Kandidaten-IDs und passendem
Auswahlparameter; die Stufe wird nicht übersprungen. Ein Modell darf alle vier
Rollen übernehmen. Fehlendes Haiku ist kein Blocker und die Wiederverwendung
verspricht keine Kosten- oder Zeitersparnis.

- Alle neuen Adapter verwenden ausschließlich gemeldete IDs. Sonstige Familien
  können über eindeutige Fähigkeitsauswahl oder exakte Auswahl verwendet werden;
  es gibt keine Opus-/Haiku-Erlaubnisliste.
- Claude bevorzugt gelieferte `opus`-/`sonnet`-/`haiku`-Aliase vor vollen IDs.
  `default`, `auto` und `opusplan` sind bei Claude/Copilot ausgeschlossen, da sie
  keine exakte Modellbindung darstellen.
- `[1m]`-Einträge werden erkannt, aber wegen möglicher Kostenfolgen nur nach
  ausdrücklicher exakter Auswahl verwendet.
- Copilot benötigt ausdrücklich `policy.state=enabled`. Fehlende, unbekannte,
  unkonfigurierte oder deaktivierte Policy blockiert den Kandidaten.
- OpenCode berücksichtigt nur den benannten verbundenen Provider. Die
  Modellkennung bleibt `provider/model`; kein Anbieterwechsel bei Fehlern.
- Frontier benötigt bestätigtes `high`. Fast verwendet bestätigtes `medium`,
  sonst `low`, sonst bei ausdrücklich fehlender Reasoning-Unterstützung
  `default` ohne Effort-/Variant-Argument. Andernfalls wird eine bestätigte
  Stufe aus `high`, `xhigh`, `max` verwendet; keine niedrigere Stufe wird erfunden.
  Fehlende Metadaten schließen den Kandidaten aus. Gibt es für eine Rolle keinen
  geeigneten Kandidaten, bleibt der Lauf blockiert.

`-FrontierModel` und `-FastModel` benennen bei Bedarf exakte gemeldete IDs,
auch für neue Familien. Bei OpenCode gehört der Provider zur ID. Fähigkeiten,
Anmeldung, Copilot-Policy und Providerbindung werden damit nicht umgangen.
Beispiel mit synthetischen IDs, keine Zusage tatsächlicher Verfügbarkeit:

```text
bash scripts/resolve-model-routing.sh -Action Status -Harness Copilot -SdkModulePath /absolute/sdk/entry.js -FrontierModel gpt-99 -FastModel gpt-99-mini
```

Für spätere Status-/Refresh-Aufrufe dieselben expliziten Auswahlparameter
verwenden. Diese neuen Parameter gelten nicht für Codex oder `agy`.

`0` bedeutet ausgerichtet, `2` bedeutet Refresh erforderlich, `3` bedeutet
blockiert. Ohne Profil zeigt Status einen Vorschlag mit Exitcode 2. Mehrdeutige
Treffer, doppelte IDs, leere Listen oder inkompatible Schnittstellen ergeben
Exitcode 3 und erhalten ein bestehendes Profil. `-WhatIf` schreibt nichts.
Nach ausdrücklicher lokaler Freigabe denselben Aufruf mit `-Action Refresh`
wiederholen. Das Schema bleibt 2.0. `generatedBy` bleibt für Codex/Antigravity
unverändert; neue Profile tragen `model-routing-governance/0.2.0`. Zusätzlich
bindet `selectionPolicySha256` die Auswahlpolicy. Ein anderer oder fehlender
Hash ergibt `RefreshRequired`, ohne das Profil beim Status zu ändern.

## Ausführung bleibt ein eigener Auftrag

Discovery beweist keine nutzbare Quote und keinen erfolgreichen Modellzugriff.
Refresh erzeugt lediglich vier Profile einschließlich eines späteren
Zugangs-Preflights. Er führt diesen nicht aus. Ein späterer Runner muss seine
eigene Autorität, Arbeitsverzeichnisgrenze und Ergebnisdatei prüfen.

Neue Profile verwenden die native CLI: Claude `--effort`, Copilot `--effort`,
OpenCode `--variant`. CLI-Hilfe wird vor echter Discovery auf die benötigten
Schalter geprüft. Der Preflight bittet um `MODEL_READY`; Claude deaktiviert
Tools/MCP, Copilot begrenzt Tools auf Lesen, OpenCode nutzt `plan`.
Fast-Profile verwenden ebenfalls Plan-/Lesemodi. Implementierungsprofile
verwenden Claude `acceptEdits`, OpenCode `build` beziehungsweise Copilots
bestehende Berechtigungsprüfung. Kein Bypass und keine pauschale Toolfreigabe.
Hersteller-Modi sind **keine Betriebssystem-Sandbox**; insbesondere OpenCode-
Agenten, Plugins, Hooks und lokale Einstellungen müssen vor Ausführung als
eigener Vertrauensbereich geprüft werden. Der Resolver führt diese Profile
nicht aus und installiert keine Isolation.

## Quellen und Prüfgrenzen

- [Claude Agent SDK](https://code.claude.com/docs/en/agent-sdk/typescript)
- [Claude CLI](https://code.claude.com/docs/en/cli-reference)
- [Claude-Modellkennungen](https://code.claude.com/docs/en/model-config)
- [Copilot SDK](https://docs.github.com/en/copilot/how-tos/copilot-sdk/troubleshooting/compatibility)
- [Copilot CLI](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference)
- [OpenCode Server](https://opencode.ai/docs/server/)
- [OpenCode CLI](https://dev.opencode.ai/docs/cli)
- [Tests, Dokumentationsentscheidung und offene Nachweise](adapter-extension-evidence.md)

Ziel: CEFR B2, anwendbare WCAG 2.2 AA. Textbefehle und Fehlergründe tragen die
Information; Farben sind nicht erforderlich. Statische Prüfungen ersetzen keine
Screenreader-, Braille- oder vollständige Barrierefreiheitsabnahme.
