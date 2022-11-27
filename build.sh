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

# acme-tiny <https://github.com/diafygi/acme-tiny>
# tag '5.0.1', commit 1858f68204983d86d3bb8f51463af91301965322
# dated 2021-09-11 18:38:35 UTC
ACME_TINY="https://raw.githubusercontent.com/diafygi/acme-tiny/5.0.1/acme_tiny.py"

# acme-issue and acme-renew scripts <https://github.com/PhrozenByte/acme>
# tag 'v1.8', commit cefb47ada9aebb45c8662768f103517b39c51d2c
# dated 2021-10-02 17:48:35 UTC
ISSUE_SCRIPT="https://raw.githubusercontent.com/PhrozenByte/acme/v1.8/src/acme-issue"
RENEW_SCRIPT="https://raw.githubusercontent.com/PhrozenByte/acme/v1.8/src/acme-renew"
CONFIG="https://raw.githubusercontent.com/PhrozenByte/acme/v1.8/conf/config.env"
VERSION="1.8"

set -eu -o pipefail
export LC_ALL=C

[ -v CI_TOOLS ] && [ "$CI_TOOLS" == "SGSGermany" ] \
    || { echo "Invalid build environment: Environment variable 'CI_TOOLS' not set or invalid" >&2; exit 1; }

[ -v CI_TOOLS_PATH ] && [ -d "$CI_TOOLS_PATH" ] \
    || { echo "Invalid build environment: Environment variable 'CI_TOOLS_PATH' not set or invalid" >&2; exit 1; }

source "$CI_TOOLS_PATH/helper/common.sh.inc"
source "$CI_TOOLS_PATH/helper/container.sh.inc"
source "$CI_TOOLS_PATH/helper/container-alpine.sh.inc"

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

pkg_install "$CONTAINER" --virtual .fetch-deps \
    curl

cmd buildah run "$CONTAINER" -- \
    curl -fsSL -o /usr/local/bin/acme-tiny "$ACME_TINY"

cmd buildah run "$CONTAINER" -- \
    curl -fsSL -o /usr/local/bin/acme-issue "$ISSUE_SCRIPT"

cmd buildah run "$CONTAINER" -- \
    curl -fsSL -o /usr/local/bin/acme-renew "$RENEW_SCRIPT"

cmd buildah run "$CONTAINER" -- \
    curl -fsSL -o /etc/acme/config.env.dist "$CONFIG"

cmd buildah run "$CONTAINER" -- \
    chmod 755 \
        /usr/local/bin/acme-tiny \
        /usr/local/bin/acme-issue \
        /usr/local/bin/acme-renew

pkg_remove "$CONTAINER" \
    .fetch-deps

pkg_install "$CONTAINER" --virtual .acme-run-deps \
    python3 \
    openssl \
    bash

user_add "$CONTAINER" acme 65536 "/var/local/acme"

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
    --annotation org.opencontainers.image.version="$VERSION" \
    --annotation org.opencontainers.image.url="https://github.com/SGSGermany/acme" \
    --annotation org.opencontainers.image.authors="SGS Serious Gaming & Simulations GmbH" \
    --annotation org.opencontainers.image.vendor="SGS Serious Gaming & Simulations GmbH" \
    --annotation org.opencontainers.image.licenses="MIT" \
    --annotation org.opencontainers.image.base.name="$BASE_IMAGE" \
    --annotation org.opencontainers.image.base.digest="$(podman image inspect --format '{{.Digest}}' "$BASE_IMAGE")" \
    "$CONTAINER"

con_commit "$CONTAINER" "${TAGS[@]}"
