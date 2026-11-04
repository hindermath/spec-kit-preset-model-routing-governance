# Platform-neutral model-routing live smoke test

The canonical live test lives under `tests/live/`. It uses the same PowerShell
7 runner on macOS, Windows and Ubuntu/WSL2. The run is deliberately manual: it
uses existing interactive harness sign-ins, may consume model quota and writes
temporary projects. Normal CI runs only the fully offline contract test.

Deutsch: [Plattformneutraler Live-Smoke-Test](live-smoke-test.md).

## When is the test required?

Repeat the test after changes to the resolver, Bash wrapper, adapters,
selection policy, profile rendering, result transport, SDK/CLI compatibility
or the acceptance matrix. The binding path patterns are stored in
`tests/live/model-routing-smoke.defaults.json`. Documentation-only and
historical-evidence changes do not trigger a live run.

## Prerequisites and authority

- PowerShell 7.3 or newer, Node.js/npm, Git and .NET SDK 10;
- `agy`, `claude`, `codex`, `copilot` and `opencode` on `PATH`;
- an existing interactive sign-in for every harness or provider;
- a clean candidate worktree;
- explicit authority for model use and temporary writes.

API-key environment variables are removed from child processes. Pinned Claude
and Copilot SDKs are staged without install scripts in a temporary directory.
OpenCode uses a temporarily authenticated loopback server. The run grants no
push, PR, merge, release, installation, Home sync or rollout authority.

## Invocation

Strict run without retry:

```powershell
pwsh -NoProfile -File tests/live/invoke-model-routing-smoke.ps1 -ConfirmLiveRun
```

Explicitly permit up to three retries per harness:

```powershell
pwsh -NoProfile -File tests/live/invoke-model-routing-smoke.ps1 -ConfirmLiveRun -MaxRetries 3
```

Without `-ConfirmLiveRun`, the script blocks before SDK, server or harness
activity. A retry uses a fresh temporary Git repository and exactly the same
model/provider binding. A later successful attempt is reported as
`PASS_WITH_RETRY`, never hidden as a plain `PASS`.

## Versioned selection and local deviation

The defaults verify Claude `opus`/`haiku`, Copilot
`claude-opus-5.5`/`claude-haiku-5.5`, and OpenCode
`openai/gpt-6.1-terra`/`openai/gpt-6-luna`. Codex and `agy` remain fully
automatic. These IDs are acceptance expectations, not availability promises
for every account.

For example, store a different local selection as
`tests/live/model-routing-smoke.local.json` and pass it explicitly:

```json
{
  "schemaVersion": "1.0",
  "selections": {
    "Copilot": {
      "frontierModel": "exact-frontier-id",
      "fastModel": "exact-fast-id"
    }
  }
}
```

```powershell
pwsh -NoProfile -File tests/live/invoke-model-routing-smoke.ps1 `
  -ConfirmLiveRun `
  -SelectionFile tests/live/model-routing-smoke.local.json
```

The local file is Git-ignored. Its report is marked `local-override` and must
not silently serve as evidence for the versioned defaults.

## Acceptance and result

Every harness receives the same task: create a package-free .NET 10 app, run it
and verify exactly `MODEL_ROUTING_OK`. After one exact selection, Claude,
Copilot and OpenCode must pass parameterless `Status` and `Refresh` calls with
`Aligned` and a byte-identical profile. The runner then independently checks
exactly one C# project, no `PackageReference`, build, run, exit code and output.

The 120-second budget covers discovery, stored-profile reuse, preflight and the
agent task per attempt. Build and run each have a separate 30-second limit. The
application and package restore receive no package source; provider access
remains necessary for the harness.

Reports are stored locally under `.test-results/model-routing-smoke/` and
contain commit, platform, configuration hash, every attempt, models, reasoning,
durations, exit codes, output and cleanup proof. Final states are `PASS`,
`PASS_WITH_RETRY`, `FAILED`, `BLOCKED`, `TIMEOUT` and `INFRA_ERROR`. Reports are
Git-ignored. A summary is promoted into release evidence only with explicit
authority.
The process exits with code 0 for `PASS` and `PASS_WITH_RETRY`, and with code 1
for every other final state.

## Documentation decision

`UpdateRequired`, owner Thorsten Hindermann. Canonical sources are the runner,
acceptance matrix, this document and its German language partner. Audience:
preset operators and maintainers. Distribution: preset source; no Home sync.
Re-evaluate on SDK, CLI, provider, model or authentication drift.
