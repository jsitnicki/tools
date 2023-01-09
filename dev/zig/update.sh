#!/usr/bin/bash
#
# Update installed Zig to latest release from master
#

set -o errexit
set -o nounset
set -o pipefail

readonly DOWNLOAD_DIR="/tmp"
readonly INSTALL_DIR="$HOME/apps"

echo "Updating Zig..."

# Cache https://ziglang.org/download/index.json in memory
readonly ZIG_RELEASES_JSON=$(curl -s https://ziglang.org/download/index.json)

# Find out lastest Zig version
readonly ZIG_VERSION_LATEST=$(echo -n "$ZIG_RELEASES_JSON" | jq -r '.master.version')
echo -e "Latest:    $ZIG_VERSION_LATEST"

# Find out installed Zig version
readonly ZIG_VERSION_INSTALLED=$(zig version)
echo -e "Installed: $ZIG_VERSION_INSTALLED"

if [[ "$ZIG_VERSION_LATEST" == "$ZIG_VERSION_INSTALLED" ]]; then
  echo "Latest version is already installed. Nothing to do."
  exit 0
fi

echo "Installing $ZIG_VERSION_LATEST..."

readonly TARBALL_URL=$(echo -n "$ZIG_RELEASES_JSON" | jq -r '.master."x86_64-linux".tarball')

echo "Downloading $TARBALL_URL..."

if [[ ! "$TARBALL_URL" =~ ".tar.xz"$ ]]; then
  echo "Expected a .tar.xz file. Aborting."
  exit 1
fi

pushd "$DOWNLOAD_DIR"
curl -O "$TARBALL_URL"
popd


readonly TARBALL_FILE=$(basename "$TARBALL_URL")
readonly TARBALL_PATH="$DOWNLOAD_DIR/$TARBALL_FILE"

echo "Unpacking $TARBALL_FILE in $INSTALL_DIR..."

tar axf "$TARBALL_PATH" -C "$INSTALL_DIR"
rm "$TARBALL_PATH"

readonly TARBALL_EXT=".tar.xz"
readonly TARBALL_BASE=$(basename "$TARBALL_FILE" "$TARBALL_EXT")

readonly LINK_PATH="$INSTALL_DIR/zig"
readonly OLD_DIR=$(realpath "$LINK_PATH")
readonly NEW_DIR="$INSTALL_DIR/$TARBALL_BASE"

echo "Updating $LINK_PATH to $NEW_DIR..."

ln -sfn "$NEW_DIR" "$LINK_PATH"

echo "Cleaning up $OLD_DIR..."

rm -r "$OLD_DIR"
