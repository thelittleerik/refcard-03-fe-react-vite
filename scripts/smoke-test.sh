#!/usr/bin/env bash
# Prüft ein laufendes Frontend von aussen: Health, ausgelieferte Version, Startseite und JS-Bundle.
# Wird von der Pipeline nach jedem Deployment ausgeführt und funktioniert genauso gegen localhost.
#
#   ./scripts/smoke-test.sh <basis-url> [erwarteter-commit]
#   ./scripts/smoke-test.sh http://localhost:8081
set -euo pipefail

BASE_URL=${1:?Aufruf: smoke-test.sh <basis-url> [erwarteter-commit]}
BASE_URL=${BASE_URL%/}
EXPECTED_COMMIT=${2:-}
ATTEMPTS=${SMOKE_ATTEMPTS:-20}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fail() {
  echo "::error title=Smoke-Test fehlgeschlagen::$*"
  exit 1
}

# Schreibt den Body nach $WORK/body und gibt nur den HTTP-Status aus ("000", wenn keine Verbindung zustande kommt).
request() {
  curl -s -o "$WORK/body" -w '%{http_code}' --max-time 10 "$@" || true
}

echo "1/4 Health: $BASE_URL/healthz"
for ((i = 1; i <= ATTEMPTS; i++)); do
  status=$(request "$BASE_URL/healthz")
  [[ "$status" == "200" ]] && break
  (( i < ATTEMPTS )) || fail "/healthz antwortet nach $ATTEMPTS Versuchen mit HTTP $status statt 200."
  sleep 5
done
echo "    ok"

echo "2/4 Version: $BASE_URL/version.json"
for ((i = 1; i <= ATTEMPTS; i++)); do
  status=$(request "$BASE_URL/version.json")
  commit=$(jq -r '.commit // empty' "$WORK/body" 2>/dev/null || true)
  version=$(jq -r '.version // empty' "$WORK/body" 2>/dev/null || true)
  if [[ "$status" == "200" && ( -z "$EXPECTED_COMMIT" || "$commit" == "$EXPECTED_COMMIT" ) ]]; then
    break
  fi
  (( i < ATTEMPTS )) || fail "Es läuft nicht der erwartete Stand. Erwartet Commit $EXPECTED_COMMIT, ausgeliefert wird '$commit' (HTTP $status). Das Deployment wurde vermutlich zurückgerollt - ECS-Service-Events prüfen."
  sleep 5
done
echo "    Version $version (Commit $commit)"

echo "3/4 Startseite: $BASE_URL/"
status=$(request "$BASE_URL/")
[[ "$status" == "200" ]] || fail "Die Startseite antwortet mit HTTP $status statt 200."
grep -q '<div id="root">' "$WORK/body" || fail "Die Startseite enthält kein React-Root-Element - es wird nicht der Vite-Build ausgeliefert."
bundle=$(grep -o '/assets/[^"]*\.js' "$WORK/body" | head -n 1 || true)
[[ -n "$bundle" ]] || fail "Die Startseite referenziert kein JS-Bundle unter /assets."
echo "    ok, Bundle $bundle"

echo "4/4 JS-Bundle: $BASE_URL$bundle"
status=$(request "$BASE_URL$bundle")
[[ "$status" == "200" ]] || fail "Das JS-Bundle $bundle antwortet mit HTTP $status statt 200."
echo "    ok"

# Das Backend wird unabhängig deployt. Ist es nicht erreichbar, ist das kein Fehler dieses Deployments -
# aber ein Hinweis, den man nicht übersehen soll.
# Der Status allein genügt nicht: ohne Backend-Route beantwortet der SPA-Fallback /v1/trips mit index.html und 200.
status=$(request "$BASE_URL/v1/trips")
if [[ "$status" == "204" ]] || { [[ "$status" == "200" ]] && jq -e 'type == "array"' "$WORK/body" >/dev/null 2>&1; }; then
  echo "Backend über dieselbe Adresse erreichbar (/v1/trips -> HTTP $status)."
else
  echo "::warning title=Backend nicht erreichbar::/v1/trips liefert keine Trip-Liste (HTTP $status). Das Frontend ist deployt, zeigt aber keine Daten, solange das Backend nicht unter dieser Adresse läuft."
fi

echo "Smoke-Test bestanden."
