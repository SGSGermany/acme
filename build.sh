#!/bin/bash
# acme
# A container to issue and renew Let's Encrypt SSL certificates using acme-tiny.
#
# Copyright (c) 2021  SGS Serious Gaming & Simulations GmbH
#
# This work is licensed under the terms of the MIT license.
# For a copy, see LICENSE file or <https://opensource.org/licenses/MIT>.
#
# SPDX-License-Identifier: MIT
# License-Filename: LICENSE

set -eu -o pipefail
export LC_ALL=C

[ -v CI_TOOLS ] && [ "$CI_TOOLS" == "SGSGermany" ] \
    || { echo "Invalid build environment: Environment variable 'CI_TOOLS' not set or invalid" >&2; exit 1; }

[ -v CI_TOOLS_PATH ] && [ -d "$CI_TOOLS_PATH" ] \
    || { echo "Invalid build environment: Environment variable 'CI_TOOLS_PATH' not set or invalid" >&2; exit 1; }

source "$CI_TOOLS_PATH/helper/common.sh.inc"
source "$CI_TOOLS_PATH/helper/container.sh.inc"
source "$CI_TOOLS_PATH/helper/container-alpine.sh.inc"
source "$CI_TOOLS_PATH/helper/git.sh.inc"

BUILD_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$BUILD_DIR/container.env"

readarray -t -d' ' TAGS < <(printf '%s' "$TAGS")

echo + "CONTAINER=\"\$(buildah from $(quote "$BASE_IMAGE"))\"" >&2
CONTAINER="$(buildah from "$BASE_IMAGE")"

echo + "MOUNT=\"\$(buildah mount $(quote "$CONTAINER"))\"" >&2
MOUNT="$(buildah mount "$CONTAINER")"

echo + "rm …/etc/crontabs/root" >&2
rm "$MOUNT/etc/crontabs/root"

echo + "rsync -v -rl --exclude .gitignore ./src/ …/" >&2
rsync -v -rl --exclude '.gitignore' "$BUILD_DIR/src/" "$MOUNT/"

pkg_install "$CONTAINER" --virtual .acme-run-deps \
    python3 \
    openssl \
    bash

user_add "$CONTAINER" acme 65536 "/var/local/acme"

# @diafygi's acme-tiny <https://github.com/diafygi/acme-tiny>
git_clone "$ACME_TINY_GIT_REPO" "$ACME_TINY_GIT_REF" \
    "$MOUNT/usr/src/acme-tiny" "…/usr/src/acme-tiny"

echo + "ACME_TINY_HASH=\"\$(git -C …/usr/src/acme-tiny rev-parse HEAD)\"" >&2
ACME_TINY_HASH="$(git -C "$MOUNT/usr/src/acme-tiny" rev-parse HEAD)"

echo + "[ \"\$ACME_TINY_GIT_COMMIT\" == \"\$ACME_TINY_HASH\" ]" >&2
if [ "$ACME_TINY_GIT_COMMIT" != "$ACME_TINY_HASH" ]; then
    echo "Failed to verify source code integrity of @diafygi's acme-tiny v$ACME_TINY_VERSION:" \
        "Expecting Git commit '$ACME_TINY_GIT_COMMIT', got '$ACME_TINY_HASH'" >&2
    exit 1
fi

echo + "cp …/usr/src/acme-tiny/acme_tiny.py …/usr/local/bin/acme-tiny" >&2
cp "$MOUNT/usr/src/acme-tiny/acme_tiny.py" "$MOUNT/usr/local/bin/acme-tiny"

cmd buildah run "$CONTAINER" -- \
    chmod 755 "/usr/local/bin/acme-tiny"

echo + "rm -rf …/usr/src/acme-tiny" >&2
rm -rf "$MOUNT/usr/src/acme-tiny"

# @PhrozenByte's acme management scripts <https://github.com/PhrozenByte/acme>
git_clone "$ACME_MGMT_GIT_REPO" "$ACME_MGMT_GIT_REF" \
    "$MOUNT/usr/src/acme-mgmt" "…/usr/src/acme-mgmt"

echo + "ACME_MGMT_HASH=\"\$(git -C …/usr/src/acme-mgmt rev-parse HEAD)\"" >&2
ACME_MGMT_HASH="$(git -C "$MOUNT/usr/src/acme-mgmt" rev-parse HEAD)"

echo + "[ \"\$ACME_MGMT_GIT_COMMIT\" == \"\$ACME_MGMT_HASH\" ]" >&2
if [ "$ACME_MGMT_GIT_COMMIT" != "$ACME_MGMT_HASH" ]; then
    echo "Failed to verify source code integrity of @PhrozenByte's acme management scripts v$ACME_MGMT_VERSION:" \
        "Expecting Git commit '$ACME_MGMT_GIT_COMMIT', got '$ACME_MGMT_HASH'" >&2
    exit 1
fi

echo + "cp …/usr/src/acme-mgmt/src/acme-issue …/usr/local/bin/acme-issue" >&2
cp "$MOUNT/usr/src/acme-mgmt/src/acme-issue" "$MOUNT/usr/local/bin/acme-issue"

echo + "cp …/usr/src/acme-mgmt/src/acme-renew …/usr/local/bin/acme-renew" >&2
cp "$MOUNT/usr/src/acme-mgmt/src/acme-renew" "$MOUNT/usr/local/bin/acme-renew"

cmd buildah run "$CONTAINER" -- \
    chmod 755 \
        "/usr/local/bin/acme-issue" \
        "/usr/local/bin/acme-renew"

echo + "cp …/usr/src/acme-mgmt/conf/config.env …/usr/local/share/acme/config.env" >&2
cp "$MOUNT/usr/src/acme-mgmt/conf/config.env" "$MOUNT/usr/local/share/acme/config.env"

echo + "rm -rf …/usr/src/acme-mgmt" >&2
rm -rf "$MOUNT/usr/src/acme-mgmt"

# finalize image
cleanup "$CONTAINER"

cmd buildah config \
    --volume "/var/local/acme" \
    --volume "/etc/acme" \
    "$CONTAINER"

cmd buildah config \
    --workingdir "/var/local/acme" \
    --entrypoint '[ "/entrypoint.sh" ]' \
    --cmd '[ "crond" ]' \
    "$CONTAINER"

cmd buildah config \
    --annotation org.opencontainers.image.title="ACME Issue & Renew" \
    --annotation org.opencontainers.image.description="A container to issue and renew Let's Encrypt SSL certificates using acme-tiny." \
    --annotation org.opencontainers.image.version- \
    --annotation org.opencontainers.image.url="https://github.com/SGSGermany/acme" \
    --annotation org.opencontainers.image.authors="SGS Serious Gaming & Simulations GmbH" \
    --annotation org.opencontainers.image.vendor="SGS Serious Gaming & Simulations GmbH" \
    --annotation org.opencontainers.image.licenses="MIT" \
    --annotation org.opencontainers.image.base.name="$BASE_IMAGE" \
    --annotation org.opencontainers.image.base.digest="$(podman image inspect --format '{{.Digest}}' "$BASE_IMAGE")" \
    "$CONTAINER"

con_commit "$CONTAINER" "${TAGS[@]}"
