# resolve-model-routing(1)

## NAME / NAME

resolve-model-routing - dynamisches Phasen-Routing pruefen / inspect dynamic phase routing

## AUFRUF / SYNOPSIS

```text
bash scripts/resolve-model-routing.sh -Action Status -Harness Codex [-Discover]
bash scripts/resolve-model-routing.sh -Action Preview -Harness Codex -ConfigPath local.json -RequirementsPath phase.json -RoutingRoot .specify/presets -ProjectRoot .
pwsh -NoProfile -File scripts/resolve-model-routing.ps1 -Action Refresh -Harness Claude -ConfigPath local.json -InputConfig approved-draft.json -RequirementsPath phase.json -RoutingRoot .specify/presets -ProjectRoot . -ApproveLocalRefresh -WhatIf
```

## BESCHREIBUNG / DESCRIPTION

DE: Unveroeffentlichter Schema-3-Vertrag. Status/Preview schreiben nicht und
rufen kein Modell auf. Discovery liest Kataloge ohne Eignung oder Zugang zu
behaupten. Jeder Harness ist explizit; Auto verlangt Klaerung. Anforderungen
und genehmigte lokale Evidence binden jede Auswahl. Refresh verlangt eine
ausdrueckliche lokale Freigabe und einen validierten Entwurf; zuerst WhatIf.
Altprofile bleiben erhalten. Keine Installation, Inferenz oder Delivery.

EN: Unreleased schema-3 contract. Status/Preview never write or infer.
Discovery is not suitability or access proof. Explicit harness and phase
requirements plus reviewed local evidence are mandatory. Refresh requires
explicit local authority and a validated draft, previewed with WhatIf.
Legacy profiles are preserved. No install, inference or delivery authority.

Details: [DE/EN-Vertrag / contract](../dynamic-routing.md).

## ENDESTATUS / EXIT STATUS

- 0: Aligned (Auswahl, kein Zugangsnachweis / selection, not access)
- 2: RefreshRequired (veraltet oder Migration noetig / stale or migration required)
- 3: Blocked (Vertrags-/Kontext-/Toolfehler / contract, context or tool failure)
- 4: NeedsClarification (fehlende oder mehrdeutige Eignung / missing or ambiguous suitability)
- 5: NotConfigured (optionales OpenCode / optional OpenCode)
