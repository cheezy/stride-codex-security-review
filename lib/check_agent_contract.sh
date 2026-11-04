#!/usr/bin/env bash
# Contract pins on agents/security-reviewer.md and the two skills for the
# Codex CLI port.
#
# Modelled on upstream cheezy/stride-security-review scripts/check_agent_contract.sh
# (fd58c62) and on the Copilot port's copy of it (stride-copilot-security-review
# 62880eb): one section per item, headed by the task that added it, each pin
# printing `ok: <label>` or `FAIL: <label> -- <why>`. Every later port task adds
# its own section here, above the tools-line section. Unlike upstream, each pin
# also carries a break-it in the self-test section at the bottom, which plants
# the broken shape in a temporary copy of the plugin tree and checks that this
# script fails on it.
#
# W2634 -- the tools line. Codex's subagents documentation
# (https://learn.chatgpt.com/docs/agent-configuration/subagents, redirected from
# https://developers.openai.com/codex/subagents) defines a custom agent as a
# standalone TOML file with the required keys name, description and
# developer_instructions. It documents no `tools` key and lists none of the
# names on this agent's tools line; its only tool control is setting feature
# keys such as `features.shell_tool` to false. The documentation is silent on
# every name, so none is renamed: the line is pinned exactly as it ships, and
# its four names are the only ones any stride-codex agent's tools line uses. That
# vocabulary is NOT verified against Codex, and none of this was observed in a
# Codex CLI session (see CHANGELOG [Unreleased]).
#
# Bash only (no PowerShell mirror; lib/test-all.ps1 says so). Offline, bash 3.2
# compatible. Reads the plugin's files; the self-tests write only to a temporary
# directory, removed on every exit. No command is built from file contents:
# every awk program and pattern is fixed here.
#
# Usage:  bash lib/check_agent_contract.sh [agent-file [command-skill [essentials-skill]]]
#         (defaults: agents/security-reviewer.md,
#          skills/stride-security-review/SKILL.md and
#          skills/security-review-essentials/SKILL.md beside this lib/)
# Exit code: 0 when every pin and self-test holds; 1 when any fails, or when
#            a checked file is missing, empty or unreadable.
set -uo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SELF="$SCRIPT_DIR/$(basename "$0")"
ROOT="$SCRIPT_DIR/.."
AGENT="${1:-$ROOT/agents/security-reviewer.md}"
CMD="${2:-$ROOT/skills/stride-security-review/SKILL.md}"
ESS="${3:-$ROOT/skills/security-review-essentials/SKILL.md}"
README="$ROOT/README.md"
AGENTS_MD="$ROOT/AGENTS.md"
fail=0

guard() { # $1=kind $2=path -- a missing, empty or unreadable file stops the run
  [ -f "$2" ] || { echo "FAIL: $1 file not found: $2"; exit 1; }
  [ -s "$2" ] || { echo "FAIL: $1 file is empty: $2"; exit 1; }
  [ -r "$2" ] || { echo "FAIL: $1 file is not readable: $2"; exit 1; }
}
guard agent "$AGENT"
guard "command skill" "$CMD"
guard "essentials skill" "$ESS"
guard README "$README"
guard AGENTS.md "$AGENTS_MD"

absent_re_in() { # $1=file $2=label $3=ERE that must NOT match
  local hit rc
  hit="$(grep -nE -m 1 -- "$3" "$1")"; rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "FAIL: $2 -- found: $(printf '%s' "$hit" | cut -c 1-80)"; fail=1
  elif [ "$rc" -eq 1 ]; then
    echo "ok: $2"
  else
    # grep exits 2 on an error; an error must never read as a pass.
    echo "FAIL: $2 -- grep could not read $1 (exit $rc)"; fail=1
  fi
}

# --- W2634: no Claude Code tool name in ported text --------------------------
# A quoted or backticked name is the tool; the bare English word ("Read the
# diff") is not, and passes. The names are held in a variable so this script
# never spells one as a quoted tool name itself. AGENTS.md is not checked here:
# its Tool Name Mapping table names them on purpose. CHANGELOG.md is history.

