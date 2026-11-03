# Automatic adapters: development candidate 0.2.0

[Deutsch](automatic-discovery.md) · [User guide](user-guide.EN.md)

This candidate adds Claude, Copilot and OpenCode. Existing Codex/Antigravity
rules, profiles and invocations remain unchanged. Release, installation and
rollout are outside the current authority. Examples apply to the reviewed
candidate source and do not change installed presets.

## Prerequisites and status

PowerShell 7 and the selected CLI must already exist. Claude and Copilot also
need Node.js. Supply `-SdkModulePath` with the absolute JavaScript entry of an
already installed, trusted official SDK: `@anthropic-ai/claude-agent-sdk` or
`@github/copilot-sdk`. That file is imported as code: never use an untrusted
file or a model-proposed path. No automatic npm/npx, SDK, CLI or preset install.

```text
bash scripts/resolve-model-routing.sh -Action Status -Harness Claude -SdkModulePath /absolute/sdk/entry.mjs
bash scripts/resolve-model-routing.sh -Action Status -Harness Copilot -SdkModulePath /absolute/sdk/entry.js
```

On Windows invoke the same resolver with `pwsh -NoProfile -File
scripts/resolve-model-routing.ps1` and the same parameters. Example SDK paths
are placeholders and must be replaced.

Claude reads `supportedModels()` with idle streaming input. No user prompt is
submitted. Persistence, optional settings, tools and MCP are disabled for this
metadata path. Copilot starts only the SDK control process using the selected
installed CLI, then reads `listModels()` without creating an inference session.
Incompatible SDK/CLI interfaces block discovery. The SDK subprocess has a
25-second timeout.

OpenCode uses an **already running** local server. Explicitly select a connected
provider. The resolver never starts a server or changes its configuration:

```text
bash scripts/resolve-model-routing.sh -Action Status -Harness OpenCode -OpenCodeServerUrl http://127.0.0.1:4096 -OpenCodeProvider anthropic
```

The URL must be an HTTP origin with `127.0.0.1` or `[::1]`. Paths, credentials,
queries, fragments and redirects are rejected. Only `GET /provider` is read,
without a proxy. Optional server credentials come from
`OPENCODE_SERVER_PASSWORD` and `OPENCODE_SERVER_USERNAME`; the default username
is `opencode`. Never put credentials in URLs or Git. HTTP responses are limited
to 4 MiB and bounded by timeouts. No cache refresh.

Neither `Status` nor `Refresh` performs model inference. Status writes no
profiles or project files through the resolver. Vendor CLIs may maintain their
own logs, caches or authentication metadata; complete zero writes throughout
the home directory are not guaranteed. Claude does not read optional local
settings on this path; it does not fully reproduce a customized interactive
session.

## Selection and results

The versioned source `scripts/adapters/selection-policy.json` initially permits
the Opus family for the three demanding roles and Haiku for `fast-mechanical`.
This is a conservative selection rule, not measured model quality. Other
families require a separately reviewed policy extension. A higher version
number alone never selects a model.

- Claude prefers returned `opus`/`haiku` aliases. Without an alias, exactly one
  matching full identifier must exist.
- Copilot requires explicit `policy.state=enabled`. Missing, unknown,
  unconfigured or disabled policy excludes a candidate.
- OpenCode uses only the selected connected provider. Model IDs remain
  `provider/model`; errors never cause a provider switch.
- Frontier requires confirmed `high`. Fast uses confirmed `medium`, then
  `low`. Explicit absence of reasoning support permits `default`, which emits
  **no** effort/variant argument. Missing metadata differs from confirmed lack
  of support and blocks selection.

Exit code `0` means aligned, `2` means refresh required, `3` means blocked.
With no profile, status proposes a binding and returns 2. Ambiguity, duplicate
IDs, empty inventories and incompatible interfaces return 3 and preserve an
existing profile. `-WhatIf` writes nothing. After explicit local authority,
repeat the command with `-Action Refresh`. Profile schema remains 2.0.
Codex/Antigravity retain their existing `generatedBy`; new profiles use
`model-routing-governance/0.2.0`.

## Execution requires its own authority

Discovery proves neither usable quota nor successful model access. Refresh
only renders four profiles, including a later access preflight, without running
them. A subsequent runner must check its own authority, worktree boundary and
result file.

New profiles use native CLI flags: Claude `--effort`, Copilot `--effort`,
OpenCode `--variant`. CLI help is checked for required switches before live
discovery. Preflight requests `MODEL_READY`; Claude disables tools/MCP,
Copilot restricts tools to reading, OpenCode uses `plan`. Fast profiles also use
plan/read modes. Implementation profiles use Claude `acceptEdits`, OpenCode
`build`, or Copilot's existing permission checks. No bypass or blanket tool
approval. Vendor modes are **not OS sandboxes**. In particular, OpenCode agents,
plugins, hooks and local settings remain a separate trust boundary to inspect
before execution. The resolver neither executes these profiles nor installs
isolation.

## Sources and verification limits

- [Claude Agent SDK](https://code.claude.com/docs/en/agent-sdk/typescript)
- [Claude CLI](https://code.claude.com/docs/en/cli-reference)
- [Copilot SDK](https://docs.github.com/en/copilot/how-tos/copilot-sdk/troubleshooting/compatibility)
- [Copilot CLI](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference)
- [OpenCode Server](https://opencode.ai/docs/server/)
- [OpenCode CLI](https://dev.opencode.ai/docs/cli)
- [Tests, documentation decision and open evidence](adapter-extension-evidence.md)

Targets: CEFR B2 and applicable WCAG 2.2 AA. Text commands and explanations
carry the information; color is not required. Static checks do not replace
screen-reader, Braille or full accessibility acceptance.
