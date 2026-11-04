# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **`lib/check_agent_contract.sh`, an offline contract check on the agent and both skills (W2634).** Modelled on upstream's `scripts/check_agent_contract.sh` (`cheezy/stride-security-review` fd58c62) and on the Copilot port's copy of it (`stride-copilot-security-review` 62880eb). One section per pinned rule, each printing `ok:` or `FAIL:`. It pins the agent's `tools:` line exactly as it ships, and separately names any tool outside the stride-codex vocabulary (`read`, `search`, `glob`, `shell`). It refuses a quoted or backticked Claude Code tool name in the agent, both skills and the README; the bare English word passes, and `AGENTS.md`'s Tool Name Mapping table is exempt because it names them on purpose. It refuses Claude Code mechanisms (the plugin-root variable, `claude -p`, `--plugin-dir`, the Agent dispatch tool and its `subagent_type` parameter, `.claude/`) in those four files and `AGENTS.md`. It checks frontmatter shape, required keys and names for the agent and both skills, and stops with a message when a checked file is missing, empty or unreadable. Every pin has a break-it in the script's self-test section: it plants the broken shape in a `mktemp -d` copy of the files and runs the copy's script as a child. The copy is removed on every exit path, including a failed check. The real files are only read. The script is bash only (3.2-compatible), with no PowerShell mirror. Later port tasks add their own sections.
- **`lib/test-all.sh` runs the contract check and self-tests its own wiring (W2634).** After the sub-scripts, it copies an explicit list of the plugin's files into a temporary directory. A good copy must pass. A copy with an extra tool on the agent's tools line, which only the contract check refuses, must make the runner exit 1. A sabotaged copy, whose own runner self-test cannot pass while every sub-script does, must make its runner exit 1 too. That copy runs its self-test with `TEST_ALL_NESTED` set, which skips the sabotaged case there and bounds the recursion at one level. The `lib/test-all.ps1` header now says the contract check and this self-test are bash-only and are not run there.

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

### Porting-guide corrections (for the release)

The codex rows of upstream's `docs/porting-g452-g454.md` (at 0ccf9bf) are wrong about this variant's eval tooling. The guide lives upstream and is not edited here.

- **Line 82** says "no eval script or CI workflow found". `lib/run_eval.sh` exists and dispatches through `codex exec --agent security-reviewer` (`lib/run_eval.sh:243`). `lib/sarif_transform.sh` exists, and `lib/run_transform_tests.sh` and `lib/check_fixtures.sh` exist and run from `lib/test-all.sh`. "No CI workflow" is still true, because there is no `.github/` directory.
- **Lines 130 and 307** repeat the error. Line 130 says "codex has fixtures but no eval runner", and line 307 tells codex to "build a runner around their own CLI". A runner already exists. What it lacks is a live run, and the `--agent` flag it relies on is unverified (above).
- **The row's tools cell** matches `agents/security-reviewer.md:5`, but rests on no Codex citation (above).

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
