ACME Issue & Renew
==================

ACME Issue & Renew (`acme`) is a service container to issue and renew
[Let's Encrypt][1] TLS certificates using [@PhrozenByte][2]'s
[`acme` management scripts][3] and [acme-tiny][4].

This container is basically just an [Alpine][5]-based installation of these
scripts. All certs and their associated files are stored in `/var/local/acme`,
the configuration is stored in `/etc/acme`. Both directories are expected to be
volumes. Please refer to the [script's `README.md`][3] for information about
these directories and the required config. The container's entrypoint will
create the necessary files and directories, so if there's no `config.env`, it
will create it. You can use the script's env variables `ACME_ACCOUNT_KEY_FILE`,
`ACME_ACCOUNT_CONTACT`, `ACME_DIRECTORY_URL` and `TLS_KEY_GROUP` to change
the config on-the-fly.

The container runs `crond` by default. The only cronjob runs once a month (on
the first day of the month at 00:00:00 UTC) and executes `acme-renew --all`.
To issue new certs or to renew existing certs manually, call `acme-issue` or
`acme-renew` inside the container, e.g.

```sh
podman exec -it acme acme-issue --force example.com www.example.com
podman exec -it acme acme-renew example.com
```

[1]: https://letsencrypt.org/
[2]: https://github.com/PhrozenByte
[3]: https://github.com/PhrozenByte/acme
[4]: https://github.com/diafygi/acme-tiny
[5]: https://alpinelinux.org/
