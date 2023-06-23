#!/bin/sh
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

set -e

if [ $# -eq 0 ] || [ "$1" == "crond" ] || [ "$1" == "acme-issue" ] || [ "$1" == "acme-renew" ]; then
    # runtime setup
    /usr/local/lib/acme/acme-setup

    # run crond
    if [ $# -eq 0 ] || [ "$1" == "crond" ]; then
        exec crond -f -l 7 -L /dev/stdout
    fi

    # run acme-issue, or acme-renew
    exec su -p -s /bin/sh acme -c '"$@"' -- '/bin/sh' "$@"
fi

exec "$@"