cc_tools='Read|Grep|Glob|Bash|Edit|Write|MultiEdit|NotebookEdit|WebFetch|WebSearch|Task|Agent'
CC_TOOL_RE="[\"'\`](${cc_tools})[\"'\`]"

absent_re_in "$AGENT"  "the agent names no Claude Code tool"            "$CC_TOOL_RE"
absent_re_in "$CMD"    "the command skill names no Claude Code tool"    "$CC_TOOL_RE"
absent_re_in "$ESS"    "the essentials skill names no Claude Code tool" "$CC_TOOL_RE"
absent_re_in "$README" "the README names no Claude Code tool"           "$CC_TOOL_RE"

# --- W2634: no Claude Code mechanism in ported text --------------------------
# The plugin-root variable, the headless and plugin-directory flags, the agent
# dispatch tool and its parameter, and the per-user config directory belong to
# Claude Code; the Codex port uses Codex CLI's own mechanisms.

CC_MECH_RE='CLAUDE_PLUGIN_ROOT|claude -p|--plugin-dir|[Tt]he Agent tool|subagent_type|\.claude/'

absent_re_in "$AGENT"     "the agent uses no Claude Code mechanism"            "$CC_MECH_RE"
absent_re_in "$CMD"       "the command skill uses no Claude Code mechanism"    "$CC_MECH_RE"
absent_re_in "$ESS"       "the essentials skill uses no Claude Code mechanism" "$CC_MECH_RE"
absent_re_in "$README"    "the README uses no Claude Code mechanism"           "$CC_MECH_RE"
absent_re_in "$AGENTS_MD" "AGENTS.md uses no Claude Code mechanism"            "$CC_MECH_RE"

# --- The frontmatter tools line (W2634; upstream W2276's shape) --------------
# Exactly these four, in this order, as a JSON flow array on one line. A YAML
# block list, an added tool, a dropped tool, a reordered or respaced line, or a
# second tools line all fail. A second check names any tool outside the
# stride-codex vocabulary, so a renamed tool says which name is foreign.

TOOLS_WANT='tools: ["read", "search", "glob", "shell"]'
TOOLS_VOCAB='read search glob shell'
tools_line="$(awk 'NR == 1 && /^---$/ { f = 1; next } f && /^---$/ { exit } f && /^tools:/' "$AGENT")"
if [ "$tools_line" = "$TOOLS_WANT" ]; then
  echo "ok: the frontmatter tools line"
else
  echo "FAIL: the frontmatter tools line -- got: $(printf '%s' "$tools_line" | tr '\n' ' ')"
  fail=1
fi

tool_names="$(printf '%s\n' "$tools_line" | sed -n 's/^tools: *\[\(.*\)\]$/\1/p' | tr ',' '\n' | sed 's/^ *"//; s/" *$//')"
if [ -z "$tool_names" ]; then
  echo "FAIL: the tools line names only the stride-codex vocabulary -- no names on a one-line JSON array"
  fail=1
else
  outside=""
  set -f
  for nm in $tool_names; do
    case " $TOOLS_VOCAB " in
      *" $nm "*) ;;
      *) outside="$outside $nm" ;;
    esac
  done
  set +f
  if [ -n "$outside" ]; then
    echo "FAIL: the tools line names only the stride-codex vocabulary -- outside:$outside"
    fail=1
  else
    echo "ok: the tools line names only the stride-codex vocabulary"
  fi
fi

# --- W2634: frontmatter shape, keys and names (upstream W2286's subset) ------
# Ported from upstream without its description byte bound or its description
# trigger pins: those belong to the W2286 port. One allowance, as in the Copilot
# port: the tools key's JSON flow array, which the plain-value rule would refuse
# for its leading `[`, is let through because the exact pin above owns it.

