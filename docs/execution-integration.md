# Normale Ausfuehrung / Production execution

Dokumentationsentscheidung / Documentation impact: `UpdateRequired`.
Owner: Preset maintainers. Audience: operators and runner maintainers.
Distribution: preset source only; no installation or Home sync.

DE: `scripts/execution-policy.psm1` ist die gemeinsame Ausfuehrungsschicht fuer
den autonomen Phasenrunner und den Smoke-Test. Die erzeugten Profile und ihre
Modell-/Reasoning-Bindungen bleiben unveraendert. Der konsumierende Runner
importiert das Modul aus dem installierten Model-Routing-Preset, normalisiert
das Arbeitsverzeichnis physisch und setzt `PWD` fuer den Kindprozess gleich.
JSON-kodierte Harnessargumente werden vor der Parameterersetzung dekodiert und
danach erneut kodiert; Prompts mit Anfuehrungszeichen bleiben Daten.

DE: Preflight erhaelt keine zusaetzlichen Schreibrechte. `fast-mechanical`
erhaelt ebenfalls keine Schreibfreigabe; agy darf dort nur den Worktree lesen.
Die bereits schreibenden Rollen erhalten sitzungsgebundene Implementierungs-
rechte: agy `command(*)` plus `write_file(<physischer Worktree>)`, Claude
`Bash`/`Write`/`Edit`, Copilot `write`/`shell` mit Folder-Trust und OpenCode
`--auto` mit dem vorhandenen Build-Agent. Dies ist keine Betriebssystem-
Sandbox und ersetzt weder Aufgabenautoritaet noch einen Container.

DE: Der normale autonome Runner benoetigt die passende lokale Quellaenderung.
Ohne dieses Modul verwendet er seinen bisherigen Argumentpfad. Bestehende
Installationen werden durch die Source-Aenderungen nicht aktualisiert.
Der Adapter besitzt den JSON-Ergebnistransport fuer Claude/Copilot/OpenCode;
native Profile bekommen den genauen Ergebnisdateipfad im Phasenprompt.

EN: `scripts/execution-policy.psm1` is shared by the production autonomous phase
runner and the smoke test. Generated profiles and model/reasoning bindings
remain unchanged. The consuming runner imports the installed routing module,
resolves the physical working directory and binds child `PWD` to the same path.
JSON harness arguments are decoded before substitution and encoded again
afterwards, preserving quoted multiline prompts as data.

EN: Preflight gains no write permission. Neither does `fast-mechanical`; agy
receives only worktree read access for that role. Existing writable roles
receive session-scoped implementation permissions: agy `command(*)` and
worktree-scoped `write_file`, Claude `Bash`/`Write`/`Edit`, Copilot `write`/`shell`
and folder trust, and OpenCode `--auto` with the existing build agent. These
permissions are not an operating-system sandbox and do not replace task
authority or containers. The consuming autonomous runner needs the matching
source change; without the module it retains its legacy argument path.
Existing installations are not modified. The adapter owns result-file
transport for Claude/Copilot/OpenCode; native profiles receive the exact result
path in their phase prompt.

## Pruefung / Verification

Offline: `pwsh -NoProfile -File tests/test-execution-policy.ps1`.

Live integration (explicit model-call authority required):

```powershell
pwsh -NoProfile -File tests/live/invoke-model-routing-smoke.ps1 -ConfirmLiveRun -MaxRetries 3 -AutonomousRunnerSource /path/to/autonomous-run-governance
```

DE: Dieser Modus startet den normalen Phasenrunner mit unveraenderten
generierten Profilen. Der Test fuegt keine Werkzeugrechte hinzu. Die normale
Preflight-/Phasenausfuehrung und semantische Ergebnisvalidierung muessen
`COMPLETED` liefern; danach folgt die externe C#-Abnahme. Modellaufrufe laufen
weiter ausschliesslich in temporaeren Git-Repositories. Alte Berichte bleiben
unveraendert. Re-Evaluation bei Aenderungen an Profilen, Rollen oder CLIs.

EN: This mode invokes the production phase runner with unchanged generated
profiles. The test injects no tool permissions. Normal preflight, phase
execution and semantic result validation must yield `COMPLETED`, followed by
external C# acceptance. All model calls stay in temporary Git repositories.
Historical reports remain unchanged. Reevaluate on profile, role or CLI changes.
