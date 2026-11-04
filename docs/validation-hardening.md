# Erweiterte Testbasis / Extended validation

Documentation impact: `UpdateRequired`. Owner: routing/runner maintainers.
Audience: operators and reviewers. Canonical source: tests/live and versioned
tests/fixtures/integration-feature. Distribution: preset source, no Home sync.

## Diagnose / Diagnostics

DE: Fehlgeschlagene Discovery-, Seed-, Status- und Refresh-Prozessantworten
werden vor dem Cleanup separat gespeichert. Ein fehlendes `reason` maskiert
den Fehler nicht mehr. Timeout-Ausnahmen behalten Prozessmetadaten und bereits
verfuegbare Ausgabe; noch offene Ausgabekanaele werden sichtbar als nicht
verfuegbar markiert. Phasenergebnisse erlauben nur `outcome`, `blockedReason`,
`phaseId` und bekannte boolesche Felder. Text wird redigiert und begrenzt;
keine vollstaendigen Gespraechsverlaeufe oder Umgebungsvariablen.

EN: Failed discovery, seed, status and refresh process responses are retained
before cleanup. Missing `reason` no longer masks the failure. Timeout exceptions
retain process metadata and completed output; still-open streams are explicitly
marked unavailable. Phase diagnostics allow only outcome, blockedReason, phaseId
and known booleans. Text is redacted and bounded, not full transcripts or env.

## Feature-Fixture

DE: Die normale Integration erhaelt einen vollstaendigen synthetischen Feature-
Satz: Spec, Plan, Aufgabe T001, Research, Datenmodell, Quickstart, Checkliste,
Constitution, AGENTS und einen normalen Feature-Zustand mit Artefakt-Hashes.
Eine temporaere Feature-Branch samt lokalem Baseline-Commit macht die Annahmen
sichtbar. Fixture-lokale Bash/PowerShell-Pruefer pruefen die vorhandenen Dateien;
sie ersetzen keine produktiven Spec-Kit-Gates. Erwartet werden genau ein
paketfreies C#-Projekt, echte Ausfuehrung und der normale Ergebnisvertrag.

EN: Production integration receives a complete synthetic feature: spec, plan,
T001, research, data model, quickstart, readiness checklist, constitution, AGENTS
and normal feature state with artifact hashes. A temporary feature branch and
local baseline commit expose the assumptions. Fixture-local Bash/PowerShell
checkers validate actual files, not unrelated production gates. One package-free
C# project, execution and the normal result contract remain required.

## Compiler-Cleanup

DE: Kindprozesse deaktivieren unnoetige dauerhafte Build-Server. Zusaetzlich
beobachtet der Runner die Prozessabstammung waehrend der Ausfuehrung. Er beendet
nur erfasste VBCSCompiler mit erneut passender PID, Startzeit, Programm- und
Compilerpfad. Linux-dotnet-Hosts werden ueber ihren DLL-Argumentpfad erkannt.
Globale PID-Differenzen oder pauschales `dotnet`-Beenden sind ausgeschlossen.
Nicht beweisbarer Besitz berechtigt nicht zum Beenden. Cleanup-Zahlen werden
berichtet; Identitaetskonflikte oder fehlgeschlagene Stops blockieren Abnahme.

EN: Child processes disable unnecessary persistent build servers. The runner
also observes ancestry while invocations are alive and stops only recorded
VBCSCompiler instances after rechecking PID/start time/executable/compiler path.
Linux dotnet hosts are recognised by their compiler DLL argument. No global PID
diff or blanket dotnet kill is used. Unproven ownership never grants termination.
Counts are reported; identity conflicts or failed stops prevent acceptance.

## Lesende Rollen / Read-only roles

```powershell
pwsh -NoProfile -File tests/live/invoke-model-routing-validation.ps1 -ConfirmLiveRun -MaxRetries 3 -IncludeReadOnlyProbe -AutonomousRunnerSource ../spec-kit-preset-autonomous-run-governance
```

DE: Nach Smoke und normaler Integration folgt eine dritte Stufe mit dem echten
Fast-Profil jedes Harnesses. Der Agent soll eine vorbereitete Datei lesen und
einen absichtlich unzulaessigen Schreibwerkzeug-Aufruf versuchen, ohne Shell-
Umgehung. Erfolg verlangt Lese-/Verweigerungsbestaetigung und extern geprueftes
Fehlen von forbidden.txt. Diese Grenze wird im Bericht benannt: Die Abwesenheit
ist extern bewiesen, der konkrete Werkzeugversuch beruht auf Agentenaussage;
das ist kein Nachweis einer Betriebssystem-Sandbox. Fehlende oder abweichende
Antworten sind echte Fehlversuche. Exakte Modellauswahl bleibt unveraendert.

EN: An optional third stage uses each harness's actual fast profile to read a
prepared file and attempt one intentionally denied file-tool write, with no
shell bypass. Success requires read/denial attestation and externally verified
absence of forbidden.txt. File absence is external evidence; the attempted
tool denial is agent-attested, not an OS sandbox proof. Missing/mismatched
results fail honestly. No model/provider fallback is introduced.

## Plattformen / Platforms

DE: Offline-Tests und modellfreie .NET-Build/Run-Regressionen laufen auf der
GitHub-Matrix macOS, Ubuntu und Windows mit gepinntem setup-dotnet und SDK 10.
Native Provider-Live-Tests verlangen separate interaktive Anmeldungen auf der
jeweiligen Plattform. Der aktuelle Arbeitsplatz ist macOS; Windows/WSL sind
hier nicht verfuegbar. Eine Podman-VM ersetzt keinen nativen Windows-/WSL-Lauf;
Host-Anmeldedaten werden nicht in Container kopiert. Native Live-Nachweise
bleiben dort offen, bis passende angemeldete Umgebungen verfuegbar sind.

EN: Offline contracts and model-free .NET build/run run on the GitHub macOS,
Ubuntu and Windows matrix with pinned setup-dotnet/SDK 10. Native provider live
tests require interactive sign-ins on each platform. This host is macOS, not
Windows/WSL. A Podman VM is not native Windows/WSL evidence; host credentials
are not copied into containers. Those native live results remain open until
authenticated environments are available.

Offline commands: tests/test-validation-hardening.ps1,
tests/test-live-smoke-dotnet.ps1 -VerifyCompilerCleanup,
tests/test-execution-policy.ps1 and tests/test-paired-validation.ps1.
Reevaluate after CLI, permission, schema or fixture changes.
