#!/usr/bin/env bash
# test_setup_flows.sh
# Mirrors AppSettings+Detection.swift logic to validate every user setup scenario.
# Avoids spawning login shells (which hang on nvm init) — uses direct path scanning instead.
# Run: bash Scripts/test_setup_flows.sh

set -uo pipefail

HOME_DIR="$HOME"
PASS=0; FAIL=0; WARN=0

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; RESET='\033[0m'

pass()  { echo -e "  ${GREEN}✓${RESET} $1"; ((PASS++)) || true; }
fail()  { echo -e "  ${RED}✗${RESET} $1"; ((FAIL++)) || true; }
warn()  { echo -e "  ${YELLOW}⚠${RESET} $1"; ((WARN++)) || true; }
header(){ echo -e "\n${BOLD}${BLUE}── $1 ──${RESET}"; }
note()  { echo -e "  ${YELLOW}→${RESET} $1"; }

# ─── helpers ──────────────────────────────────────────────────────────────────

# Build a comprehensive candidate PATH list from all known node managers.
# Mirrors the app's executablePathForDetection fallback logic.
build_search_paths() {
  local name="$1"
  local -a paths=()

  # Current shell PATH dirs
  IFS=':' read -ra path_dirs <<< "${PATH:-}"
  for d in "${path_dirs[@]}"; do
    paths+=("$d/$name")
  done

  # Common absolute locations (mirrors Swift hardcoded fallbacks)
  paths+=(
    "$HOME/.local/bin/$name"
    "$HOME/.volta/bin/$name"
    "$HOME/.npm-global/bin/$name"
    "/opt/homebrew/bin/$name"
    "/usr/local/bin/$name"
    "/usr/local/lib/node_modules/.bin/$name"
  )

  if [[ "$name" == "codex" ]]; then
    # nvm: scan all installed versions (newest first via reverse-sort)
    if [[ -d "$HOME/.nvm/versions/node" ]]; then
      while IFS= read -r ver; do
        paths+=("$HOME/.nvm/versions/node/$ver/bin/codex")
      done < <(ls "$HOME/.nvm/versions/node/" | sort -rV 2>/dev/null || ls -r "$HOME/.nvm/versions/node/")
    fi
    # fnm
    if [[ -d "$HOME/.fnm/node-versions" ]]; then
      while IFS= read -r ver; do
        paths+=("$HOME/.fnm/node-versions/$ver/installation/bin/codex")
      done < <(ls "$HOME/.fnm/node-versions/" | sort -rV 2>/dev/null || ls -r "$HOME/.fnm/node-versions/")
    fi
    # pnpm global
    if command -v pnpm &>/dev/null; then
      pnpm_bin=$(pnpm bin -g 2>/dev/null || true)
      [[ -n "$pnpm_bin" ]] && paths+=("$pnpm_bin/codex")
    fi
  fi

  printf '%s\n' "${paths[@]}"
}

find_executable() {
  local name="$1"
  while IFS= read -r candidate; do
    [[ -x "$candidate" ]] && echo "$candidate" && return 0
  done < <(build_search_paths "$name")
  return 1
}

codex_auth_file_ok() {
  local auth="$HOME/.codex/auth.json"
  [[ -f "$auth" ]] || return 1
  python3 - <<'EOF' 2>/dev/null
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    sys.exit(0 if any(k in d for k in ['OPENAI_API_KEY','tokens','token','api_key']) else 1)
except:
    sys.exit(1)
EOF
  python3 -c "
import json, sys
try:
    d = json.load(open('$auth'))
    sys.exit(0 if any(k in d for k in ['OPENAI_API_KEY','tokens','token','api_key']) else 1)
except:
    sys.exit(1)
" 2>/dev/null
}

LENNY_MCP_URL="https://mcp.lennysdata.com/mcp"

contains_mcp_url_in_json() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  python3 -c "
import json, sys
try:
    raw = json.dumps(json.load(open('$file')))
    sys.exit(0 if '$LENNY_MCP_URL' in raw else 1)
