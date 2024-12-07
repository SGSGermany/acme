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
`ACME_ACCOUNT_CONTACT`, `ACME_DIRECTORY_URL`, `TLS_KEY_GROUP` and
`FP_REVOCATION_LIST` to change the config on-the-fly.

The container runs `crond` by default. It runs two cronjobs, `acme-renew --all`
to renew all certificates once per month, and `acme-check --all` daily to check
validity of all certificates (especially whether they might have been revoked).
The cronjobs will choose a random execution time automatically; an algorithm
ensures that the execution times don't change unless you add/remove domains.
You might passt the `CRON_RENEW` and `CRON_CHECK` environment variables to
overwrite the schedule (pass e.g. `CRON_RENEW='23 4 3 * *'` to run `acme-renew`
on the 3rd day of the month at 04:23 o'clock).

To issue new certs, renew existing ones, or to check certs manually, call
`acme-issue`, `acme-renew`, or `acme-check` inside the container, e.g.

```sh
podman exec -it acme acme-issue --force example.com www.example.com
podman exec -it acme acme-renew example.com
podman exec -it acme acme-check --all
```

[1]: https://letsencrypt.org/
[2]: https://github.com/PhrozenByte
[3]: https://github.com/PhrozenByte/acme
[4]: https://github.com/diafygi/acme-tiny
[5]: https://alpinelinux.org/
