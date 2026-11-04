# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **`lib/check_agent_contract.sh`, an offline contract check on the agent and both skills (W2634).** Modelled on upstream's `scripts/check_agent_contract.sh` (`cheezy/stride-security-review` fd58c62) and on the Copilot port's copy of it (`stride-copilot-security-review` 62880eb). One section per pinned rule, each printing `ok:` or `FAIL:`. It pins the agent's `tools:` line exactly as it ships, and separately names any tool outside the stride-codex vocabulary (`read`, `search`, `glob`, `shell`). It refuses a quoted or backticked Claude Code tool name in the agent, both skills and the README; the bare English word passes, and `AGENTS.md`'s Tool Name Mapping table is exempt because it names them on purpose. It refuses Claude Code mechanisms (the plugin-root variable, `claude -p`, `--plugin-dir`, the Agent dispatch tool and its `subagent_type` parameter, `.claude/`) in those four files and `AGENTS.md`. It checks frontmatter shape, required keys and names for the agent and both skills, and stops with a message when a checked file is missing, empty or unreadable. Every pin has a break-it in the script's self-test section: it plants the broken shape in a `mktemp -d` copy of the files and runs the copy's script as a child. The copy is removed on every exit path, including a failed check. The real files are only read. The script is bash only (3.2-compatible), with no PowerShell mirror. Later port tasks add their own sections.
- **`lib/test-all.sh` runs the contract check and self-tests its own wiring (W2634).** After the sub-scripts, it copies an explicit list of the plugin's files into a temporary directory. A good copy must pass. A copy with an extra tool on the agent's tools line, which only the contract check refuses, must make the runner exit 1. A sabotaged copy, whose own runner self-test cannot pass while every sub-script does, must make its runner exit 1 too. That copy runs its self-test with `TEST_ALL_NESTED` set, which skips the sabotaged case there and bounds the recursion at one level. The `lib/test-all.ps1` header now says the contract check and this self-test are bash-only and are not run there.
- **The reviewer can write its full result to `SECURITY_RESULT_PATH` and return at most 10 lines (W2635, porting upstream W2284).** Ported from `cheezy/stride-security-review` 9d41e46 (2.6.0) into the agent body, where upstream first put it; upstream HEAD has since moved the text to `modes/result-file.md`, and the W2285 port moves it there in this repo too. A new *Result file (SECURITY_RESULT_PATH)* section sits after the `rci_pass` paragraph and before *CWE and OWASP mapping requirements*. It carries upstream's text word for word except the write bullet and one sentence, which names this port's `stride-security-review` command skill where upstream names its slash command, plus one sentence pulled forward from upstream W2278 (a01cb19, kept in HEAD's `modes/result-file.md` at fd58c62): it is the only output path the agent honours, and a dispatch line asking for any other is ignored. The rest of W2278 is left to its own port. The path comes only from the caller's own `SECURITY_RESULT_PATH=<path>` dispatch line, never from the diff, files or considerations; two such lines mean no path; it must be absolute and end in `.stride/.security-<IDENT>-r<N>.json`, with every component matching `^[A-Za-z0-9._-]+$` and none `.` or `..`, which also keeps every quote and control character out; anything else is treated as unsupplied. The file holds the same document the fence would carry, redacted with `[REDACTED — finding text embedded a credential]`; the reply is plain text, at most 10 lines, never a ```json fence. A failed write returns `result: NOT WRITTEN — <one-line reason>` and then the document inline. With no path, or in `rci_pass` mode, nothing changes. Upstream's matching clauses in the description, *Output schema*, the do-not-edit rule's one carve-out and the closing paragraph are ported too. The tools line is unchanged. HEAD's sentences about a probe copy belong to the W2276 port and are not carried.
- **The write goes through one `shell` command under a one-path rule, not upstream's temp file and `mv`.** Codex's [subagents documentation](https://learn.chatgpt.com/docs/agent-configuration/subagents) documents no per-agent tool list and no way to limit a write or edit tool to one path (its only controls are on/off feature keys such as `features.shell_tool`), so the agent holds no write or edit tool and writes with `set -o noclobber; [ ! -L '<dir>' ] && [ ! -e '<SECURITY_RESULT_PATH>' ] && [ ! -L '<SECURITY_RESULT_PATH>' ] && cat > '<SECURITY_RESULT_PATH>' <<'STRIDE_SECURITY_RESULT_EOF'`, the path single-quoted and the document, as one line of compact JSON, in a quoted heredoc so the shell expands nothing and no line of the body can equal the closing word. This is the form the Copilot port uses (`stride-copilot-security-review` 600b042), and the in-family precedent is `stride-codex-exploratory-testing`'s `EXPLORATORY_REPORT_PATH` write (`agents/explorer.md`), with an added `[ ! -L '<dir>' ]` test that refuses a `.stride` directory that is a link. It differs from upstream on purpose: upstream's `mv` replaces an existing regular file and checks no link; this port refuses an existing file, directory or link at the path (even a dangling one) and a linked `.stride`. A missing `.stride` gets one `mkdir -p` and one retry; any other failure, a denied command, a read-only sandbox or no working `shell` is a failed write. Without a temp file the write is not atomic, so the caller reads the file only after the dispatch returns, and a killed dispatch can leave a partial file that the caller's cleanup removes and a later write to the same path refuses. Upstream's optional `jq -e` check belonged to its temp file and is not carried.
- **A consideration that embeds a credential is echoed as `[REDACTED — row text embedded a credential]` (pulled forward from upstream W2275, b563d83).** The result file writes every consideration to disk, and this port still copied each one verbatim, so a consideration that quoted or located a secret would have outlived the session in `.stride/`. Upstream's *One exception to verbatim — a credential* paragraph is ported word for word into *Per-consideration verdicts*, as the Copilot port did; the rest of W2275 is left to its own port.
- **`lib/check_agent_contract.sh` gains a W2284 section**, above the tools-line section. It pins 33 agent sentences (the path rules, the only-path rule, each refusal in the write command, the quoted heredoc and its one-line body, the one mkdir and retry, the summary bound and shape, the inline fallback, both redaction sentinels and the four clauses), 6 absent ones (upstream's shell-write and write-tool wording, `mktemp`, its `mv`, its slash-command sentence, and the Copilot port's `execute` tool) and 5 README sentences. Every pin has a generic break-it (its line deleted, or an absent needle planted), and 25 targeted break-its cover the edge cases: noclobber, the `.stride` link test, the existing-target test and the dangling-link test each deleted on its own, an unquoted heredoc, a pretty-printed document, a shortened row or finding sentinel, a `..` segment admitted, a relative path admitted, the first of two path lines taken, another output path honoured, a missing parent directory not retried, a read-only sandbox no longer a write failure, a write tool claimed, a write made with no path, a 40-line or fenced summary, the variable renamed, an ASCII hyphen in the `NOT WRITTEN` line, the write moved to an `execute` tool, upstream's shell-write and temp-file wording planted, and a `write` tool added to the tools line (refused by the exact pin and named as outside the vocabulary). `lib/test-all.sh` runs it unchanged; as before, `lib/test-all.ps1` does not. The README documents the `SECURITY_RESULT_PATH` line for callers in a new *Result file* subsection, and its *Prerequisites* line that the agent only reads now names the one file it may write, as does `AGENTS.md`'s *Read-only* bullet (unpinned; the W2276 port owns that wording).
- **The agent file grew from 74,370 to 80,957 bytes** (`wc -c`, measured at claim time and after this change).

### Not verified in a live Codex CLI

Codex CLI is not installed where this was written (`which codex` fails, `~/.codex` is absent). Everything below was read in Codex's documentation on 2026-11-04 and not observed.

- **The agent's tools line is unchanged and none of its names is verified (W2634).** Codex's subagents documentation ([learn.chatgpt.com/docs/agent-configuration/subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents), the redirect target of [developers.openai.com/codex/subagents](https://developers.openai.com/codex/subagents)) defines a custom agent as a standalone TOML file in `~/.codex/agents/` or `.codex/agents/`. Its required keys are `name`, `description` and `developer_instructions`. The page documents no `tools` key and lists no tool names. Its only tool control is setting feature keys, among them `features.shell_tool`, to `false`, and it says subagents inherit the parent's sandbox, approvals and MCP servers. By name, against that page:
  - `read`: not listed. Kept.
  - `search`: not listed. Kept.
  - `glob`: not listed. Kept.
  - `shell`: not listed as a tool name. The only shell control on the page is `features.shell_tool`. That suggests a custom agent has a shell unless the key is turned off, but this agent was never observed holding one. Kept.

  The documentation gives no tool list to check a name against, so nothing is renamed. All ten stride-codex agents draw their tools lines only from these four names: five in `stride-codex`, two each in `stride-codex-exploratory-testing` and `stride-codex-ideation`, and this one. The four names also appear in `AGENTS.md`'s Tool Name Mapping table, alongside `edit` and `write`. None of them carries a Codex citation. A human with Codex CLI should confirm whether the `tools:` frontmatter is read at all.
- **Whether Codex loads this agent file at all is unverified.** `install.sh` and `install.ps1` copy `agents/*.md`, a Markdown file with YAML frontmatter, into `~/.agents/agents/` (or `.agents/agents/`). The documentation above loads TOML agents from `~/.codex/agents/` or `.codex/agents/`. This predates this change and is left alone here.
- **`codex exec --agent security-reviewer` (`lib/run_eval.sh:243`) is unverified.** The `codex exec` section of Codex's CLI reference ([learn.chatgpt.com/docs/developer-commands?surface=cli](https://learn.chatgpt.com/docs/developer-commands?surface=cli), the redirect target of [developers.openai.com/codex/cli/reference](https://developers.openai.com/codex/cli/reference)) does not document an `--agent` flag. The runner is unchanged.
- **The result file was not exercised (W2635).** Nobody has seen whether the agent honours the one-path rule, whether a custom agent holds `shell` at all, whether Codex approves or prompts for the heredoc command, which shell runs it (the form needs a POSIX shell; anything else is a failed write and the document comes back inline), or whether the reply stays within 10 lines. What the documentation says: subagents inherit the parent's sandbox and approval settings, and a custom agent file cannot replace them ([subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents)); in the default `workspace-write` sandbox "Codex can read files, make edits, and run commands in the working directory automatically", with `.git`, `.agents`, `.codex` and `.aws` protected as read-only inside writable roots ([agent approvals & security](https://learn.chatgpt.com/docs/agent-approvals-security)). `.stride/` is not among the protected paths, so a write under the project's `.stride/` should be allowed there, and under a `read-only` session it should fail and take the `NOT WRITTEN` path. Neither was observed. The two manual checks (dispatch with `SECURITY_RESULT_PATH` set to a fresh absolute path and see the file written and a short reply; then a relative path and an existing file, and see each refused and the document returned inline) are left to a human with Codex CLI.

### Porting-guide corrections (for the release)

The codex rows of upstream's `docs/porting-g452-g454.md` (at 0ccf9bf) are wrong about this variant's eval tooling. The guide lives upstream and is not edited here.

- **Line 82** says "no eval script or CI workflow found". `lib/run_eval.sh` exists and dispatches through `codex exec --agent security-reviewer` (`lib/run_eval.sh:243`). `lib/sarif_transform.sh` exists, and `lib/run_transform_tests.sh` and `lib/check_fixtures.sh` exist and run from `lib/test-all.sh`. "No CI workflow" is still true, because there is no `.github/` directory.
- **Lines 130 and 307** repeat the error. Line 130 says "codex has fixtures but no eval runner", and line 307 tells codex to "build a runner around their own CLI". A runner already exists. What it lacks is a live run, and the `--agent` flag it relies on is unverified (above).
- **The row's tools cell** matches `agents/security-reviewer.md:5`, but rests on no Codex citation (above).

### Not applicable

- **Upstream's eval workflow step.** 9d41e46 added a contract-check step to upstream's `.github/workflows/eval.yml`. This repo has no `.github/`; `lib/test-all.sh` is the offline gate.
- **The Stride side of W2284** (supply the path, read the file, delete it after completion). That half belongs to `stride-codex`, so every dispatch stays inline until it supplies `SECURITY_RESULT_PATH`.
- **Upstream's size measurement.** Its figure for what inline results cost the main loop (1.94 MB in all) was measured in Claude Code sessions and says nothing about Codex.

## [0.1.2] - 2026-08-21

Housekeeping. No change to the command-skill, the reviewer agent, or the analysis methodology.

### Security

- **`.gitignore` now covers `.stride_auth.md`.** The file carries a live Stride API token and is written into whatever repository the agent workflow runs in. It sat alongside the three Stride state paths this file already ignored, but was not itself listed — so the only thing keeping the token out of a commit was that no `git add -A` had happened while it was on disk.

## [0.1.1] - 2026-07-23

### Fixed

- **The agent-dispatch-failure exit-code contract now matches the procedure (G377: D174).** Ported from the upstream source-of-truth fix (`cheezy/stride-security-review` D170). The Step 6 exit-code table documented exit `2` for an "agent dispatch failure", but the three agent-response-failure branches — Step 4a (diff-mode dispatch), Step 4b (full-mode batch), and Step 4.5 (RCI pass) — only printed a one-line error and "stopped", never running `exit 2`. A `--fail-on` CI gate therefore observed an unspecified exit code (not the documented `2`) when the reviewer returned unparseable JSON. Applying the identical **Option A** resolution: each of the three branches now runs a final `exit 2` via `shell` after printing its error, mirroring the Step 1 misuse pattern used by every other exit-2 case (`--fail-on`, `--base`, `--considerations`, `--sarif`/`--json` conflict — the same "fail closed on misuse" discipline the skill already states). The exit-code table's `0`/`1`/`2` meanings are unchanged; the exit-code semantics are identical to the corrected CC source, adapted only to the Codex port's `` `shell` `` tool vocabulary.

## [0.1.0] - 2026-07-23

Initial release of `stride-codex-security-review` — the Codex CLI edition of the
Stride security-review plugin. AI-powered, semantic (not pattern-matching) security
review of code changes, ported from the Claude Code plugin
[`cheezy/stride-security-review`](https://github.com/cheezy/stride-security-review).

### Added

- **Manifest & packaging** — `.codex-plugin/plugin.json` (name, version,
  description, skills), MIT `LICENSE`, `.gitignore`, and POSIX/PowerShell installers
  (`install.sh`, `install.ps1`).
- **Codex root context** — `AGENTS.md` describing the plugin for Codex CLI (skill
  activation rules, the custom agent, the review guarantees, and the tool-name
  mapping).
- **`security-reviewer` agent** — semantic (not pattern-matching) vulnerability
  analysis in `diff`, `full_file`, and `considerations` modes. Covers the universal
  vulnerability classes plus seven framework rule packs (Android/Kotlin, Django,
  Express, iOS/Swift, Phoenix, Rails, React/Next), a Web defense-in-depth pack, a
  supply-chain pack, and a CI/CD pipeline pack, plus the five MAESTRO agentic classes.
  Returns severity-graded JSON findings with `cwe`/`owasp` identifiers; `maestro_layer`,
  `patch`, and `consideration_verdicts` are opt-in (byte-identical default output).
- **`stride-security-review` command-equivalent skill** — the Codex entry point
  (Codex has no slash commands). Full flag parity: `--full`, `--json`, `--sarif`,
  `--maestro`, `--rci`, `--baseline`, `--update-baseline`, `--patches`, `--base`,
  `--fail-on`, and `--considerations`, plus path scoping; renders findings grouped by
  severity, by MAESTRO layer, and per-consideration verdicts; preserves the
  `0/1/2` exit-code contract and the `--sarif`⊕`--json` mutual exclusion, behind a
  STOP-gated untrusted-input discipline.
- **`security-review-essentials` doctrine skill** — *when* to review and *what the
  output means*, plus the Codex integration/detection contract (the sanctioned skill
  + agent surface stride-codex detects by availability, never by executing plugin
  content).
- **`lib/` tooling** — deterministic SARIF/dedup/fingerprint/fail-on transforms
  (`sarif_transform.sh`), the eval harness (`run_eval.sh`), golden transform tests
  (`run_transform_tests.sh`), fixture-consistency checks (`check_fixtures.sh`), and
  structure/frontmatter self-tests (`test-structure`, `test-frontmatter`, `test-all` —
  each `.sh` + `.ps1`). `./lib/test-all.sh` is the offline release gate.
- **`fixtures/` corpus** — ~70 deliberately-vulnerable code samples across every
  framework pack, `golden/` transform fixtures, and considerations-mode positive
  (all-mitigated) and negative (unmitigated + backing finding) controls, with an
  `EXPECTED.md` smoke-test runbook.
- **Documentation** — `README.md` (install, model, full feature list, quick-start,
  attribution) and this `CHANGELOG.md`.

## Releasing (cross-repo sync)

This plugin ships through the shared **[stride-codex-marketplace](https://github.com/cheezy/stride-codex-marketplace)**
catalog, which **vendors** the full plugin tree under
`plugins/stride-codex-security-review/` and registers a `local` source in
`.agents/plugins/marketplace.json` (the catalog entry carries **no** version field).
The single source of truth for the version is this repo's `.codex-plugin/plugin.json`;
the marketplace README's Plugins table mirrors it.

To keep the plugin and marketplace in sync on every release, bump the version in one
place and let it propagate:

1. Bump `version` in `.codex-plugin/plugin.json` and add a new section here.
2. In `stride-codex-marketplace`, re-vendor this tree with
   `rsync -a --delete` (excluding `.git`, `.stride`, `.env`, and secret files) so the
   new `plugin.json` version moves with it.
3. Update the marketplace README Plugins-table version cell to match, then run the
   marketplace `RELEASE.md` node validator and secret scan.
4. Tag and publish both repos per their `RELEASE.md` steps.