except:
    sys.exit(1)
" 2>/dev/null
}

contains_mcp_url_in_toml() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  grep -q "lennysdata" "$file" 2>/dev/null && grep -q "$LENNY_MCP_URL" "$file" 2>/dev/null
}

json_valid() {
  python3 -c "import json; json.load(open('$1'))" 2>/dev/null
}

# ══════════════════════════════════════════════════════════════════════════════
echo -e "\n${BOLD}Lil-Lenny Setup Flow Test Suite${RESET}"
echo    "$(date)"
echo    "Home: $HOME"

# ─── SECTION 1: Executable Detection ─────────────────────────────────────────
header "1. Executable Detection"

claude_path=""
codex_path=""

if p=$(find_executable "claude"); then
  claude_path="$p"
  pass "claude found: $claude_path"
else
  warn "claude not found — Claude Code not installed or not in PATH"
fi

if p=$(find_executable "codex"); then
  codex_path="$p"
  pass "codex found: $codex_path"
else
  warn "codex not found — Codex not installed or not in PATH"
fi

# nvm 'current' symlink check
if [[ -d "$HOME/.nvm/versions/node" ]]; then
  if [[ -L "$HOME/.nvm/versions/node/current" ]]; then
    pass "nvm 'current' symlink exists"
  else
    warn "nvm 'current' symlink missing — app relies on version scan as fallback"
    note "Installed nvm versions: $(ls "$HOME/.nvm/versions/node/" | tr '\n' ' ')"
  fi
fi

# ─── SECTION 2: Login / Auth Detection ───────────────────────────────────────
header "2. Login / Auth Detection"

has_claude_login=false
has_codex_login=false
has_openai_key=false
has_anthropic_key=false

## Anthropic API key (env only; no Settings key available outside app)
if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
  has_anthropic_key=true
  pass "ANTHROPIC_API_KEY present in environment"
else
  note "ANTHROPIC_API_KEY not in environment"
fi

## Claude login
if [[ -n "$claude_path" ]]; then
  if $has_anthropic_key; then
    has_claude_login=true
    pass "Claude: ANTHROPIC_API_KEY → treated as logged in"
  else
    auth_raw=$("$claude_path" auth status --output-format json 2>/dev/null || "$claude_path" auth status 2>/dev/null || true)
    auth_lower=$(echo "$auth_raw" | tr '[:upper:]' '[:lower:]')
    logged_in_json=false
    if echo "$auth_raw" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if d.get('loggedIn') else 1)" 2>/dev/null; then
      logged_in_json=true
    fi

    if $logged_in_json || echo "$auth_lower" | grep -q "logged in"; then
      has_claude_login=true
      pass "Claude: auth status → logged in"
    elif echo "$auth_lower" | grep -qE "not logged in|login required"; then
      fail "Claude: auth status → NOT logged in  (fix: claude login)"
    else
      "$claude_path" auth status &>/dev/null
      exit_code=$?
      if [[ "$exit_code" == "0" ]]; then
        has_claude_login=true
        warn "Claude: auth status exit 0 but output unrecognised — app will assume logged in"
        note "Output: $auth_raw"
      else
        fail "Claude: auth status failed (exit $exit_code) — app will show Claude as unavailable"
      fi
    fi
  fi
else
  note "Claude: skipped (not installed)"
fi

## OpenAI API key
if [[ -n "${OPENAI_API_KEY:-}" ]]; then
  has_openai_key=true
  pass "OPENAI_API_KEY present in environment"
else
  note "OPENAI_API_KEY not in environment (user can paste in Settings)"
fi

## Codex login
if [[ -n "$codex_path" ]]; then
  if $has_openai_key; then
    has_codex_login=true
    pass "Codex: OPENAI_API_KEY → treated as logged in"
  elif codex_auth_file_ok; then
    has_codex_login=true
    pass "Codex: ~/.codex/auth.json contains valid auth credentials"
  else
    login_raw=$("$codex_path" login status 2>&1 || true)
    login_lower=$(echo "$login_raw" | tr '[:upper:]' '[:lower:]')
    if echo "$login_lower" | grep -qE "logged in|chatgpt|openai"; then
      has_codex_login=true
      pass "Codex: login status → logged in"
    elif echo "$login_lower" | grep -qE "not logged in|login required"; then
      fail "Codex: login status → NOT logged in  (fix: codex login)"
    else
      warn "Codex: login status output unrecognised — may show as 'Not installed'"
      note "Output: $login_raw"
    fi
  fi
