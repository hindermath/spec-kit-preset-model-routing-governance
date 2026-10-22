## Spec Kit model discovery and routing

DE: Konkrete Modelle bleiben lokal, Git versioniert nur Rollen und Regeln.
Harness ausdruecklich waehlen, nie Anbieter wegen einer installierten CLI
wechseln. Discovery nur im nachgewiesenen Umfang behaupten. Vor jeder Phase
explizite Anforderungen und den gemeinsamen Schema-3-Selector verwenden;
Eignung und aktuelle Konto-/Provider-/Projektbindungen verlangen. Default und
Namensmuster belegen keine Qualitaet. Status/Preview schreiben nicht und rufen
keine Modelle auf. Refresh und Migration brauchen lokale Freigabe; Mehrdeutigkeit
bleibt NeedsClarification. Auswahl ist kein Zugangsnachweis. Native Modell-/
Effort-Konformitaet vor dem begrenzten Preflight belegen; fehlende Receipts und
Fallback blockieren. Script-only startet kein Modell; kein Live-Modellwechsel
und keine neue Execution-, Delivery-, Remote-, Secret- oder Bypass-Autoritaet.

EN:

- Keep concrete models in a local, non-versioned profile. Git stores only
  provider-neutral roles, adapters, and selection policy.
- Resolve the current agent surface explicitly. Never switch providers or
  harnesses merely because another executable is installed.
- Use `Enumerate`, `EnumerateNames`, `ValidateCandidate`, or `ConfiguredOnly`
  according to the adapter's proven capability. Do not claim enumeration where
  the harness offers only candidate validation.
- Before each phase use explicit requirements and the shared schema-3 selector.
  Require reviewed suitability, current inventory and complete account/provider/
  project bindings. Default flags and name patterns are not quality evidence.
- Status/Preview never infer or write. Refresh needs explicit local authority;
  never silently migrate a legacy profile. Ambiguity is NeedsClarification.
- A successful selection is not access proof. Require separately reviewed native
  model/effort conformance before spending one bounded access preflight. Missing
  acknowledgements or fallback block, not pass. No live model switching.
- `script-only` never starts a model process. Model routing grants no delivery,
  remote, secret, provider, bypass, or administrator authority.

*Keep concrete models in a local, non-versioned profile. Resolve only the
current agent surface, never switch providers silently, and fail closed for
unknown or ambiguous mappings. Model routing grants no execution or remote
authority.*
