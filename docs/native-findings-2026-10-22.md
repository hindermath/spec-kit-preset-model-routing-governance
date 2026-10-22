# Offline-Findings vor dem Routing-Piloten / Offline findings before routing pilots

Central tracking: [home-baseline#340](https://github.com/hindermath/home-baseline/issues/340).

## DE

Drei reproduzierbare Fehler im unveroeffentlichten dynamischen Entwicklungsstand:

1. Claude-Adapter verwendet `--permission-mode default`, obwohl die installierte
   Claude-Code-CLI 2.1.304 diesen Wert nicht dokumentiert und `manual` anbietet.
2. Child-Runner lehnt JSON-Argumentarrays mit einem Element ab: `ConvertFrom-Json`
   entpackt `["--version"]` zum Skalar. Dadurch scheitern alle fuenf echten
   CLI-Audits vor dem Harnessstart, obwohl Mehrargument-Fixtures bestehen.

3. Der erste native Windows-CI-Lauf behielt CR aus CRLF in der logischen
   Subprozess-Ausgabe. Korrigiert ist ausschliesslich die Zeilentrennung;
   eine zusaetzliche CRLF-Fixture erhaelt die exakte Record-Assertion.

Korrekturen im Entwicklungsbranch: `manual` plus unveraendert verweigerte
unbeantwortete Prompts; `ConvertFrom-Json -NoEnumerate`. Regressionen fuer
Claude-Modus und Einzelelement-Argumentvektor. Native Receipt-Validatoren und
Timeouts bleiben unveraendert streng. Die CLI-Oberflaechenpruefung besteht nach
Korrektur, beweist aber keine reale Inferenz oder effektive Berechtigungen.

Bisherige Tags/ZIPs und installierte Pakete sind nicht von dieser Quellkorrektur
veraendert. Kein Live-Run vor separater Budgetfreigabe und nativer Evidence.

## EN

Two reproducible defects in unreleased dynamic routing: Claude's adapter used
undocumented `default` permission mode instead of the installed CLI's `manual`;
the child runner unwrapped single-element JSON argument arrays and rejected
metadata commands before launching any harness. Multi-argument fixtures had
not covered that case. Corrections preserve denied unattended approvals and
array shape, with dedicated regressions. Native identity validators and timeouts
remain strict. Successful CLI help checks are not live model/permission proof.
Existing tags, archives and installations are unchanged. Real probes require
separate budget approval and native evidence.

The first native Windows CI also exposed CRLF delimiters retained inside
logical output records. Correcting the delimiter handling and adding an exact
CRLF regression preserves the oracle. The expanded suite has seventy assertions;
native macOS, Linux and Windows passed in run 39743006078 at exact head 84b473b.

Documentation Impact: `UpdateRequired`; owner Thorsten Hindermann. This finding
is source-only developer evidence, not operational or product acceptance.
