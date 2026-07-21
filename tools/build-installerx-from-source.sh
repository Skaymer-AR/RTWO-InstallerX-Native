#!/usr/bin/env bash
set -euo pipefail

UPSTREAM="${UPSTREAM:-https://github.com/wxxsfxyzm/InstallerX-Revived.git}"
COMMIT="${COMMIT:-5a63a9465129f547031fa8d1d7f3a945beeb732b}"
APP_ID="${APP_ID:-com.google.android.packageinstaller}"
WORKDIR="${WORKDIR:-$PWD/build/InstallerX-Revived}"

mkdir -p "$(dirname "$WORKDIR")"

if [[ ! -d "$WORKDIR/.git" ]]; then
  git clone "$UPSTREAM" "$WORKDIR"
fi

git -C "$WORKDIR" fetch --all --tags
git -C "$WORKDIR" checkout --detach "$COMMIT"

cd "$WORKDIR"

./gradlew :app:assembleOnlineUnstableRelease -PAPP_ID="$APP_ID"

echo
echo "Build complete. Locate the APK under:"
find app/build/outputs/apk -type f -name '*.apk' -print
