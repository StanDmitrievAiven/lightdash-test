# Lightdash on Aiven Apps, fully stateless.
#
# All Lightdash state lives in an external Aiven for PostgreSQL service —
# users, projects, dashboards, charts, scheduled deliveries, sessions, etc.
# This container itself is disposable: scale to N replicas, redeploy at will.
#
# Required environment variables (set in Aiven Console -> Variables):
#   PGCONNECTIONURI    Aiven PG service URI, MUST include sslmode=require, e.g.
#                      postgres://avnadmin:PASSWORD@HOST:PORT/defaultdb?sslmode=require
#                      When deployed via Aiven Apps with a `pg` service integration,
#                      this variable is auto-injected by the platform.
#   LIGHTDASH_SECRET   Long random string. KEEP THIS STABLE across deploys —
#                      if it changes, encrypted records in PG become unreadable.
#   SITE_URL           Public https URL of the deployed app
#                      (e.g. https://lightdash.<your-aiven-app>.aivencloud.app).
#
# Recommended for production-on-Aiven-Apps:
#   SECURE_COOKIES=true
#   TRUST_PROXY=true
#   SCHEDULER_ENABLED=true             (no Redis needed; jobs queued in PG)
#
# Optional — only needed for advanced features:
#   HEADLESS_BROWSER_HOST / HEADLESS_BROWSER_PORT  for chart screenshots / PDF
#                                                  exports / scheduled deliveries
#                                                  with images.
#   S3_*  +  RESULTS_S3_*              for query-results + delivery-file
#                                       persistence.
#   SLACK_* / EMAIL_SMTP_*             for delivery channels.
#
# One-time PG setup (run once against the target Aiven PG database):
#   CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
# Lightdash will create + migrate the rest of its schema on first boot.

FROM lightdash/lightdash:latest

# Aiven Apps injects PROJECT_CA_CERT (base64) at runtime. Aiven services use
# an Aiven-issued CA — Node's default trust store doesn't include it, so
# `?sslmode=require` connections fail with "self-signed certificate in
# certificate chain". The wrapper below decodes the cert into the trust
# store via NODE_EXTRA_CA_CERTS before handing off to the upstream entrypoint.
COPY aiven-entrypoint.sh /usr/local/bin/aiven-entrypoint.sh
RUN chmod +x /usr/local/bin/aiven-entrypoint.sh

# Aiven Apps injects PORT; Lightdash already honours it (default 8080).
ENV PORT=8080
EXPOSE 8080

# Override only the ENTRYPOINT (so we can inject the CA cert). CMD stays
# the same as the upstream image, which means no behavioural change beyond
# the CA wiring.
ENTRYPOINT ["/usr/local/bin/aiven-entrypoint.sh"]
CMD ["node", "dist/index.js"]