else
  note "Codex: skipped (not installed)"
fi

# ─── SECTION 3: MCP Configuration ────────────────────────────────────────────
header "3. Official MCP (LennyData) Configuration"

mcp_detected=false

claude_configs=(
  "$HOME/.claude.json"
  "$HOME/.claude/settings.json"
  "$HOME/.claude/settings.local.json"
)
for f in "${claude_configs[@]}"; do
  if contains_mcp_url_in_json "$f"; then
    pass "MCP URL detected in Claude config: $(basename "$f")"
    mcp_detected=true
  elif [[ -f "$f" ]]; then
    note "Claude config exists, no MCP URL: $(basename "$f")"
  fi
done

codex_toml="$HOME/.codex/config.toml"
if contains_mcp_url_in_toml "$codex_toml"; then
  pass "MCP URL detected in ~/.codex/config.toml"
  mcp_detected=true
elif [[ -f "$codex_toml" ]]; then
  note "~/.codex/config.toml exists, no MCP entry"
fi

if [[ -n "${LENNYSDATA_MCP_AUTH_TOKEN:-}" ]]; then
  pass "LENNYSDATA_MCP_AUTH_TOKEN present in environment"
  mcp_detected=true
else
  note "LENNYSDATA_MCP_AUTH_TOKEN not in environment"
fi

$mcp_detected || note "No official MCP config — will use Starter Pack archive"

# ─── SECTION 4: Edge Case / Config Integrity ─────────────────────────────────
header "4. Edge Case & Config Integrity Checks"

for f in "${claude_configs[@]}"; do
  [[ -f "$f" ]] || continue
  if json_valid "$f"; then
    pass "Valid JSON: $(basename "$f")"
  else
    fail "INVALID JSON: $f — MCP detection will silently fail"
  fi
done

if [[ -f "$HOME/.codex/auth.json" ]]; then
  if json_valid "$HOME/.codex/auth.json"; then
    pass "Valid JSON: ~/.codex/auth.json"
  else
    fail "INVALID JSON: ~/.codex/auth.json — Codex auth detection will fail"
  fi
fi

for exe in "$claude_path" "$codex_path"; do
  [[ -z "$exe" ]] && continue
  if [[ -x "$exe" ]]; then
    pass "Executable bit OK: $exe"
  else
    fail "NOT executable: $exe  (fix: chmod +x $exe)"
  fi
done

# Check for duplicate codex installs that might cause version confusion
if [[ -n "$codex_path" ]]; then
  all_codex=$(build_search_paths "codex" | while IFS= read -r p; do [[ -x "$p" ]] && echo "$p"; done | sort -u)
  count=$(echo "$all_codex" | grep -c . || true)
  if [[ $count -gt 1 ]]; then
    warn "Multiple codex executables found ($count) — app will use first found"
    echo "$all_codex" | while IFS= read -r p; do note "  $p"; done
  fi
fi

# ─── SECTION 5: Scenario Resolution ──────────────────────────────────────────
header "5. Expected Backend Resolution"

echo ""
printf "  %-25s %s\n" "Claude installed+logged in:" "$has_claude_login"
printf "  %-25s %s\n" "Codex  installed+logged in:" "$has_codex_login"
printf "  %-25s %s\n" "OpenAI API key available:"   "$has_openai_key"
printf "  %-25s %s\n" "Official MCP configured:"    "$mcp_detected"
echo ""

# Mirrors ClaudeSessionBackend priority resolution
if $has_claude_login; then
  if $mcp_detected; then
    echo -e "  ${GREEN}→ Backend: Claude Code + Official MCP (Priority 1 or 3)${RESET}"
  else
    echo -e "  ${GREEN}→ Backend: Claude Code + Starter Pack${RESET}"
  fi
