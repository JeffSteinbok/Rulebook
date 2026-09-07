#!/usr/bin/env bash
# Writes the App Store Connect API key JSON that fastlane's deliver reads.
# Same key and defaults as testflight.sh; override with the environment.
#
# The output names the .p8 by path rather than embedding it, so the private
# key never lands in the repo. The JSON is gitignored regardless.
set -euo pipefail

ASC_KEY_ID="${ASC_KEY_ID:-9L496DA23R}"
ASC_ISSUER_ID="${ASC_ISSUER_ID:-517f64b1-e6f9-4185-be4e-ef0faa859ae1}"
ASC_KEY_PATH="${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8}"

if [ ! -f "$ASC_KEY_PATH" ]; then
  echo "No .p8 at $ASC_KEY_PATH — set ASC_KEY_PATH." >&2
  exit 1
fi

OUT="$(cd "$(dirname "$0")/.." && pwd)/fastlane/asc_api_key.json"
cat > "$OUT" <<JSON
{
  "key_id": "$ASC_KEY_ID",
  "issuer_id": "$ASC_ISSUER_ID",
  "key_filepath": "$ASC_KEY_PATH",
  "in_house": false
}
JSON
chmod 600 "$OUT"
echo "Wrote $OUT"
