---
description: Inspect harness-local model routing without changing files
---

# Model Routing Status

Inspect the current harness, its version, discovery capability, available
models and reasoning levels, installed `model-routing.json` catalogs, and the
effective local role bindings. This command is strictly read-only. Do not
create or refresh a profile, do not invoke a model, and do not change Git or
remote state.

Resolve the script from the repository's top-level `scripts` directory when it
exists; otherwise use
`.specify/presets/model-routing-governance/scripts/resolve-model-routing.ps1`
or its Bash wrapper. Run `-Action Status`. Report `Aligned`, `RefreshRequired`,
`NeedsClarification`, or `Blocked`, followed by a text-first reason and exact
next action.

## Nutzungshilfe / Reader help

DE: Stabile Aufgabenrollen an ausdrücklich eingerichtete lokale Profile binden; die Grenzen dieses Releases sichtbar halten. Diese Command-Erklärung ändert keine Berechtigungen oder Voraussetzungen.
Die bestehenden technischen Feldnamen und Statuswerte nicht übersetzen oder
nur zum Bestehen eines Tests verändern. Einführung, Begriffe, Beispiel,
Ergebnis und Fehlerhilfe stehen im [deutschen Leserpfad](https://github.com/hindermath/spec-kit-preset-model-routing-governance/blob/main/docs/user-guide.md).

EN: Bind stable task roles to explicitly configured local profiles; keep this release's limits visible. This command explanation changes no authority or prerequisites.
Keep technical field names and states unchanged; never alter them just to pass.
See the [English reader path](https://github.com/hindermath/spec-kit-preset-model-routing-governance/blob/main/docs/user-guide.EN.md)
for introduction, terms, example, result and troubleshooting.
