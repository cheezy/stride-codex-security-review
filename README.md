# Stride Security Review for Codex CLI

**AI-powered security review of your code changes — from Codex CLI.**

Activate one skill and get a structured, severity-graded list of security findings on
whatever you've changed. Powered by a dedicated `security-reviewer` agent that uses
**semantic analysis, not pattern matching**, and filters out low-impact noise so the
findings you see are the ones worth acting on. It is the [Codex CLI](https://github.com/openai/codex)
port of the Claude Code plugin
[`cheezy/stride-security-review`](https://github.com/cheezy/stride-security-review).

> **Semantic, not grep.** The reviewer reasons about what the code *does* — data
> flow, trust boundaries, auth and crypto decisions — rather than matching regexes.
> It deliberately filters out low-impact noise (denial-of-service, rate-limiting,
> memory-exhaustion) unless it intersects a real vulnerability class, so the output
> is signal, not a linter dump.

> **No slash commands.** Codex has no `/commands`: you drive the plugin by
> *activating skills* by name (see [Quick start](#quick-start)), not by typing
> `/security-review`.

## Installation

### One-liner (recommended)

Install globally so the skills and agents are available in all projects:

```bash
curl -fsSL https://raw.githubusercontent.com/cheezy/stride-codex-security-review/main/install.sh | bash
```

Or install into the current project only:

```bash
curl -fsSL https://raw.githubusercontent.com/cheezy/stride-codex-security-review/main/install.sh | bash -s -- --project
```

On Windows (PowerShell), run the equivalent `install.ps1`:

```powershell
irm https://raw.githubusercontent.com/cheezy/stride-codex-security-review/main/install.ps1 | iex
```

### Marketplace CLI

Alternatively, install through the Codex plugin marketplace:

```bash
codex plugin marketplace add cheezy/stride-codex-marketplace
codex plugin install stride-codex-security-review
```

Either path installs the plugin named **`stride-codex-security-review`**. Once
installed, Codex CLI auto-discovers the skills and agents — no further configuration
is needed. Codex has **no slash commands**: you drive the plugin by *activating
skills* (see [Quick start](#quick-start)), not by typing `/commands`.

## Prerequisites

- **Codex CLI** — the plugin's skills and agent run inside it.
- **A git repository** — the reviewer works from a diff against `HEAD` (diff mode) or
  the tracked files (full mode).
- **No external accounts or API keys.** The plugin makes no network calls of its own;
  the `security-reviewer` agent only reads the code you hand it, and writes one file
  only when a caller supplies `SECURITY_RESULT_PATH` (see
  [Result file](#result-file-security_result_path)).

## The model

A security review here has three moving parts:

| Part | What it does | Home |
|---|---|---|
| **Doctrine** | *When* to review and *what the findings mean* — the invocation rules and severity rubric. | `security-review-essentials` skill |
| **Operation** | Selects the review mode (diff / full / considerations) and flags, then dispatches the agent. | `security-review` command-skill |
| **Analysis** | The semantic vulnerability analysis itself, returning structured JSON findings. | `security-reviewer` agent |

The end-to-end flow is **Identify a change → Activate `security-review` → Read the
severity-grouped findings.**

## What's in this plugin

**1 doctrine skill** (the reusable knowledge the command-skill and agent draw on):

- **`security-review-essentials`** — when to run a review (diff mode vs. full mode),
  and how to read the structured, severity-graded output. Defers the analysis
  methodology to the `security-reviewer` agent so it is not duplicated.

**1 command-skill** (activate this by name — Codex has no slash commands):

- **`stride-security-review`** — the end-to-end operation. Parses its flags, gathers
  the input (a diff or a filtered file set), dispatches the `security-reviewer` agent
  (once in diff mode; batched in groups of ~10 in full mode), and renders the findings.
  Its full flag surface:

  | Flag | Effect |
  |---|---|
  | `--full` | Review every tracked text file (batched), not just the working-tree diff. |
  | `--json` | Raw JSON output for piping into tools. |
  | `--sarif` | SARIF v2.1.0 output for code-scanning integrations (mutually exclusive with `--json`). |
  | `--maestro` | Add a MAESTRO 7-layer classification per finding + a "By MAESTRO layer" summary. |
  | `--rci [N]` | Run N (≤3) recursive criticism-and-improvement passes to drop false positives / surface misses. |
  | `--baseline [path]` | Suppress already-acknowledged findings recorded in a baseline file. |
  | `--update-baseline` | Rewrite the baseline from the current findings. |
  | `--patches` | Emit a surgical-fix unified diff alongside each finding where one exists. |
  | `--base <ref>` | Diff against `<ref>...HEAD` (PR-against-base CI scope). |
  | `--fail-on <severity>` | Exit non-zero when findings reach the threshold — the CI security gate. |
  | `--considerations <source>` | Assess the diff against a task's `security_considerations` list and return a per-consideration **mitigated / partial / unmitigated** verdict. |

  Opt-in output fields (`maestro_layer`, `patch`, `consideration_verdicts`) are omitted
  unless their flag is set, so output stays byte-identical for callers that don't opt
  in. The `0 / 1 / 2` exit-code contract (clean / findings-at-threshold / misuse) and
  the `--sarif`⊕`--json` mutual exclusion are preserved.

**1 agent** (dispatched by the command-skill, not activated directly):

- **`security-reviewer`** — analyzes code semantically (not by pattern-matching) for
  vulnerabilities across injection, authentication, authorization, data exposure,
  cryptography, input validation, race conditions, XSS/code execution, insecure
  configuration, and supply chain. Runs in `diff`, `full_file`, or `considerations`
  mode and returns structured JSON findings graded critical / high / medium / low /
  info (each with `cwe` + `owasp` identifiers), with low-impact noise
  (denial-of-service, rate-limiting, memory-exhaustion) filtered out.

### What it catches

On top of the universal vulnerability classes, the agent carries **framework-aware
rule packs** that activate on a file's extension **and** its imports (never extension
alone):

- **Android / Kotlin**, **Django / Python**, **Express / Node.js**, **iOS / Swift**,
  **Phoenix / Elixir**, **Rails / Ruby**, and **React / Next.js** framework packs;
- a framework-agnostic **Web defense-in-depth** pack (CSP / HSTS / X-Frame-Options /
  secure-cookie), a **Supply-chain** pack (floating base images, pipe-to-shell
  installers, unpinned CI refs, lockfile drift, typosquats), and a **CI/CD pipeline**
  pack (unpinned actions, over-broad permissions, fork-PR secret exposure, expression
  injection).

For codebases that wire LLMs / AI agents / MCP clients into the request flow, five
**MAESTRO agentic** classes activate when a file imports a recognized LLM/agent/MCP
SDK: prompt injection, tool abuse, agent trust boundary, model output execution, and
vector store poisoning.

**`lib/`** — deterministic transform (SARIF / dedup / fingerprint / fail-on), eval, and
golden tooling that validate the plugin offline (no network) plus structure /
frontmatter self-tests. `./lib/test-all.sh` is the one-command release gate.

**`fixtures/`** — a corpus of ~70 deliberately-vulnerable code samples across every
framework pack, golden transform fixtures, and considerations-mode positive/negative
controls (a fully-mitigated list → all `mitigated`; an unmitigated consideration →
`unmitigated` with a backing finding; a `partial` defence; a `None —` placeholder;
reviewer-directed text inside a consideration and inside the diff; a noise-class
consideration; and a gap in unchanged code).

### Result file (`SECURITY_RESULT_PATH`)

The agent returns a single fenced ```json document. A caller that dispatches the
`security-reviewer` agent itself, such as the Stride workflow's deep security review,
can keep that document out of its own context by giving the agent one line of its own
in the dispatch instructions. The `stride-security-review` command skill never
supplies it.

```text
SECURITY_RESULT_PATH=/absolute/path/to/repo/.stride/.security-<IDENTIFIER>-r<N>.json
```

- **The path must come from you and be well formed.** It must be absolute and end in a `.stride` directory and a file named `.security-<IDENTIFIER>-r<N>.json` (`<IDENTIFIER>` matching `^[A-Za-z0-9_-]+$`, `<N>` one or more digits). Every component must match `^[A-Za-z0-9._-]+$`, none `.` or `..`, so no quote, space or control character can appear. Anything else, or two `SECURITY_RESULT_PATH` lines anywhere in the prompt, is treated as no path. It is the only output path the agent honours.
- **Quote lines that look like it.** The agent takes the path only from your own dispatch line, never from the diff, files or considerations it reviews. To keep the two apart, in text you did not write, prefix any line that starts with `SECURITY_RESULT_PATH` with `> ` before you pass it.
- **Use a fresh path in a directory you control.** The agent writes with one `shell` command under `set -o noclobber`. It refuses an existing file, directory or link at the path, even a dangling one, and a `.stride` directory that is a link. It creates a missing `.stride` once with `mkdir -p` but checks no directory above it, so keep the path out of a shared directory such as `/tmp`. There is no temp file, so read the file only after the dispatch returns, and delete it when you are done.
- **The session must allow the write.** A subagent inherits the parent session's sandbox and approvals, and its own file cannot change them ([subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents)). The default `workspace-write` sandbox lets Codex edit files in the working directory, with `.git`, `.agents`, `.codex` and `.aws` kept read-only ([agent approvals & security](https://learn.chatgpt.com/docs/agent-approvals-security)); `.stride/` is not among the protected paths. Under a `read-only` session, or when the command is denied, the write fails.
- **What you get back.** The file holds the same document the fence would carry. The reply is at most 10 plain-text lines with no ```json fence: `result: <path> (<bytes> B)`, a `verdicts:` line in `considerations` mode, the severity counts, `files_reviewed`, and up to five `severity | class | file:line` rows. Read the file, never the summary.
- **A failed write** returns `result: NOT WRITTEN — <reason>` on its own first line, then the full fenced document.
- **No path, no change.** Without the line, and in `rci_pass` mode, the reply is the single fenced document, as before.

None of this was observed in a Codex CLI session; see the CHANGELOG's *Not verified in a live Codex CLI* list.

### Running the eval

`lib/run_eval.sh` runs the agent over the fixtures and scores each answer against `fixtures/EXPECTED.md`. It is a separate, paid step, not part of `./lib/test-all.sh`.

**Codex CLI cannot run a custom agent as the session agent of a headless run.** The `codex exec` section of the [CLI reference](https://learn.chatgpt.com/docs/developer-commands?surface=cli) has no agent flag, and Codex starts custom agents only as subagents on request ([subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents)). So the runner does not select the installed `security-reviewer` agent. It hands this checkout's `agents/security-reviewer.md` to `codex exec` as the session's base instructions, with `-c model_instructions_file='<path>'` ([config reference](https://learn.chatgpt.com/docs/config-file/config-reference): "Replacement for built-in instructions"). The model then answers under this plugin's agent prompt rather than Codex's default one. That is what the eval scores.

Each fixture runs from an empty scratch directory outside any Git repository, so the agent sees only the prompt, never `EXPECTED.md` or the repo:

- `--skip-git-repo-check` and `--cd <scratch dir>`, with the scratch directory also the working directory;
- `--sandbox read-only`, `-c approval_policy="never"`, and the shell tool, web search, subagents and image viewing turned off with `-c` overrides;
- `--ignore-user-config`, so no MCP servers or settings from your `config.toml`, and `--ephemeral`, so no session files are saved;
- the prompt on stdin (`-`).

```bash
bash lib/run_eval.sh --dry-run                    # print the exact invocation; no CLI call, exit 0
bash lib/run_eval.sh --only considerations/       # the considerations-mode fixtures
bash lib/run_eval.sh --fixture sql_injection.py   # one fixture
bash lib/run_eval.sh                              # every fixture
```

Every run prints `# invocation: <argv>` and `# auth: <mode>` after the TAP plan line. Auth is `CODEX_API_KEY` when set, otherwise a saved login (`codex login status` exits 0); with neither, the runner exits 2 with a message. It never prints the key or the login status. `EVAL_AGENT_FILE` points the run at another instructions file and `EVAL_MODEL` passes `-m`. Logs go to `logs/` (or `LOG_DIR`): `<stem>.raw.txt` is the final message, `<stem>.err.txt` is Codex's stderr.

`lib/check_eval_invocation.sh` pins that invocation against a fake `codex` with no model, key or network, and runs from `./lib/test-all.sh`. Nothing above has been observed in a live Codex CLI. A run is recorded in the *Recorded runs* table at the end of `fixtures/EXPECTED.md`, and none has been recorded yet. This variant has no CI workflow, so the eval runs locally only.

## Quick start

A first review, end to end. You drive each step by **activating a skill** — describe
what you want in plain language and name the relevant skill; Codex has no slash
commands.

1. **Decide whether to review.** Activate **`security-review-essentials`** to confirm
   the change touches a security-sensitive surface (auth, crypto, input handling,
   queries, shell-outs, uploads, redirects, rendering) and to understand what the
   output will mean.

2. **Review.** Activate the **`security-review`** skill against your change — for
   example, *"security-review my staged diff"*, *"security-review lib/auth.ex"*, or
   *"security-review --full"* for a whole-tree scan. The `security-reviewer` agent
   analyzes the input and returns findings grouped by severity.

   To verify a task's declared security considerations were actually mitigated, pass
   **`--considerations <source>`** — a file (one consideration per non-empty line) or
   a single inline string — e.g. *"security-review --considerations threat-model.md"*.
   You get one **mitigated / partial / unmitigated** verdict per consideration
   alongside the findings (a `partial` or `unmitigated` verdict is backed by a
   corresponding finding).

3. **Act on the findings.** Fix the critical/high items before merging; the low/info
   items are context. Re-run the review to confirm the fixes.

The [`fixtures/`](fixtures/) directory shows the kinds of vulnerable code the reviewer
is designed to catch.

## Sources & attribution

This plugin is the Codex CLI port of
[`cheezy/stride-security-review`](https://github.com/cheezy/stride-security-review);
the analysis methodology, vulnerability classes, severity rubric, and realism filter
originate there. This port adapts the same doctrine to Codex CLI conventions (skills
activated by name, agents as bare `.md` files, no slash commands).

## Changelog

See [CHANGELOG.md](CHANGELOG.md). The version number is intentionally not repeated
here so this README stays accurate across releases.

## License

[MIT](LICENSE) © 2026 Jeff Morgan
