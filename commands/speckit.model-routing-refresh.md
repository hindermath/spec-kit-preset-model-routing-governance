---
description: Persist one explicitly approved local schema-3 routing configuration
---

# Lokaler Refresh / Local refresh

DE: Nur mit aktueller ausdruecklicher Freigabe genau eine lokale, nicht
versionierte Konfiguration aktualisieren. Harness, Anforderungen und
InputConfig benennen; zuerst Preview und Refresh -WhatIf pruefen. Schreiben
erfordert -ApproveLocalRefresh. Keine automatische Migration, keine
Namensheuristik und keine Inferenz. Quellen-/Eignungsnachweise und lokale
Policy muessen gueltig sein. Kein Providerwechsel oder Delivery-Auftrag.

EN: Refresh exactly one local untracked config only with explicit authority.
Require explicit harness, requirements and InputConfig; inspect Preview and
Refresh -WhatIf first. Writing requires ApproveLocalRefresh. Never silently
migrate, infer, switch providers or grant delivery authority.
