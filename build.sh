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

set -eu -o pipefail
export LC_ALL=C

cmd() {
    echo + "$@"
    "$@"
    return $?
}

BUILD_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
[ -f "$BUILD_DIR/container.env" ] && source "$BUILD_DIR/container.env" \
    || { echo "ERROR: Container environment not found" >&2; exit 1; }

readarray -t -d' ' TAGS < <(printf '%s' "$TAGS")

echo + "CONTAINER=\"\$(buildah from $BASE_IMAGE)\""
CONTAINER="$(buildah from "$BASE_IMAGE")"

echo + "MOUNT=\"\$(buildah mount $CONTAINER)\""
MOUNT="$(buildah mount "$CONTAINER")"

echo + "rsync -v -rl --exclude .gitignore ./src/ …/"
rsync -v -rl --exclude '.gitignore' "$BUILD_DIR/src/" "$MOUNT/"

cmd buildah run "$CONTAINER" -- \
    adduser -u 65536 -s "/sbin/nologin" -D -h "/var/local/acme" acme

cmd buildah run "$CONTAINER" -- \
    apk add --no-cache --virtual .fetch-deps \
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

cmd buildah run "$CONTAINER" -- \
    apk del --no-network .fetch-deps

cmd buildah run "$CONTAINER" -- \
    apk add --virtual .acme-run-deps \
        python3 \
        openssl \
        bash

cmd buildah run "$CONTAINER" -- \
    ln -s python3 /usr/bin/python

cmd buildah run "$CONTAINER" -- \
    ln -s /etc/ssl1.1/openssl.cnf /etc/ssl/openssl.cnf

echo + "rm …/etc/crontabs/root"
rm "$MOUNT/etc/crontabs/root"

echo + "echo '0 0 1 * * acme-renew --all --verbose --retry' > …/etc/crontabs/acme"
echo '0 0 1 * * acme-renew --all --verbose --retry' > "$MOUNT/etc/crontabs/acme"

cmd buildah config \
    --volume "/var/local/acme" \
    --volume "/etc/acme" \
    "$CONTAINER"

cmd buildah config \
    --entrypoint '[ "/entrypoint.sh" ]' \
    --cmd 'crond' \
    "$CONTAINER"

cmd buildah config \
    --annotation org.opencontainers.image.title="ACME Issue & Renew" \
    --annotation org.opencontainers.image.description="A container to issue and renew Let's Encrypt SSL certificates using acme-tiny." \
    --annotation org.opencontainers.image.url="https://github.com/SGSGermany/acme" \
    --annotation org.opencontainers.image.authors="SGS Serious Gaming & Simulations GmbH" \
    --annotation org.opencontainers.image.vendor="SGS Serious Gaming & Simulations GmbH" \
    --annotation org.opencontainers.image.licenses="MIT" \
    --annotation org.opencontainers.image.base.name="$BASE_IMAGE" \
    --annotation org.opencontainers.image.base.digest="$(podman image inspect --format '{{.Digest}}' "$BASE_IMAGE")" \
    "$CONTAINER"

cmd buildah commit "$CONTAINER" "$IMAGE:${TAGS[0]}"
cmd buildah rm "$CONTAINER"

for TAG in "${TAGS[@]:1}"; do
    cmd buildah tag "$IMAGE:${TAGS[0]}" "$IMAGE:$TAG"
done
