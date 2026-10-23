# resolve-model-routing(1)

## NAME / NAME

resolve-model-routing - lokale Spec-Kit-Modellbindungen prüfen oder aktualisieren

*resolve-model-routing - inspect or refresh local Spec Kit model bindings*

## AUFRUF / SYNOPSIS

```text
pwsh -NoProfile -File scripts/resolve-model-routing.ps1 -Action Status [-Harness Codex]
bash scripts/resolve-model-routing.sh -Action Refresh -Harness Antigravity
```

## BESCHREIBUNG

`Status` liest ausschließlich den aktuellen Zustand. `Refresh` schreibt das
ausgewählte lokale Profil nur, wenn Discovery und Validierung genau eine
bekannte Zuordnung bestätigen. Unbekannte oder mehrdeutige Modelle blockieren.
Keine Aktion verändert das Repository oder erteilt Delivery-Autorität.

Automatische Profile unterstützt der stabile Resolver nur für Codex und
Antigravity. Claude, Copilot und OpenCode werden nicht allein durch ihre
Policy-Bezeichnung zu implementierten Adaptern. Refresh prüft Metadaten; er
führt keinen Modellzugangs-Preflight aus. Der spätere Runner-Preflight kann
Kontingent verbrauchen und braucht die passende Ausführungsautorität.

## DESCRIPTION

`Status` is read-only. `Refresh` writes only the selected local profile after
a known, unique mapping passes discovery and validation. Unknown or ambiguous
models fail closed. Neither action changes a repository or grants delivery
authority.

The stable resolver renders automatic profiles only for Codex and Antigravity.
Claude, Copilot and OpenCode policy labels are not implemented adapters.
Refresh checks metadata; it does not run a model-access preflight. A later
runner preflight can consume quota and needs applicable execution authority.

## ENDESTATUS / EXIT STATUS

- `0`: ausgerichtet oder erfolgreich aktualisiert / aligned or refreshed successfully
- `2`: Aktualisierung oder Klärung erforderlich / refresh required or needs clarification
- `3`: durch fehlende Harness-, Discovery-, Modell- oder Reasoning-Evidence blockiert / blocked by missing harness, discovery, model, or reasoning evidence
