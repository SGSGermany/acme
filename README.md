ACME Issue & Renew
==================

ACME Issue & Renew (`acme`) is a service container to issue and renew
[Let's Encrypt][1] TLS certificates using [@PhrozenByte][2]'s
[`acme` management scripts][3] and [acme-tiny][4].

This container is basically just an [Alpine][5]-based installation of these
scripts. All certs and their associated files are stored in `/var/local/acme`,
the configuration is stored in `/etc/acme`. Both directories are expected to be
volumes. Please refer to the [script's `README.md`][3] for information about
these directories and the required config.

On the container's first run the entrypoint script will create the necessary
files and directories; this also includes `/etc/acme/config.env`. The config
file is populated with values of the env variables `ACME_ACCOUNT_KEY_FILE`,
`ACME_ACCOUNT_CONTACT`, `ACME_DIRECTORY_URL`, `TLS_KEY_GROUP`, and
`FP_REVOCATION_LIST`. `FQDN_GROUPS` isn't supported at the moment.

The container runs `crond` by default. It runs two cronjobs, `acme-renew --all`
to renew all certificates once per month, and `acme-check --all` daily to check
validity of all certificates (especially whether they might have been revoked).
The cronjobs will choose a random execution time automatically; an algorithm
ensures that the execution times don't change unless you add/remove domains.
You might pass the `CRON_RENEW` and `CRON_CHECK` environment variables to
adjust the schedule (pass e.g. `CRON_RENEW='23 4 3 * *'` to run `acme-renew`
on the 3rd day of the month at 04:23 o'clock).

To issue new certs, renew existing ones, or to check certs manually, call
`acme-issue`, `acme-renew`, or `acme-check` inside the container, e.g.

```sh
podman exec -it --user acme acme acme-issue --force example.com www.example.com
podman exec -it --user acme acme acme-renew example.com
podman exec -it --user acme acme acme-check --all
```

Licensing
---------

Made with ♥ by [SGS Serious Gaming & Simulations](https://www.sgs-online.info).

This repository contains scripts and resources for building and continuously
integrating an OCI container image, as well as components used to run it
(e.g., setup scripts, runtime configuration, modified config files).

All contents of this repository are free and open-source software, licensed
under the terms of the [MIT License](./LICENSE).

Please note that the resulting OCI container image includes not only the
components provided in this repository, but also the primary third-party
software it is built to run, as well as base operating system components.
These are licensed under their respective licenses and are not covered by
the MIT License of this repository. Please refer to the respective component
licenses for details.

[1]: https://letsencrypt.org/
[2]: https://github.com/PhrozenByte
[3]: https://github.com/PhrozenByte/acme
[4]: https://github.com/diafygi/acme-tiny
[5]: https://alpinelinux.org/
