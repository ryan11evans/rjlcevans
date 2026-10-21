#!/bin/sh
# Copy the current vision-simulator/ web app to vision-simulator-staging/.
#
# GitHub Pages publishes the whole main branch. /vision-simulator/ is what
# every installed app loads. /vision-simulator-staging/ is a separate path,
# so publishing this copy does not change the live app until you copy it
# back over vision-simulator/. Run this from the repo root.
set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/vision-simulator"
DEST="$ROOT/vision-simulator-staging"

if [ ! -f "$SRC/index.html" ] || [ ! -f "$SRC/shell-detect.js" ]; then
  echo "error: $SRC is missing index.html or shell-detect.js" >&2
  exit 1
fi

mkdir -p "$DEST"
# Keep screenshot captures and the generator out of the staging site.
# They are not part of the app the WebView loads.
tar -C "$SRC" \
  --exclude='app-store-screenshots' \
  --exclude='screens' \
  --exclude='test' \
  --exclude='capture-screens.js' \
  --exclude='capture-screens-ipad.js' \
  --exclude='export-ipad-screenshots.js' \
  --exclude='screenshot-gen.html' \
  --exclude='iphone-screenshots.html' \
  --exclude='ipad-screenshots.html' \
  -cf - . | tar -C "$DEST" -xf -

echo "Staged $SRC -> $DEST"
echo "Next: commit only vision-simulator-staging/."
echo "A push of that folder to main publishes /vision-simulator-staging/ and does not change the live app."
