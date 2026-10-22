## Summary

Implement the approved source-only dynamic phase routing design: shared
schema-3 selector, explicit role/complexity/risk/capability requirements,
reviewed local candidates, five adapter profiles, read-only status/preview,
explicit migration and bounded execution helpers. Add offline native-platform CI.

Tracking: [home-baseline#340](https://github.com/hindermath/home-baseline/issues/340).
Offline findings: [#7](https://github.com/hindermath/spec-kit-preset-model-routing-governance/issues/7).

## Validation and limitations

- Local Bash and PowerShell: same 69 deterministic assertions, not 138 cases.
- Fourteen preset sources / fifty commands covered, strongest role retained.
- Installed CLI help surfaces checked without inference; this found and fixed
  Claude permission-mode and single-element argument-vector defects.
- Native identity/effort/no-fallback records remain synthetic and unverified.
  Draft PR: do not promote to operational deployment from green fixtures alone.
- No inference, release, installation, local profile migration or Home sync.
- Native macOS/Linux/Windows CI results must be reviewed at this exact head.

## Documentation Impact

`UpdateRequired`, owner Thorsten Hindermann. DE/EN README, guide, native
verification notes, command help, templates and manpage updated together.
Audience: maintainers and pilot operators; reader path README → guide → native
verification → explicit budget approval. Source: this canonical preset repo.
No runtime distribution from this PR. Reevaluate on schema/CLI/protocol changes.

Separate budget approval and real native conformance precede pilot packages
and installation. Existing tags and installed copies remain unchanged.