frontmatter() { # $1=file -> the lines between the opening and closing --- fences
  awk 'NR == 1 { if ($0 != "---") exit 1; next } /^---$/ { c = 1; exit } { print } END { exit !c }' "$1"
}
check_frontmatter() { # $1=file $2=label $3=required keys, space-separated
  local fm bad k
  if ! fm="$(frontmatter "$1")"; then
    echo "FAIL: $2 frontmatter -- no closing --- fence"; fail=1; return
  fi
  # Each line is a top-level `key: value`, a `key: |` block, or a line indented
  # under that block; a plain value must not hold ': ', ' #' or a leading YAML
  # indicator, which would change or break how YAML reads it.
  bad="$(printf '%s\n' "$fm" | awk '
    /^[a-z_]+: *\|$/ { blk = 1; if (seen[$1]++) print "duplicate key " $1; next }
    blk && /^  [^ ]/ { next }
    /^[a-z_]+:( |$)/ { blk = 0; if (seen[$1]++) print "duplicate key " $1
      v = $0; sub(/^[a-z_]+: */, "", v)
      if ($1 == "tools:" && v ~ /^\[.*\]$/) next
      if (v ~ /: / || v ~ / #/ || v ~ /^[][{}>|*&!%@?:#-]/) print "plain value YAML would misread: " $1
      next }
    { print "not a key or block line: " substr($0, 1, 40) }')"
  if [ -n "$bad" ]; then
    echo "FAIL: $2 frontmatter -- $(printf '%s' "$bad" | tr '\n' ' ')"; fail=1
  else
    echo "ok: $2 frontmatter has the shape YAML reads"
  fi
  for k in $3; do
    if printf '%s\n' "$fm" | grep -q "^$k:"; then
      echo "ok: $2 frontmatter has $k"
    else
      echo "FAIL: $2 frontmatter -- missing key $k"; fail=1
    fi
  done
}
fm_line() { # $1=file $2=label $3=exact frontmatter line
  if frontmatter "$1" | grep -qxF -- "$3"; then
    echo "ok: $2"
  else
    echo "FAIL: $2 -- no frontmatter line: $3"; fail=1
  fi
}
check_frontmatter "$AGENT" "the agent" "name description tools"
check_frontmatter "$CMD" "the command skill" "name description"
check_frontmatter "$ESS" "the essentials skill" "name description"
fm_line "$AGENT" "the agent keeps the name security-reviewer" 'name: security-reviewer'
fm_line "$CMD" "the command skill keeps the name stride-security-review" 'name: stride-security-review'
fm_line "$ESS" "the essentials skill keeps the name security-review-essentials" 'name: security-review-essentials'

# --- Self-tests: a break-it per pin ------------------------------------------
# Each case copies the checked files and this script into a temporary
# directory, plants one broken shape in the copy, and runs the copy's script as
# a child. CHECK_AGENT_CONTRACT_CHILD stops the child running the self-tests
# again. Skipped when a file path is given, so a run against a copy reports on
# that copy alone. The real files are only ever read.

if [ -z "${CHECK_AGENT_CONTRACT_CHILD:-}" ] && [ "$#" -eq 0 ]; then
  TMP="$(mktemp -d "${TMPDIR:-/tmp}/check-agent-contract.XXXXXX")" || {
    echo "FAIL: self-tests could not create a temporary directory"; exit 1; }
  trap 'chmod -R u+rw "$TMP" 2>/dev/null; rm -rf "$TMP"' EXIT
  trap 'exit 1' HUP INT TERM

  A=agents/security-reviewer.md
  C=skills/stride-security-review/SKILL.md
  E=skills/security-review-essentials/SKILL.md
  mkdir -p "$TMP/base/lib" "$TMP/base/agents" \
    "$TMP/base/skills/stride-security-review" "$TMP/base/skills/security-review-essentials"
  cp "$SELF" "$TMP/base/lib/check_agent_contract.sh"
  cp "$AGENT" "$TMP/base/$A"
  cp "$CMD" "$TMP/base/$C"
  cp "$ESS" "$TMP/base/$E"
  cp "$README" "$TMP/base/README.md"
  cp "$AGENTS_MD" "$TMP/base/AGENTS.md"

  n=0
  mk() { # sets t to a fresh copy of the base tree (no subshell, so n advances)
    n=$((n + 1)); t="$TMP/t$n"; cp -R "$TMP/base" "$t"
  }
  ed_awk() { # $1=file $2=awk program [awk args...] -- rewrite the file in place
    local f="$1"; shift
    awk "$@" "$f" > "$f.new" && mv "$f.new" "$f"
  }
  # expect <label> <want-exit> <needle> <tree> [script args...]
  expect() {
    local label="$1" want="$2" needle="$3" tree="$4" out rc
    shift 4
    out="$(CHECK_AGENT_CONTRACT_CHILD=1 bash "$tree/lib/check_agent_contract.sh" "$@" 2>&1)"; rc=$?
    if [ "$rc" -ne "$want" ]; then
      echo "FAIL: self-test: $label -- exit $rc, wanted $want"; fail=1
    elif ! printf '%s\n' "$out" | grep -qF -- "$needle"; then
      echo "FAIL: self-test: $label -- output lacks: $needle"; fail=1
    else
      echo "ok: self-test: $label"
    fi
  }

  expect "the shipped tree passes every pin" 0 "agent contract: all pins present" "$TMP/base"

  # Guards.
  mk; rm "$t/$A"
  expect "a missing agent file exits non-zero with a message" 1 "FAIL: agent file not found" "$t"
  mk; : > "$t/$A"
  expect "an empty agent file exits non-zero with a message" 1 "FAIL: agent file is empty" "$t"
  mk; chmod 000 "$t/$A"
  if [ -r "$t/$A" ]; then
    echo "ok: self-test: an unreadable agent file exits non-zero with a message -- skipped (permissions not enforced for this user)"
  else
    expect "an unreadable agent file exits non-zero with a message" 1 "FAIL: agent file is not readable" "$t"
  fi
  chmod 600 "$t/$A"
  mk; rm "$t/$C"
  expect "a missing command skill exits non-zero with a message" 1 "FAIL: command skill file not found" "$t"
  mk; rm "$t/$E"
  expect "a missing essentials skill exits non-zero with a message" 1 "FAIL: essentials skill file not found" "$t"
  mk; rm "$t/README.md"
  expect "a missing README exits non-zero with a message" 1 "FAIL: README file not found" "$t"
  mk; rm "$t/AGENTS.md"
  expect "a missing AGENTS.md exits non-zero with a message" 1 "FAIL: AGENTS.md file not found" "$t"

  # Claude Code tool names, planted in each checked file.
  mk; printf 'Use the `%s` tool.\n' Bash >> "$t/$A"
  expect "a backticked Claude Code tool in the agent fails" 1 \
    "FAIL: the agent names no Claude Code tool" "$t"
  mk; printf 'Search with "%s".\n' Grep >> "$t/$C"
  expect "a double-quoted Claude Code tool in the command skill fails" 1 \
    "FAIL: the command skill names no Claude Code tool" "$t"
  mk; printf "List files with '%s'.\n" Glob >> "$t/$E"
  expect "a single-quoted Claude Code tool in the essentials skill fails" 1 \
    "FAIL: the essentials skill names no Claude Code tool" "$t"
  mk; printf 'The agent holds `%s`.\n' Read >> "$t/README.md"
  expect "a Claude Code tool in the README fails" 1 \
    "FAIL: the README names no Claude Code tool" "$t"
  mk; printf 'Read the diff, then Bash it.\n' >> "$t/$A"
  expect "the bare English word in prose passes" 0 "agent contract: all pins present" "$t"
  # Every name cc_tools lists, planted one at a time. The list is spelled out
  # here rather than read from cc_tools, so a typo there fails a case here.
  for nm in Read Grep Glob Bash Edit Write MultiEdit NotebookEdit WebFetch WebSearch Task Agent; do
    mk; printf 'Call the `%s` tool.\n' "$nm" >> "$t/$A"
    expect "the Claude Code tool $nm in the agent fails" 1 \
      "FAIL: the agent names no Claude Code tool" "$t"
  done

  # Claude Code mechanisms, planted in each checked file.
  mk; printf 'Run %s/lib/x.sh.\n' '${CLAUDE_PLUGIN_ROOT}' >> "$t/$A"
  expect "the plugin-root variable in the agent fails" 1 \
    "FAIL: the agent uses no Claude Code mechanism" "$t"
  mk; printf 'Run claude -p "review".\n' >> "$t/$C"
  expect "a headless claude run in the command skill fails" 1 \
    "FAIL: the command skill uses no Claude Code mechanism" "$t"
  mk; printf 'Load it with --plugin-dir.\n' >> "$t/$E"
  expect "the plugin-directory flag in the essentials skill fails" 1 \
    "FAIL: the essentials skill uses no Claude Code mechanism" "$t"
  mk; printf 'Dispatch it with the Agent tool.\n' >> "$t/README.md"
  expect "the agent dispatch tool in the README fails" 1 \
    "FAIL: the README uses no Claude Code mechanism" "$t"
  mk; printf 'Pass subagent_type to it.\n' >> "$t/AGENTS.md"
  expect "the dispatch parameter in AGENTS.md fails" 1 \
    "FAIL: AGENTS.md uses no Claude Code mechanism" "$t"
  mk; printf 'Install it under ~/.claude/agents.\n' >> "$t/AGENTS.md"
  expect "the Claude Code config directory in AGENTS.md fails" 1 \
    "FAIL: AGENTS.md uses no Claude Code mechanism" "$t"
  mk; printf 'Then the agent tool runs it.\n' >> "$t/README.md"
  expect "a lower-case \"the agent tool\" in prose passes" 0 "agent contract: all pins present" "$t"

  # The tools line.
  mk; ed_awk "$t/$A" '/^tools:/ && !d { sub(/"shell"/, "\"Bash\""); d = 1 } { print }'
  expect "a tool outside the vocabulary fails and is named" 1 \
    "FAIL: the tools line names only the stride-codex vocabulary -- outside: Bash" "$t"
  mk; ed_awk "$t/$A" '/^tools:/ && !d { sub(/"shell"/, "\"Bash\""); d = 1 } { print }'
  expect "a renamed tool also fails the exact tools line" 1 "FAIL: the frontmatter tools line -- got:" "$t"
  mk; ed_awk "$t/$A" '/^tools:/ && !d { sub(/\]$/, ", \"edit\"]"); d = 1 } { print }'
  expect "an added edit tool fails the tools line" 1 "FAIL: the frontmatter tools line -- got:" "$t"
  mk; ed_awk "$t/$A" '/^tools:/ && !d { sub(/ "glob",/, ""); d = 1 } { print }'
  expect "a dropped glob fails the tools line" 1 "FAIL: the frontmatter tools line -- got:" "$t"
  mk; ed_awk "$t/$A" '/^tools:/ && !d { $0 = "tools: [\"search\", \"read\", \"glob\", \"shell\"]"; d = 1 } { print }'
  expect "a reordered tools line fails" 1 "FAIL: the frontmatter tools line -- got:" "$t"
  mk; ed_awk "$t/$A" '/^tools:/ && !d { gsub(/, /, ","); d = 1 } { print }'
  expect "a respaced tools line fails" 1 "FAIL: the frontmatter tools line -- got:" "$t"
  mk; ed_awk "$t/$A" '/^tools:/ && !d { print "tools:"; print "  - read"; print "  - search"; print "  - glob"; print "  - shell"; d = 1; next } { print }'
  expect "a YAML block-list tools key fails the vocabulary check" 1 \
    "-- no names on a one-line JSON array" "$t"
  mk; ed_awk "$t/$A" '/^tools:/ && !d { held = $0; d = 1; next } { print } END { print held }'
  expect "a tools line outside the frontmatter fails" 1 "FAIL: the agent frontmatter -- missing key tools" "$t"
  mk; ed_awk "$t/$A" '/^tools:/ && !d { print; print; d = 1; next } { print }'
  expect "a tools line that matches twice fails as a duplicate key" 1 "duplicate key tools:" "$t"
  mk; ed_awk "$t/$A" '/^tools:/ && !d { print; print; d = 1; next } { print }'
  expect "a tools line that matches twice fails the exact pin" 1 "FAIL: the frontmatter tools line -- got:" "$t"

  # Frontmatter keys, names and shape, per file.
  mk; ed_awk "$t/$A" 'NR > 1 && /^---$/ { e = 1 } !e && /^description: *\|$/ { skip = 1; next } skip && /^  / { next } { skip = 0; print }'
  expect "deleting the agent description fails" 1 "FAIL: the agent frontmatter -- missing key description" "$t"
  mk; ed_awk "$t/$A" '/^name:/ && !d { d = 1; next } { print }'
  expect "deleting the agent name fails" 1 "FAIL: the agent frontmatter -- missing key name" "$t"
  mk; ed_awk "$t/$C" '/^description:/ && !d { d = 1; next } { print }'
  expect "deleting the command skill description fails" 1 \
    "FAIL: the command skill frontmatter -- missing key description" "$t"
  mk; ed_awk "$t/$C" '/^name:/ && !d { d = 1; next } { print }'
  expect "deleting the command skill name fails" 1 "FAIL: the command skill frontmatter -- missing key name" "$t"
  mk; ed_awk "$t/$E" '/^description:/ && !d { d = 1; next } { print }'
  expect "deleting the essentials skill description fails" 1 \
    "FAIL: the essentials skill frontmatter -- missing key description" "$t"
  mk; ed_awk "$t/$E" '/^name:/ && !d { d = 1; next } { print }'
  expect "deleting the essentials skill name fails" 1 \
    "FAIL: the essentials skill frontmatter -- missing key name" "$t"
  mk; ed_awk "$t/$A" '/^name:/ && !d { $0 = $0 "-x"; d = 1 } { print }'
  expect "renaming the agent fails" 1 "FAIL: the agent keeps the name security-reviewer -- no frontmatter line" "$t"
  mk; ed_awk "$t/$C" '/^name:/ && !d { $0 = $0 "-x"; d = 1 } { print }'
  expect "renaming the command skill fails" 1 \
    "FAIL: the command skill keeps the name stride-security-review -- no frontmatter line" "$t"
  mk; ed_awk "$t/$E" '/^name:/ && !d { $0 = $0 "-x"; d = 1 } { print }'
  expect "renaming the essentials skill fails" 1 \
    "FAIL: the essentials skill keeps the name security-review-essentials -- no frontmatter line" "$t"
  mk; ed_awk "$t/$A" 'NR > 1 && /^---$/ && !d { d = 1; next } { print }'
  expect "an agent frontmatter with no closing fence fails" 1 "FAIL: the agent frontmatter -- no closing --- fence" "$t"
  mk; ed_awk "$t/$A" 'NR == 2 { print "stray line" } { print }'
  expect "a stray line in the agent frontmatter fails" 1 \
    "FAIL: the agent frontmatter -- not a key or block line: stray line" "$t"
  mk; ed_awk "$t/$C" '/^description:/ && !d { sub(/^description: /, "description: [planted] "); d = 1 } { print }'
  expect "a leading [ is allowed only on the tools key" 1 \
    "FAIL: the command skill frontmatter -- plain value YAML would misread: description:" "$t"
  mk; ed_awk "$t/$E" '/^description:/ && !d { $0 = $0 " Note: planted."; d = 1 } { print }'
  expect "an essentials skill description YAML would misread fails" 1 \
    "FAIL: the essentials skill frontmatter -- plain value YAML would misread: description:" "$t"
  mk; ed_awk "$t/$A" '/^name:/ && !d { print; print; d = 1; next } { print }'
  expect "a duplicated agent name line fails" 1 "FAIL: the agent frontmatter -- duplicate key name:" "$t"

  # Argument override: a run against a given file reports on that file.
  mk; ed_awk "$t/$A" '/^tools:/ && !d { sub(/\]$/, ", \"edit\"]"); d = 1 } { print }'
  expect "a broken agent passed as an argument fails" 1 "FAIL: the frontmatter tools line -- got:" \
    "$TMP/base" "$t/$A"
fi

if [ "$fail" -ne 0 ]; then
  echo "agent contract: FAILED"
  exit 1
fi
echo "agent contract: all pins present"
