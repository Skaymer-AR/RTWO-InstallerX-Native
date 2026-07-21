#!/usr/bin/env bash
set -euo pipefail

UPSTREAM="${UPSTREAM:-https://github.com/wxxsfxyzm/InstallerX-Revived.git}"
COMMIT="${COMMIT:-5a63a9465129f547031fa8d1d7f3a945beeb732b}"
APP_ID="${APP_ID:-com.google.android.packageinstaller}"
WORKDIR="${WORKDIR:-$PWD/build/InstallerX-Revived}"

# InstallerX resolves Miuix snapshots from GitHub Packages. Its Gradle settings
# read GITHUB_ACTOR and GITHUB_TOKEN, while GitHub CLI workflows commonly expose
# the same token as GH_TOKEN. Bridge both names without printing the secret.
if [[ -z "${GITHUB_TOKEN:-}" && -n "${GH_TOKEN:-}" ]]; then
  export GITHUB_TOKEN="$GH_TOKEN"
fi

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "ERROR: GITHUB_TOKEN (or GH_TOKEN) is required to download Miuix dependencies from GitHub Packages." >&2
  exit 1
fi

if [[ -z "${GITHUB_ACTOR:-}" ]]; then
  echo "ERROR: GITHUB_ACTOR is required for GitHub Packages authentication." >&2
  exit 1
fi

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
