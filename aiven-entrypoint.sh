#!/bin/sh
# Wrapper around the upstream Lightdash entrypoint.
#
# Aiven Apps injects PROJECT_CA_CERT (base64-encoded) for every container
# and the platform expects you to add it to your TLS trust store so that
# connections to Aiven managed services (PG, ClickHouse, Kafka, ...) verify
# correctly. Aiven uses an internal CA, not a publicly-trusted one, so the
# default Node trust store fails the handshake with
# "self-signed certificate in certificate chain".
#
# We solve this here: decode the cert into a file, then point Node at it
# via NODE_EXTRA_CA_CERTS. After that, hand off to the upstream entrypoint
# unchanged so all Lightdash bootstrap (knex migrate, scheduler, server)
# runs as it would in any other deployment.

set -e

if [ -n "${PROJECT_CA_CERT:-}" ]; then
    echo "${PROJECT_CA_CERT}" | base64 -d > /tmp/aiven-ca.pem
    export NODE_EXTRA_CA_CERTS=/tmp/aiven-ca.pem
fi

exec dumb-init -- /usr/bin/prod-entrypoint.sh "$@"
