# SAP CAP + PostgreSQL Setup Guide (Node.js)

## Prerequisites

- Node.js 18+
- `@sap/cds-dk` installed globally (`npm i -g @sap/cds-dk`)
- PostgreSQL instance (local or remote)

---

## Project Initialization

```bash
cds init <app-name> --add nodejs,tiny-sample
cd <app-name>
npm install
cds add postgres
```

> Note: `cds init` alone does not generate `package.json`. The `--add nodejs` flag is required.

---

## Local Development (SQLite)

No configuration required. SQLite is used by default for local development.

```bash
cds watch
```

Service is available at `http://localhost:4004`.

---

## PostgreSQL Configuration

Create `.cdsrc.json` in the project root:

```json
{
  "requires": {
    "db": {
      "[pg]": {
        "kind": "postgres",
        "credentials": {
          "host": "<host>",
          "port": 5432,
          "user": "<user>",
          "password": "<password>",
          "database": "<database>",
          "ssl": true
        },
        "pool": {
          "acquireTimeoutMillis": 30000,
          "destroyTimeoutMillis": 30000
        }
      }
    }
  }
}
```

**Notes:**
- Use individual credential fields — the `url` field is not reliably parsed by `@cap-js/postgres`.
- The default `acquireTimeoutMillis` is 1000ms. For remote databases, set it to at least 30000ms.
- Set `ssl: true` for hosted PostgreSQL providers that require SSL.
- Store sensitive credentials in `.env` or a secrets manager. Do not commit `.cdsrc.json` with plaintext passwords to version control.

---

## Commands

```bash
# Deploy schema to PostgreSQL
cds deploy --profile pg

# Run application with PostgreSQL
cds watch --profile pg

# Verify effective configuration
cds env requires.db --profile pg
```

---

## Project Structure

```
cap-app/
├── .cdsrc.json         ← PostgreSQL profile configuration
├── db/
│   ├── schema.cds      ← Entity definitions
│   └── data/           ← CSV seed data
├── srv/
│   └── service.cds     ← Service definitions
└── package.json
```

---

## Known Issues

| Symptom | Cause | Resolution |
|---|---|---|
| `package.json` not generated | `cds init` used without `--add nodejs` | Use `cds init <n> --add nodejs` |
| `ResourceRequest timed out` | Default pool timeout too low for remote DB | Set `acquireTimeoutMillis: 30000` in pool config |
| `deployment to undefined:5432` | `url` field not parsed correctly | Use individual credential fields |
| Tables created in SQLite instead of PostgreSQL | `--profile pg` flag missing | Run `cds deploy --profile pg` |