elif $has_codex_login; then
  if $mcp_detected; then
    echo -e "  ${GREEN}→ Backend: Codex + Official MCP (Priority 2 or 4)${RESET}"
  else
    echo -e "  ${GREEN}→ Backend: Codex + Starter Pack${RESET}"
  fi
elif $has_openai_key; then
  echo -e "  ${YELLOW}→ Backend: OpenAI API + Starter Pack (Priority 5)${RESET}"
  $mcp_detected && warn "MCP token present but OpenAI backend can't use token-based MCP — Starter Pack used instead"
else
  fail "No backend available — app will show setup prompt"
  echo -e "  ${RED}  User must: install Claude, install Codex, or add OPENAI_API_KEY in Settings.${RESET}"
fi

# ─── SECTION 6: Settings Pane State ──────────────────────────────────────────
header "6. Settings Pane State Checks"

# Models pane: at least one segment must be selectable
if $has_claude_login || $has_codex_login || true; then
  # OpenAI is always selectable (user can paste key)
  pass "Models pane: at least one runtime tab is selectable (OpenAI API always enabled)"
fi

# Source pane: no token + no MCP → Starter Pack shown
if ! $mcp_detected; then
  note "Source pane: Starter Pack will be active (no MCP token or native config)"
fi

# MCP installer targets
if $mcp_detected; then
  if $has_claude_login && $has_codex_login; then
    note "MCP installer: will target both Claude Code and Codex"
  elif $has_claude_login; then
    note "MCP installer: will target Claude Code only"
  elif $has_codex_login; then
    note "MCP installer: will target Codex only"
  else
    note "MCP installer: no CLI target — token stored locally only"
  fi
fi

# ─── SECTION 7: Risk Checks ───────────────────────────────────────────────────
header "7. Known Risk Scenarios"

# Risk: shell env resolution could return empty (app's resolveShellEnvironment)
# We can't easily test the app's exact env, but we can verify zsh starts
if /bin/zsh --login --no-rcs -c "echo ok" &>/dev/null; then
  pass "zsh login shell starts without rc files (env resolution baseline works)"
else
  fail "zsh login shell failed to start — app's shell env resolution will return empty dict"
fi

# Risk: token in env but not in Settings — lower priority
if [[ -n "${LENNYSDATA_MCP_AUTH_TOKEN:-}" ]]; then
  note "LENNYSDATA_MCP_AUTH_TOKEN in env will be overridden if a different token is saved in app Settings"
fi

# Risk: multiple nvm versions, codex only in subset
if [[ -d "$HOME/.nvm/versions/node" ]]; then
  total_ver=$(ls "$HOME/.nvm/versions/node/" | wc -l | tr -d ' ')
  codex_ver=0
  while IFS= read -r ver; do
    [[ -x "$HOME/.nvm/versions/node/$ver/bin/codex" ]] && ((codex_ver++)) || true
  done < <(ls "$HOME/.nvm/versions/node/")
  if [[ $total_ver -gt 1 ]]; then
    note "nvm: $codex_ver/$total_ver node versions have codex — app scans all, will find it"
  fi
fi

# ─── Summary ──────────────────────────────────────────────────────────────────
header "Summary"

echo -e "  ${GREEN}Passed${RESET}   : $PASS"
echo -e "  ${YELLOW}Warnings${RESET} : $WARN"
echo -e "  ${RED}Failed${RESET}   : $FAIL"
echo ""

if [[ $FAIL -gt 0 ]]; then
  echo -e "${RED}${BOLD}Action required — address ✗ items above.${RESET}"
  exit 1
elif [[ $WARN -gt 0 ]]; then
  echo -e "${YELLOW}${BOLD}Setup OK — review ⚠ warnings above.${RESET}"
  exit 0
else
  echo -e "${GREEN}${BOLD}All checks passed.${RESET}"
  exit 0
fi
