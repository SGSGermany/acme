#!/bin/sh
# acme
# A container to issue and renew Let's Encrypt SSL certificates using acme-tiny.
#
# Copyright (c) 2016-2020  Daniel Rudolf
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
    if [ ! -d /var/local/acme/live ]; then
        mkdir /var/local/acme/live
        chown acme:acme /var/local/acme/live
    fi
    if [ ! -d /var/local/acme/archive ]; then
        mkdir /var/local/acme/archive
        chown acme:acme /var/local/acme/archive
    fi
    if [ ! -d /var/local/acme/challenges ]; then
        mkdir /var/local/acme/challenges
        chown acme:acme /var/local/acme/challenges
    fi

    if [ -z "$ACME_ACCOUNT_KEY_FILE" ]; then
        ACME_ACCOUNT_KEY_FILE="/etc/acme/account.key"
        if [ ! -f "$ACME_ACCOUNT_KEY_FILE" ]; then
            ( umask 027 && openssl genrsa 4096 > "$ACME_ACCOUNT_KEY_FILE" )
            chmod 640 "$ACME_ACCOUNT_KEY_FILE"
            chown acme:acme "$ACME_ACCOUNT_KEY_FILE"
        fi
    fi
    if [ ! -f /etc/acme/config.env ]; then
        touch /etc/acme/config.env
        chown acme:acme /etc/acme/config.env

        echo "ACME_ACCOUNT_KEY_FILE='$ACME_ACCOUNT_KEY_FILE'" >> /etc/acme/config.env
        echo "ACME_ACCOUNT_CONTACT='$ACME_ACCOUNT_CONTACT'" >> /etc/acme/config.env
        echo "ACME_DIRECTORY_URL='$ACME_DIRECTORY_URL'" >> /etc/acme/config.env
        echo "TLS_KEY_GROUP='$TLS_KEY_GROUP'" >> /etc/acme/config.env
    fi

    # crond
    if [ $# -eq 0 ] || [ "$1" == "crond" ]; then
        exec crond -f -l 7 -L /dev/stdout
    fi

    # acme-issue and acme-renew
    exec su -p -s /bin/sh acme -c '"$@"' -- '/bin/sh' "$@"
fi

exec "$@"
