# Role-Based Authorization with XSUAA — Deep Dive

---

## Table of Contents

1. [How Authorization Actually Works (The Mental Model)](#1-how-authorization-actually-works)
2. [File-by-File Breakdown](#2-file-by-file-breakdown)
   - [db/schema.cds](#dbschemacds)
   - [srv/cat-service.cds](#srvcat-servicecds)
   - [xs-security.json](#xs-securityjson)
   - [package.json](#packagejson)
3. [The Full Chain — How It All Connects](#3-the-full-chain)
4. [Common Confusion — Permissions vs Scopes vs Roles](#4-common-confusion)

---

## 1. How Authorization Actually Works

### Your Assumption (Traditional RBAC)

You were thinking of the classic pattern:

```
Permissions (READ, UPDATE, DELETE)
    ↓  bundled into
Roles (Admin, Viewer)
    ↓  assigned to
Users
```

This is how systems like Keycloak, AWS IAM, or Spring Security work. You define fine-grained **permissions** first, then group them into **roles**.

### How SAP CAP + XSUAA Actually Works

CAP does it **differently**. There are **two separate layers** that handle authorization, and they work independently:

```
┌──────────────────────────────────────────────────────────────┐
│  LAYER 1: CDS Service (cat-service.cds)                      │
│                                                              │
│  This is where you define WHAT operations each role can do.  │
│  You say: "Admin can do *, Viewer can do READ"               │
│  The CDS runtime enforces this at the application level.     │
│                                                              │
│  Roles here are just STRING NAMES — CDS doesn't know or      │
│  care what a "scope" is. It just checks:                     │
│  "Does this user's JWT token contain this role name?"        │
└──────────────────────────────────────────────────────────────┘
                          │
                          │  At runtime, CAP checks the user's
                          │  JWT token for role names
                          │
┌──────────────────────────────────────────────────────────────┐
│  LAYER 2: XSUAA (xs-security.json)                           │
│                                                              │
│  This is the IDENTITY layer. It defines:                     │
│  - Scopes (atomic privileges like "Admin", "Viewer")         │
│  - Role Templates (bundles of scopes)                        │
│  - Role Collections (what you assign to real users in BTP)   │
│                                                              │
│  XSUAA puts the scope names into the user's JWT token.       │
│  CAP reads those scope names and treats them as "roles".     │
└──────────────────────────────────────────────────────────────┘
```

### The Key Insight

> **In CAP, permissions (READ, WRITE, etc.) are NOT defined in XSUAA. They are defined directly in the CDS service file using `@restrict`.**
>
> XSUAA only manages **who gets which role name in their token**. The CDS runtime is what maps role names → allowed operations.

So the flow is:

```
xs-security.json defines:  Scope "Admin" exists
                               ↓
Role Template bundles:     Role "Admin" includes scope "Admin"
                               ↓
Role Collection groups:    "BookStore_Admin" includes role template "Admin"
                               ↓
BTP Cockpit:               User john@example.com is assigned "BookStore_Admin"
                               ↓
At login, XSUAA puts:     "Admin" into John's JWT token
                               ↓
CAP CDS checks:           @restrict says Admin can do '*' → ✅ ALLOWED
```

---

## 2. File-by-File Breakdown

---

### `db/schema.cds`

```cds
namespace my.bookshop;
```

- **`namespace my.bookshop;`** — Declares a CDS namespace. All entities defined in this file will be prefixed with `my.bookshop.` internally. This is like a Java package or a database schema name. It prevents naming collisions if you have multiple modules.

```cds
entity Books {
```

- **`entity Books`** — Defines a database-level entity (table). After namespace resolution, the full name is `my.bookshop.Books`. CDS will create an SQLite table (dev) or HANA table (prod) named `my_bookshop_Books`.

```cds
  key ID    : Integer;
```

- **`key ID : Integer;`** — Declares `ID` as the **primary key** of the entity. The `key` keyword tells CDS this field uniquely identifies each record. `Integer` maps to SQL `INTEGER`. In OData, this becomes the entity's key property, enabling URLs like `/Books(1)`.

```cds
      title  : String;
```

- **`title : String;`** — A regular field. `String` defaults to `NVARCHAR(5000)` in HANA. No constraints — it's nullable and has no max length specified.

```cds
      author : String;
```

- **`author : String;`** — Same as above. Another nullable string column.

**What this file does NOT do:** It has no authorization logic. This file is purely the data model — the "shape" of your database table.

---

### `srv/cat-service.cds`

This is where all the authorization magic happens.

```cds
using {my.bookshop as db} from '../db/schema';
```

- **`using {my.bookshop as db}`** — Imports the namespace `my.bookshop` from the schema file and aliases it as `db`. This lets you write `db.Books` instead of `my.bookshop.Books` throughout this file.
- **`from '../db/schema'`** — Relative path to the schema.cds file. CDS resolves this at compile time.

```cds
service CatalogService @(requires: 'authenticated-user') {
```

- **`service CatalogService`** — Declares an OData V4 service. CAP will expose this at the URL path `/odata/v4/catalog` (it lowercases and removes "Service" from the name by convention).
- **`@(requires: 'authenticated-user')`** — This is an **authorization annotation**. It's a **gate at the service level**:
  - Any request to ANY entity in this service MUST come from an authenticated user.
  - If no valid credentials are provided → **401 Unauthorized**.
  - `'authenticated-user'` is a **pseudo-role** built into CAP. You don't need to define it anywhere — CAP understands it natively. It simply means "any user with a valid JWT token or basic auth credentials".
  - Other built-in pseudo-roles: `'system-user'`, `'internal-user'`, `'any'` (allows anonymous).

```cds
  @(restrict: [
    { grant: '*',    to: 'Admin'  },
    { grant: 'READ', to: 'Viewer' }
  ])
```

- **`@(restrict: [...])`** — This is the **fine-grained authorization annotation**. It's an array of privilege rules applied to the entity below it.
- **`{ grant: '*', to: 'Admin' }`** — Rule 1:
  - `grant: '*'` — Grants ALL CDS events: `READ`, `CREATE`, `UPDATE`, `DELETE`. The `*` is a wildcard.
  - `to: 'Admin'` — This privilege applies to users who have the role `Admin` in their JWT token.
  - **This is where "permissions" live in CAP.** The permission (what you can do) is the `grant` value. The role is the `to` value. They are defined together inline — not separately.
- **`{ grant: 'READ', to: 'Viewer' }`** — Rule 2:
  - `grant: 'READ'` — Only grants the READ event (OData `GET` requests).
  - `to: 'Viewer'` — Applies to users with the `Viewer` role.
  - If a Viewer tries to `POST` (create), `PATCH` (update), or `DELETE` → **403 Forbidden**.

```cds
  entity Books as projection on db.Books;
```

- **`entity Books`** — Exposes `Books` as an OData entity set within CatalogService.
- **`as projection on db.Books`** — This entity is a **projection** (view) on the underlying `my.bookshop.Books` database entity. A projection can select specific fields, add computed fields, etc. Here it's a 1:1 pass-through (all fields exposed).
- The `@restrict` annotation above applies to THIS entity specifically. You could have other entities in the same service with different restrictions.

**How CAP enforces `@restrict` at runtime:**

1. A request comes in: `POST /odata/v4/catalog/Books`
2. CAP extracts the user's roles from the JWT (or mocked auth).
3. CAP checks all `@restrict` rules on the `Books` entity.
4. It looks for a rule where `grant` includes the requested event (`CREATE`) AND `to` matches one of the user's roles.
5. If found → allow. If not → **403 Forbidden**.

---

### `xs-security.json`

This file is **only used when deploying to SAP BTP**. It tells the XSUAA service how to set up the OAuth2 security configuration. Locally, this file is completely ignored — mock auth from `package.json` is used instead.

```json
"xsappname": "backend-xsuaa-demo",
```

- **`xsappname`** — A unique identifier for your application in the XSUAA service. Scopes are prefixed with this name to avoid collisions across apps on the same BTP subaccount. For example, scope `Admin` becomes `backend-xsuaa-demo.Admin` internally.

```json
"tenant-mode": "dedicated",
```

- **`tenant-mode`** — Defines the multitenancy mode:
  - `"dedicated"` — Single-tenant. One XSUAA instance per subaccount. This is the simple/common case.
  - `"shared"` — Multi-tenant. One app serves multiple tenants (subscribers). Scopes are further prefixed with tenant IDs.

```json
"scopes": [
  {
    "name": "$XSAPPNAME.Admin",
    "description": "Full access to Books"
  },
  {
    "name": "$XSAPPNAME.Viewer",
    "description": "Read-only access to Books"
  }
],
```

- **`scopes`** — Defines the atomic privileges that exist in your application.
- **`$XSAPPNAME`** — A placeholder variable that XSUAA replaces with the actual `xsappname` value at deployment time. So `$XSAPPNAME.Admin` becomes `backend-xsuaa-demo.Admin`.
- **`"name": "$XSAPPNAME.Admin"`** — Declares a scope called `Admin`. A scope in XSUAA is conceptually similar to an OAuth2 scope — it's a string that can be included in a JWT token.

> ⚠️ **Critical:** The scope name after `$XSAPPNAME.` must **exactly match** the role name used in `@restrict → to:` in your CDS file. CDS checks for `'Admin'` → XSUAA must have a scope ending in `.Admin`. CAP strips the `xsappname.` prefix when reading the JWT.

- **`"description"`** — Human-readable text shown in BTP Cockpit. Has no functional impact.

```json
"attributes": [],
```

- **`attributes`** — Defines custom user attributes (like department, region, cost center) that can be used for **instance-based authorization** (e.g., "User can only see Books from their own region"). Empty here because we're only doing role-based, not attribute-based authorization.

```json
"role-templates": [
  {
    "name": "Admin",
    "description": "Admin role — full CRUD on Books",
    "scope-references": ["$XSAPPNAME.Admin"]
  },
  {
    "name": "Viewer",
    "description": "Viewer role — read-only on Books",
    "scope-references": ["$XSAPPNAME.Viewer"]
  }
],
```

- **`role-templates`** — Define **bundles of scopes**. This is the concept you were looking for!
  - A role template groups one or more scopes together.
  - In our case each role template has exactly one scope (1:1 mapping), but you could bundle multiple scopes into one role template.
  - Example of bundling: A `Manager` role template could reference both `$XSAPPNAME.Viewer` AND `$XSAPPNAME.Admin` scopes.
- **`"scope-references"`** — Array of scope names this role template includes. When a user is given this role template, ALL the listed scopes are added to their JWT token.

```json
"role-collections": [
  {
    "name": "BookStore_Admin",
    "description": "Admin role collection",
    "role-template-references": ["$XSAPPNAME.Admin"]
  },
  {
    "name": "BookStore_Viewer",
    "description": "Viewer role collection",
    "role-template-references": ["$XSAPPNAME.Viewer"]
  }
]
```

- **`role-collections`** — This is what you **actually assign to users** in BTP Cockpit.
  - You CANNOT assign scopes or role templates directly to users. You must assign **role collections**.
  - A role collection bundles one or more **role templates** (which in turn bundle scopes).
  - **`"role-template-references"`** — Array of role templates included in this collection. Uses the format `$XSAPPNAME.RoleTemplateName`.

### The XSUAA Hierarchy

```
Scope (atomic privilege string)
  └── bundled into → Role Template (grouping of scopes)
       └── bundled into → Role Collection (what's assigned to users)
            └── assigned to → User (in BTP Cockpit)
```

So your original mental model was actually correct for the XSUAA side! The difference is that:
- **XSUAA scopes ≠ permissions like READ/WRITE.** Scopes are just named tokens (strings).
- **CDS `@restrict` is where READ/WRITE permissions are defined and enforced.**

---

### `package.json`

```json
"name": "backend-xsuaa-demo",
"version": "1.0.0",
```

- Standard npm metadata. `name` should match `xsappname` in xs-security.json by convention (not enforced).

```json
"dependencies": {
  "@cap-js/hana": "^2",
  "@sap/cds": "^9",
  "@sap/xssec": "^4"
},
```

- **`@cap-js/hana`** — HANA database driver for production deployment. Unused locally (SQLite is used instead).
- **`@sap/cds`** — The SAP Cloud Application Programming Model runtime. This is the core framework that reads your CDS files, creates the OData service, enforces `@restrict` annotations, and handles all middleware.
- **`@sap/xssec`** — The **XSUAA security library**. In production, this library:
  1. Validates incoming JWT tokens against the XSUAA service.
  2. Extracts scopes/roles from the token.
  3. Makes them available to the CAP runtime for authorization checks.
  - Without this package, `auth: "xsuaa"` in production would fail.

```json
"devDependencies": {
  "@cap-js/sqlite": "^2",
  "@sap/cds-dk": "^9"
},
```

- **`@cap-js/sqlite`** — SQLite database driver, used only during local development. CDS automatically uses this when you run `cds serve` locally.
- **`@sap/cds-dk`** — CAP Development Kit. Provides the `cds` CLI commands (`cds serve`, `cds build`, `cds deploy`, etc.). Only needed during development.

```json
"scripts": {
  "start": "cds-serve"
},
```

- **`"start": "cds-serve"`** — The npm start script. `cds-serve` is a shortcut that boots the CAP server. On BTP Cloud Foundry, the platform runs `npm start` to launch your app.

```json
"private": true,
```

- **`"private": true`** — Prevents accidentally publishing this package to the npm registry.

```json
"cds": {
  "requires": {
    "auth": {
```

- **`"cds": { "requires": { ... } }`** — CAP configuration section. `requires` defines external services/features CAP needs.
- **`"auth"`** — Configures the authentication strategy. CAP has built-in support for multiple auth kinds.

```json
      "[production]": {
        "kind": "xsuaa"
      },
```

- **`"[production]"`** — A **CDS profile**. This config only activates when the app runs with `NODE_ENV=production` (which BTP Cloud Foundry sets automatically).
- **`"kind": "xsuaa"`** — Tells CAP to use real XSUAA JWT validation. CAP will:
  1. Expect a bound XSUAA service instance (via `VCAP_SERVICES`).
  2. Use `@sap/xssec` to validate JWT tokens.
  3. Extract scopes from the token and map them to CDS role names.

```json
      "[development]": {
        "kind": "mocked",
        "users": {
```

- **`"[development]"`** — Activates when running locally (the default profile when you run `cds serve`).
- **`"kind": "mocked"`** — Uses **mock authentication**. No real XSUAA service is needed. CAP uses HTTP Basic Auth and checks credentials against the `users` block below. The server sends a `WWW-Authenticate: Basic` header, which triggers the browser's username/password popup.

```json
          "admin": {
            "password": "admin",
            "roles": ["Admin"]
          },
```

- **`"admin"`** — A mock user with username `admin`.
- **`"password": "admin"`** — The password for basic auth. (Only for local testing — never used in production.)
- **`"roles": ["Admin"]`** — This mock user has the `Admin` role. When CAP processes a request from this user, it pretends the JWT token contains the `Admin` scope. The `@restrict` annotation then grants `*` (all operations).

```json
          "viewer": {
            "password": "viewer",
            "roles": ["Viewer"]
          }
```

- Same as above but with only the `Viewer` role → CDS `@restrict` only grants `READ`.

---

## 3. The Full Chain

### Locally (Development)

```
Browser → GET /odata/v4/catalog/Books
       → CAP sees @(requires: 'authenticated-user') → demands Basic Auth
       → User enters "viewer" / "viewer"
       → CAP mocked auth finds the user in package.json → roles: ["Viewer"]
       → CAP checks @restrict on Books → Viewer has grant: 'READ'
       → GET is a READ → ✅ 200 OK with data

Browser → POST /odata/v4/catalog/Books  (as viewer)
       → CAP checks @restrict → Viewer only has READ, not CREATE
       → ❌ 403 Forbidden

Browser → POST /odata/v4/catalog/Books  (as admin)
       → CAP checks @restrict → Admin has grant: '*' which includes CREATE
       → ✅ 201 Created
```

### On BTP (Production)

```
Browser → GET /odata/v4/catalog/Books
       → App Router redirects to XSUAA login page
       → User logs in with SAP ID / IDP credentials
       → XSUAA checks: User has role collection "BookStore_Viewer"
       → Role collection includes role template "Viewer"
       → Role template includes scope "$XSAPPNAME.Viewer"
       → XSUAA issues JWT with scope: ["backend-xsuaa-demo.Viewer"]
       → Request hits CAP with JWT attached
       → @sap/xssec validates JWT, extracts scopes
       → CAP strips prefix → role name = "Viewer"
       → @restrict check: Viewer has READ → ✅ 200 OK
```

---

## 4. Common Confusion

### "Where are the permissions defined?"

| What you expected | What CAP does |
|---|---|
| Permissions (READ, WRITE) defined in XSUAA | Permissions defined in CDS `@restrict` annotations |
| Roles bundle permissions in XSUAA | XSUAA role templates bundle **scopes** (just named strings) |
| Roles assigned to users in XSUAA | **Role collections** assigned to users (not role templates directly) |

### "Why doesn't XSUAA know about READ/WRITE?"

Because XSUAA is a **generic OAuth2 authorization server**. It doesn't know anything about OData, CDS, or REST operations. It only manages **identity** (who are you?) and **scopes** (what named privileges do you have?).

The **application** (CAP) is responsible for interpreting what those scopes mean in terms of actual operations.

### "So why do we need XSUAA scopes at all?"

Scopes are the **bridge** between XSUAA and CAP:

1. XSUAA puts scope names into the JWT token.
2. CAP reads those scope names from the token.
3. CAP matches them against the `to:` values in `@restrict`.
4. The `grant:` values determine what operations are allowed.

Without scopes, CAP would have no way to know which roles a user has.

### The Hierarchy Visualized

```
xs-security.json                         cat-service.cds
┌─────────────────────┐                  ┌──────────────────────────┐
│ Scope: "Admin"      │ ──(JWT token)──▶ │ @restrict: grant '*'     │
│ Scope: "Viewer"     │ ──(JWT token)──▶ │ @restrict: grant 'READ'  │
│                     │                  │                          │
│ Role Template:      │                  │ (CAP enforces these at   │
│  bundles scopes     │                  │  runtime based on the    │
│                     │                  │  role names in the JWT)  │
│ Role Collection:    │                  │                          │
│  assigned to users  │                  │                          │
└─────────────────────┘                  └──────────────────────────┘
     IDENTITY LAYER                          APPLICATION LAYER
     (who has what role)                     (what can each role do)
```
