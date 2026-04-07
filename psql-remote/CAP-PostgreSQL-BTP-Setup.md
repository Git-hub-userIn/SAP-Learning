# CAP PostgreSQL on SAP BTP — Setup Guide

## 1. Initialize Project

```bash
cds init <project-name> && cd <project-name>
cds add nodejs xsuaa tiny-sample postgres
cds add mta
```

---

## 2. Update mta.yaml

Replace the auto-generated postgres resource (which tries to create a new instance) with a reference to your existing one:

**Replace:**
```yaml
- name: <project-name>-postgres
  type: org.cloudfoundry.managed-service
  parameters:
    service: postgresql-db
    service-plan: development
```

**With:**
```yaml
- name: <project-name>-postgres
  type: org.cloudfoundry.existing-service
  parameters:
    service-name: <your-cf-postgres-instance-name>   # e.g. postgres
```

---

## 3. Build & Deploy

```bash
npm i
mbt build
cf deploy mta_archives/<project-name>_1.0.0.mtar
```

---

## 4. Enable SSH on Deployed App

Required for pgAdmin access via SSH tunnel. Only needs to be done once per app.

```bash
cf enable-ssh <project-name>-srv
cf restart <project-name>-srv
```

You can verify SSH is enabled in the BTP Cockpit under the app's General Information — `SSH Enabled: true`.

---

## 5. Get Service Key Credentials

The service key contains the database connection details needed for pgAdmin.

```bash
cf create-service-key <postgres-instance-name> my-key
cf service-key <postgres-instance-name> my-key
```

Note down these values from the JSON output:
- `hostname`
- `port`
- `dbname`
- `username`
- `password`

> You can also find these in BTP Cockpit → Instances and Subscriptions → your PostgreSQL instance → Service Keys.

---

## 6. Connect via pgAdmin

Open pgAdmin → right-click **Servers** → **Register → Server**

### General Tab
| Field | Value |
|-------|-------|
| Name | Any name you like |

### Connection Tab
| Field | Value |
|-------|-------|
| Host name/address | `hostname` from service key |
| Port | `port` from service key |
| Maintenance database | `dbname` from service key |
| Username | `username` from service key |
| Password | `password` from service key |

### Parameters Tab
Click `+` to add a new parameter:

| Name | Value |
|------|-------|
| SSL mode | `require` |

### SSH Tunnel Tab

| Field | Value |
|-------|-------|
| Use SSH tunneling | ON |
| Tunnel host | Derived from your CF API endpoint (see below) |
| Tunnel port | `2222` |
| Authentication | Password |
| Username | `cf:<app-guid>/0` |
| Password | One-time code from `cf ssh-code` |

#### How to get the Tunnel Host
Run `cf target` and look at the API endpoint:
```
API endpoint: https://api.cf.us10-001.hana.ondemand.com
```
Replace `api.cf` with `ssh.cf`:
```
ssh.cf.us10-001.hana.ondemand.com
```
This works for any BTP region. Port is always `2222`.

#### How to get SSH Username and Password

Run these two commands right before hitting Save (ssh-code expires in ~5 minutes):

```bash
cf app <project-name>-srv --guid    # gives you the app GUID
cf ssh-code                          # gives you the one-time password
```

Build the username as: `cf:<GUID>/0`

Example:
```
Username: cf:04b21135-1a04-4f12-8b45-59d3179c59c1/0
Password: KDZkswhsBuh2mGZ55o_lcnf_zpiRvS0J
```

> ⚠️ The SSH password expires in ~5 minutes. Run `cf ssh-code` again if the connection fails.

---

## Notes

- The GUID never changes for the same app — only the ssh-code changes on each reconnect.
- Your deployed CAP app connects to PostgreSQL over SSL automatically via `VCAP_SERVICES` — no extra config needed.
- The SSH tunnel is only needed for local tools like pgAdmin. Your app on BTP connects directly.
