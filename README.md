# Lightdash on Aiven — stateless

Run [Lightdash](https://github.com/lightdash/lightdash) (the open-source Looker
alternative) as a fully stateless container, with **Aiven for PostgreSQL** as
the only stateful backing service.

> TL;DR — there is **no** Redis, **no** local volume, **no** embedded DB.
> Every piece of Lightdash state (users, projects, dashboards, charts, scheduled
> deliveries, sessions) lives in your Aiven Postgres database. Scale to N
> replicas, redeploy, blow the container away — your data stays put.

## Why this works

Lightdash is happy to talk to an external Postgres. Their docs even call it out
explicitly: ["Configure Lightdash to use an external database"](https://docs.lightdash.com/self-host/customize-deployment/configure-lightdash-to-use-an-external-database).

What Lightdash needs to be stateless:

| Concern | Where it lives in this setup |
| --- | --- |
| Auth, projects, dashboards, charts, organisations | Aiven for PostgreSQL |
| Scheduled-delivery job queue | Aiven for PostgreSQL (no Redis required — the scheduler uses PG) |
| Sessions / cookies | Encrypted with `LIGHTDASH_SECRET`, stored in PG |
| Container filesystem | Disposable. Nothing important is written here. |

What Lightdash **doesn't** need (but you can add later for advanced features):

- **Headless Chrome** — only needed for chart screenshots, PDF exports, and
  scheduled deliveries with embedded images. Run the
  `ghcr.io/browserless/chromium` image as a sidecar and point Lightdash at it
  with `HEADLESS_BROWSER_HOST` / `HEADLESS_BROWSER_PORT`.
- **S3 object storage** — only needed if you want query-result caching and
  delivery-file persistence. Any S3-compatible store works (Aiven for
  ClickHouse can speak S3, MinIO, AWS, GCS via the S3 API, ...).
- **SMTP / Slack** — only for delivery channels.

## Files in this repo

- [`Dockerfile`](./Dockerfile) — single-line `FROM lightdash/lightdash:latest`,
  exposes port 8080. That's it. All wiring is via env vars.
- [`docker-compose.yml`](./docker-compose.yml) — convenience compose file for
  running the container locally against an Aiven PG.
- [`.env.example`](./.env.example) — every env var you need (and a few
  optional ones) with explanations.

## Deploy on Aiven Apps

1. **Create an Aiven for PostgreSQL service** (PG 12 or later).
2. **Enable the `uuid-ossp` extension** — Lightdash needs it for migrations:

   ```sql
   CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
   ```

   (You can run this from the Aiven Console -> Services -> your PG -> Query
   editor, or via `psql`.)

3. **Generate a stable Lightdash secret**:

   ```bash
   openssl rand -hex 32
   ```

   Save it — you'll need it on every deploy. **If it ever changes, all
   encrypted records in PG become unrecoverable.**

4. **Deploy this repo as an Aiven App** (Aiven Console -> Applications ->
   Create from Git). Point at this GitHub repo. Aiven Apps will detect the
   `Dockerfile` and build it.

5. **Set the application variables** in the Aiven Console:

   | Variable | Value |
   | --- | --- |
   | `PGCONNECTIONURI` | the Aiven PG service URI, including `?sslmode=require` |
   | `LIGHTDASH_SECRET` | the secret from step 3 |
   | `SITE_URL` | the public https URL Aiven Apps gave you (e.g. `https://lightdash.<id>.aivencloud.app`) |
   | `SECURE_COOKIES` | `true` |
   | `TRUST_PROXY` | `true` |

   `PORT` is injected automatically by Aiven Apps.

6. **First boot** runs the schema migrations against PG. Watch the application
   logs (Console -> Logs) — you should see `Lightdash listening on PORT 8080`.

7. **Open the public URL.** Create the first user (it auto-becomes the org
   admin). Connect a dbt project or a warehouse and you're off.

## Connect Lightdash to your Aiven warehouse

Once Lightdash is up, point it at any of your Aiven analytical services as a
project warehouse:

- **Aiven for PostgreSQL** — Lightdash > Create project > Postgres -> paste
  the service URI / credentials.
- **Aiven for ClickHouse** — Lightdash > Create project > ClickHouse -> use
  the HTTPS endpoint.

Lightdash will read your dbt models from the connected git repo and let your
team explore the metrics defined there.

## Run locally

```bash
cp .env.example .env
# edit .env: PGCONNECTIONURI, LIGHTDASH_SECRET, SITE_URL=http://localhost:8080
docker compose up --build
# open http://localhost:8080
```

The container talks to your Aiven PG over the public internet (Aiven services
expose a TLS endpoint by default). For production, prefer an Aiven Apps
deployment in the same VPC as your PG service.

## Notes

- The `Dockerfile` pins to `lightdash/lightdash:latest`. For deterministic
  deploys, pin to a specific tag — see
  [Lightdash releases](https://github.com/lightdash/lightdash/releases).
- The image already runs `node` as a non-root user and listens on
  `0.0.0.0:$PORT`.
- Aiven for PostgreSQL ships with `uuid-ossp` available out of the box; you
  just need to `CREATE EXTENSION` it once.
- This repo intentionally does NOT bundle a Postgres container. The whole
  point is to lean on Aiven's managed PG for HA, backups, point-in-time
  recovery, etc.
