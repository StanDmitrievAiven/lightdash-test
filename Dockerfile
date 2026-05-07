# Lightdash on Aiven Apps, fully stateless.
#
# All Lightdash state lives in an external Aiven for PostgreSQL service —
# users, projects, dashboards, charts, scheduled deliveries, sessions, etc.
# This container itself is disposable: scale to N replicas, redeploy at will.
#
# Required environment variables (set in Aiven Console -> Variables):
#   PGCONNECTIONURI    Aiven PG service URI, MUST include sslmode=require, e.g.
#                      postgres://avnadmin:PASSWORD@HOST:PORT/defaultdb?sslmode=require
#   LIGHTDASH_SECRET   Long random string. KEEP THIS STABLE across deploys —
#                      if it changes, encrypted records in PG become unreadable.
#   SITE_URL           Public https URL of the deployed app
#                      (e.g. https://lightdash.<your-aiven-app>.aivencloud.app)
#
# Recommended for production-on-Aiven-Apps:
#   SECURE_COOKIES=true
#   TRUST_PROXY=true
#   PGSSLMODE=require                  (already implied by ?sslmode=require)
#   SCHEDULER_ENABLED=true             (no Redis needed; jobs queued in PG)
#
# Optional — only needed for advanced features:
#   HEADLESS_BROWSER_HOST / HEADLESS_BROWSER_PORT  for chart screenshots / PDF
#                                                  exports / scheduled deliveries
#                                                  with images. Run a separate
#                                                  browserless container.
#   S3_*  +  RESULTS_S3_*              for query-results + delivery-file
#                                       persistence. Aiven for ClickHouse can
#                                       speak S3, or use any S3-compatible
#                                       object store.
#   SLACK_* / EMAIL_SMTP_*             for delivery channels.
#
# One-time PG setup (run once against the target Aiven PG database):
#   CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
# Lightdash will create + migrate the rest of its schema on first boot.

FROM lightdash/lightdash:latest

# Aiven Apps injects PORT; Lightdash already honours it (default 8080).
# Setting it here is just belt-and-braces.
ENV PORT=8080
EXPOSE 8080

# Inherit ENTRYPOINT/CMD from the upstream image — no override.
