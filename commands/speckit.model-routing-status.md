---
description: Inspect harness-local routing without inference or writes
---

# Routing-Status / Routing status

DE: Einen ausdruecklichen Harness und die lokale Konfiguration verwenden.
Den Resolver aus diesem Preset mit `-Action Status` aufrufen; nicht still eine
aeltere zentrale Kopie verwenden. Fuer eine konkrete Auswahl explizite
Phasenanforderungen uebergeben. `-Discover` liest nur Inventar-Metadaten.
Aligned, RefreshRequired, NeedsClarification, NotConfigured oder Blocked samt
Grund und naechster Aktion berichten. Kein Refresh, Modellaufruf oder Git-Write.

EN: Use an explicit harness and local configuration. Run this preset's
resolver with Status, not an older central copy. Supply explicit phase
requirements for selection. Discover only reads inventory metadata. Report
status, reason and next action. Never refresh profiles, infer, or mutate Git.
