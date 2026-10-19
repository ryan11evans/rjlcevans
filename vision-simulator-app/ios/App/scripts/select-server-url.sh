#!/bin/sh
# Point the bundled Capacitor config at staging only for the Staging
# configuration (the "App Staging" scheme). Debug and Release always keep
# the production URL baked into capacitor.config.json, so an App Store
# archive cannot accidentally load the staging site.
set -eu

PROD="https://rjlcevans.com/vision-simulator/"
STAGING_DEFAULT="https://rjlcevans.com/vision-simulator-staging/"
CONFIG="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/capacitor.config.json"
CONFIGURATION="${CONFIGURATION:-}"
REQUESTED="${VISION_SIM_SERVER_URL:-}"

if [ "$CONFIGURATION" != "Staging" ]; then
  if [ -n "$REQUESTED" ] && [ "$REQUESTED" != "$PROD" ]; then
    echo "error: $CONFIGURATION would load $REQUESTED. Only the Staging configuration may leave production." >&2
    exit 1
  fi
  exit 0
fi

URL="$REQUESTED"
if [ -z "$URL" ]; then
  URL="$STAGING_DEFAULT"
fi

case "$URL" in
  https://*) ;;
  *)
    echo "error: refusing non-https server URL: $URL" >&2
    exit 1
    ;;
esac

if [ ! -f "$CONFIG" ]; then
  echo "warning: capacitor.config.json was not in the app bundle ($CONFIG). Run npx cap sync first." >&2
  exit 0
fi

if [ "$URL" = "$PROD" ]; then
  exit 0
fi

# The committed config contains the production URL exactly once.
if ! grep -q "$PROD" "$CONFIG"; then
  echo "error: $CONFIG does not contain the production URL; refusing to guess." >&2
  exit 1
fi

tmp="${CONFIG}.tmp"
sed "s#${PROD}#${URL}#g" "$CONFIG" > "$tmp"
mv "$tmp" "$CONFIG"
echo "Vision Simulator server.url -> $URL"
