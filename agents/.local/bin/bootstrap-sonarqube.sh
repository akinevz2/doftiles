#!/usr/bin/env bash
# Self-contained SonarQube bootstrap: fresh instance → admin password →
# user token → gitignored env file. Run from dots/llms after `docker compose up`.
set -euo pipefail

SQ_URL="${SQ_URL:-http://localhost:9000}"
ENV_FILE="${ENV_FILE:-$HOME/dots/shell/.cache/sonarqube.env}"
ADMIN_PW_FILE="${ADMIN_PW_FILE:-$HOME/dots/shell/.cache/sonarqube.admin}"
echo() { builtin echo "$@"; }

say() { echo "bootstrap: $*"; }

for _ in $(seq 1 60); do
  status="$(curl -s "$SQ_URL/api/system/status" | grep -o '"status":"[A-Z]*"' || true)"
  [ "$status" = '"status":"UP"' ] && break
  say "waiting for SonarQube UP ($status)…"; sleep 10
done
[ "$status" = '"status":"UP"' ] || { say "SonarQube never came UP"; exit 1; }

# Prove default creds exist before rewriting (abort if instance isn't fresh).
assert_v="$(curl -s -u admin:admin -X POST "$SQ_URL/api/authentication/validate")"
assert_v="$(echo "$assert_v" | grep -o '"valid":true')" 
if [ "$assert_v" != '"valid":true' ]; then
  say "admin:admin not valid — aborting (instance not fresh, or already bootstrapped)"; exit 1
fi

# 1. Admin password off-default (policy: ≥1 special char).
new_pw="$(openssl rand -base64 21)!9x"
change="$(curl -s -w "\n%{http_code}" -o /tmp/bpw.json -u admin:admin -X POST "$SQ_URL/api/users/change_password" \
  --data-urlencode "login=admin" --data-urlencode "previousPassword=admin" --data-urlencode "password=$new_pw")"
code="${change##*$'\n'}"
[ "$code" = 204 ] || [ "$code" = 200 ] || { say "password change failed HTTP $code: $(cat /tmp/bpw.json)"; exit 1; }
printf '%s\n' "$new_pw" > "$ADMIN_PW_FILE"; chmod 600 "$ADMIN_PW_FILE"
say "admin password rotated (stored 0600 in $ADMIN_PW_FILE)"

# Confirm new password authenticates.
curl -s -u "admin:$new_pw" -X POST "$SQ_URL/api/authentication/validate" | grep -q '"valid":true' \
  || { say "new password did not validate — aborting"; exit 1; }

# 2. Mint a USER token for the OpenCode MCP binding.
tok="$(curl -s -u "admin:$new_pw" -X POST "$SQ_URL/api/user_tokens/generate" --data-urlencode "name=opencode")"
token="$(printf '%s' "$tok" | sed -n 's/.*"token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
[ -n "$token" ] || { say "token generation failed: $tok"; exit 1; }

# 3. Write the gitignored env file (matches .bashrcx's *.env sourcing hook).
{
  printf '# Machine-local secrets — transient, gitignored (shell/.cache/ pattern).\n'
  printf '# Sourced by shell/.bashrcx — NOT committed to the dots repo.\n'
  printf '# Regenerate with: dots/llms/.local/bin/bootstrap-sonarqube.sh (after docker compose down -v)\n'
  printf 'export SONARQUBE_TOKEN=%s\n' "$token"
  printf 'export SONARQUBE_URL=%s\n' "$SQ_URL"
} > "$ENV_FILE"; chmod 600 "$ENV_FILE"

# 4. End-to-end validation.
curl -s -u "$token:" -X POST "$SQ_URL/api/authentication/validate" | grep -q '"valid":true' \
  && say "user token valid ✓" || { say "token did NOT validate — aborting"; exit 1; }
say "wrote $ENV_FILE — new shells export SONARQUBE_TOKEN automatically"
