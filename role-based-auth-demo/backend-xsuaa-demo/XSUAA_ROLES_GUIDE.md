# How to Add, Enforce & Verify Roles via XSUAA — Complete Guide

---

## Table of Contents

1. [Overview — The 3 Phases](#1-overview)
2. [Phase 1: ADD Roles](#2-phase-1-add-roles)
   - [Step 1.1: Define Scopes in xs-security.json](#step-11-define-scopes)
   - [Step 1.2: Create Role Templates](#step-12-create-role-templates)
   - [Step 1.3: Create Role Collections](#step-13-create-role-collections)
   - [Step 1.4: Advanced — Bundling Multiple Scopes](#step-14-advanced--bundling-multiple-scopes)
   - [Step 1.5: Advanced — Attribute-Based Scoping](#step-15-advanced--attribute-based-scoping)
3. [Phase 2: ENFORCE Roles](#3-phase-2-enforce-roles)
   - [Step 2.1: Service-Level Guard](#step-21-service-level-guard)
   - [Step 2.2: Entity-Level Restrictions](#step-22-entity-level-restrictions)
   - [Step 2.3: All Possible Grant Values](#step-23-all-possible-grant-values)
   - [Step 2.4: Advanced — Field-Level Restrictions](#step-24-advanced--field-level-restrictions)
   - [Step 2.5: Advanced — Where Clauses (Instance-Based)](#step-25-advanced--where-clauses)
   - [Step 2.6: Advanced — Programmatic Enforcement in JS](#step-26-advanced--programmatic-enforcement-in-js)
   - [Step 2.7: Wire Up Auth in package.json](#step-27-wire-up-auth-in-packagejson)
   - [Step 2.8: Add Required npm Dependency](#step-28-add-required-npm-dependency)
4. [Phase 3: VERIFY Roles](#4-phase-3-verify-roles)
   - [Step 3.1: Local Verification (Mocked Auth)](#step-31-local-verification)
   - [Step 3.2: Verify via Browser](#step-32-verify-via-browser)
   - [Step 3.3: Verify via curl](#step-33-verify-via-curl)
   - [Step 3.4: Verify via REST Client (VS Code)](#step-34-verify-via-rest-client)
   - [Step 3.5: Verify on BTP (Production)](#step-35-verify-on-btp)
   - [Step 3.6: Decode & Inspect JWT Tokens](#step-36-decode--inspect-jwt-tokens)
   - [Step 3.7: Verify Programmatically in Handler](#step-37-verify-programmatically-in-handler)
5. [Quick Reference — Adding a New Role End-to-End](#5-quick-reference)
6. [Troubleshooting](#6-troubleshooting)

---

## 1. Overview

Adding role-based auth to a CAP + XSUAA app involves **3 phases**, each touching specific files:

```
Phase 1: ADD          Phase 2: ENFORCE          Phase 3: VERIFY
─────────────         ──────────────────         ───────────────
xs-security.json      cat-service.cds            Browser / curl / Postman
                      package.json               BTP Cockpit
                      (optional) .js handler      JWT token inspection
```

---

## 2. Phase 1: ADD Roles

This phase defines what roles exist in the XSUAA identity system.

---

### Step 1.1: Define Scopes

**File:** `xs-security.json` → `scopes` array

Scopes are the **atomic building blocks** of authorization. Each scope is a named string that can appear in a user's JWT token.

```json
{
  "xsappname": "my-app",
  "tenant-mode": "dedicated",
  "scopes": [
    {
      "name": "$XSAPPNAME.Admin",
      "description": "Full administrative access"
    },
    {
      "name": "$XSAPPNAME.Viewer",
      "description": "Read-only access"
    },
    {
      "name": "$XSAPPNAME.Editor",
      "description": "Can create and update but not delete"
    }
  ]
}
```

**Rules:**
- `$XSAPPNAME` is a variable that XSUAA replaces with your app name at deployment. Technically you *can* write a scope without it (e.g., just `"Admin"`), but you **should always use it**. Without the prefix, scope names are globally unscoped on the subaccount, which causes collisions when multiple apps define the same scope name. Treat it as mandatory.
- The part after `$XSAPPNAME.` is the **scope suffix** — this is what CAP sees as the "role name".
- Scope suffix must **exactly match** what you use in CDS `@restrict → to:`.
- Scope names are **case-sensitive**. `Admin` ≠ `admin`.
- Keep scope names simple — PascalCase is convention (e.g., `Admin`, `Viewer`, `RegionalManager`).

> 💡 **Shortcut:** In CAP v7+, you can auto-generate `xs-security.json` from your CDS annotations:
> ```bash
> cds add xsuaa
> ```
> This reads all `@requires` and `@restrict` annotations from your CDS files and scaffolds the scopes, role templates, and role collections for you. Much less error-prone than writing it by hand.

**Naming guidelines:**

| Good ✅ | Bad ❌ | Why |
|---|---|---|
| `$XSAPPNAME.Admin` | `$XSAPPNAME.ADMIN_ROLE` | CAP will look for role `ADMIN_ROLE` — must match CDS exactly |
| `$XSAPPNAME.Viewer` | `$XSAPPNAME.read` | `read` is confusing — sounds like an operation, not a role |
| `$XSAPPNAME.RegionalManager` | `$XSAPPNAME.regional-manager` | Hyphens can cause issues in some contexts |

---

### Step 1.2: Create Role Templates

**File:** `xs-security.json` → `role-templates` array

Role templates **bundle one or more scopes** together. They are the middle layer between scopes and what users get assigned.

```json
"role-templates": [
  {
    "name": "Admin",
    "description": "Full administrative access",
    "scope-references": [
      "$XSAPPNAME.Admin"
    ]
  },
  {
    "name": "Viewer",
    "description": "Read-only access",
    "scope-references": [
      "$XSAPPNAME.Viewer"
    ]
  },
  {
    "name": "Editor",
    "description": "Can create and update content",
    "scope-references": [
      "$XSAPPNAME.Editor"
    ]
  }
]
```

**Rules:**
- `name` — The role template name. Shown in BTP Cockpit.
- `scope-references` — Array of scopes this role template grants. Can include **multiple scopes**.
- Each scope reference must match a scope defined in the `scopes` array above.

---

### Step 1.3: Create Role Collections

**File:** `xs-security.json` → `role-collections` array

Role collections are what you **assign to actual users** in BTP Cockpit. You cannot assign scopes or role templates directly — only role collections.

```json
"role-collections": [
  {
    "name": "MyApp_Admin",
    "description": "Administrators of the application",
    "role-template-references": [
      "$XSAPPNAME.Admin"
    ]
  },
  {
    "name": "MyApp_Viewer",
    "description": "Read-only users",
    "role-template-references": [
      "$XSAPPNAME.Viewer"
    ]
  },
  {
    "name": "MyApp_Editor",
    "description": "Content editors",
    "role-template-references": [
      "$XSAPPNAME.Editor"
    ]
  }
]
```

**Rules:**
- `name` — Must be **unique across the entire BTP subaccount** (not just your app). Prefix with your app name to avoid collisions.
- `role-template-references` — Uses format `$XSAPPNAME.RoleTemplateName`.
- A single role collection can include **multiple role templates** from the same or different apps.

---

### Step 1.4: Advanced — Bundling Multiple Scopes

You can create a role template that includes multiple scopes. For example, a `Manager` who gets both `Viewer` and `Editor` access:

```json
"role-templates": [
  {
    "name": "Manager",
    "description": "Can view and edit content",
    "scope-references": [
      "$XSAPPNAME.Viewer",
      "$XSAPPNAME.Editor"
    ]
  }
]
```

When a user with this role template makes a request, their JWT token will contain **both** `Viewer` and `Editor` scopes. CAP will then allow any operation granted to **either** role in `@restrict`.

Similarly, a role collection can bundle multiple role templates:

```json
"role-collections": [
  {
    "name": "MyApp_SuperUser",
    "description": "Full access — all roles combined",
    "role-template-references": [
      "$XSAPPNAME.Admin",
      "$XSAPPNAME.Viewer",
      "$XSAPPNAME.Editor"
    ]
  }
]
```

---

### Step 1.5: Advanced — Attribute-Based Scoping

You can add **custom attributes** to restrict access further (e.g., by region or department):

```json
"attributes": [
  {
    "name": "Region",
    "description": "Geographical region",
    "valueType": "string"
  }
],
"role-templates": [
  {
    "name": "RegionalViewer",
    "description": "Can view books in their region only",
    "scope-references": ["$XSAPPNAME.Viewer"],
    "attribute-references": [
      {
        "name": "Region"
      }
    ]
  }
]
```

When an admin creates a role from this template in BTP Cockpit, they must specify the Region value (e.g., `EU`, `US`). This value then appears in the JWT token and can be used in CDS `@restrict` `where` clauses (covered in Phase 2).

---

## 3. Phase 2: ENFORCE Roles

This phase defines **what each role is allowed to do** inside your CAP application.

---

### Step 2.1: Service-Level Guard

**File:** `srv/cat-service.cds`

The first line of defense — block unauthenticated access to the entire service:

```cds
service CatalogService @(requires: 'authenticated-user') {
  // All entities inside are protected
}
```

**All possible values for `@requires`:**

| Value | Meaning |
|---|---|
| `'authenticated-user'` | Any logged-in user (has a valid JWT). Most common. |
| `'system-user'` | Technical user (service-to-service communication). |
| `'internal-user'` | Internal CAP-to-CAP calls only. |
| `'any'` | No authentication needed (public access). **Removes all protection.** |
| `'Admin'` | Only users with the `Admin` role can access the service at all. |
| `['Admin', 'Viewer']` | Users with `Admin` OR `Viewer` can access. |

**Example — different services with different guards:**

```cds
// Public catalog — anyone can browse
service PublicCatalogService @(requires: 'any') {
  @readonly entity Books as projection on db.Books;
}

// Admin service — only admins
service AdminService @(requires: 'Admin') {
  entity Books as projection on db.Books;
  entity Users as projection on db.Users;
}
```

---

### Step 2.2: Entity-Level Restrictions

**File:** `srv/cat-service.cds`

`@restrict` is where you define fine-grained permissions per entity:

```cds
service CatalogService @(requires: 'authenticated-user') {

  @(restrict: [
    { grant: '*',               to: 'Admin'  },
    { grant: 'READ',            to: 'Viewer' },
    { grant: ['READ', 'WRITE'], to: 'Editor' }
  ])
  entity Books as projection on db.Books;
}
```

**Anatomy of a `@restrict` rule:**

```
{ grant: <operation(s)>,  to: <role(s)>,  where: <optional filter> }
```

- **`grant`** — What operations are allowed. Single string or array.
- **`to`** — Which role(s) this rule applies to. Single string or array.
- **`where`** — Optional CQL condition for instance-based filtering.

**Multiple roles in one rule:**

```cds
// Both Admin and Editor can do full CRUD
{ grant: '*', to: ['Admin', 'Editor'] }
```

**Multiple rules are OR-ed:**

```cds
@(restrict: [
  { grant: 'READ',   to: 'Viewer' },
  { grant: 'CREATE', to: 'Editor' },
  { grant: 'UPDATE', to: 'Editor' },
  { grant: '*',      to: 'Admin'  }
])
```

CAP checks: "Does ANY rule match the current (operation, role) pair?" If yes → allow.

---

### Step 2.3: All Possible Grant Values

| Grant Value | OData Operation | HTTP Method | Description |
|---|---|---|---|
| `'READ'` | Query / Read | `GET` | Retrieve entities |
| `'CREATE'` | Create | `POST` | Insert new entities |
| `'UPDATE'` | Update | `PATCH` / `PUT` | Modify existing entities |
| `'DELETE'` | Delete | `DELETE` | Remove entities |
| `'WRITE'` | — | — | Shorthand for `CREATE` + `UPDATE` + `DELETE` |
| `'*'` | — | — | Shorthand for `READ` + `CREATE` + `UPDATE` + `DELETE` (everything) |

**Equivalences:**

```cds
// These two are identical:
{ grant: '*', to: 'Admin' }
{ grant: ['READ', 'CREATE', 'UPDATE', 'DELETE'], to: 'Admin' }

// These two are identical:
{ grant: 'WRITE', to: 'Editor' }
{ grant: ['CREATE', 'UPDATE', 'DELETE'], to: 'Editor' }

// READ + WRITE = everything = *
{ grant: ['READ', 'WRITE'], to: 'Manager' }
// is the same as:
{ grant: '*', to: 'Manager' }
```

---

### Step 2.4: Advanced — Field-Level Restrictions

You can restrict which fields a role can write to:

```cds
@(restrict: [
  { grant: 'READ',   to: 'Viewer' },
  {
    grant: 'UPDATE',
    to: 'Editor',
    // Editor can only update title and author, NOT the ID
    grant.fields: ['title', 'author']
  },
  { grant: '*', to: 'Admin' }
])
entity Books as projection on db.Books;
```

> ⚠️ **Compatibility note:** The `grant.fields` syntax is relatively advanced and its behavior can vary between CAP versions. In some older versions (`@sap/cds` < v7) or certain edge cases, field-level restrictions may not be fully enforced. **Always test this thoroughly** with your specific CAP version before relying on it for security. If in doubt, enforce field-level checks programmatically in a JS handler instead (see Step 2.6).

---

### Step 2.5: Advanced — Where Clauses

Instance-based authorization — restrict access to specific rows:

```cds
@(restrict: [
  {
    grant: 'READ',
    to: 'RegionalViewer',
    // Can only read books where the region matches the user's Region attribute
    where: 'region = $user.Region'
  },
  { grant: '*', to: 'Admin' }
])
entity Books as projection on db.Books;
```

- `$user.Region` reads the `Region` attribute from the JWT token (set via XSUAA attributes).
- `$user` gives access to: `$user.id`, `$user.tenant`, and any custom XSUAA attributes.

---

### Step 2.6: Advanced — Programmatic Enforcement in JS

Sometimes annotations aren't enough. You can enforce roles in a custom service handler:

**File:** `srv/cat-service.js`

```js
const cds = require('@sap/cds');

module.exports = class CatalogService extends cds.ApplicationService {

  init() {
    const { Books } = this.entities;

    // Before any modification, check for specific role
    this.before(['CREATE', 'UPDATE', 'DELETE'], Books, (req) => {
      // req.user.is('RoleName') checks if the user has that role
      if (!req.user.is('Admin') && !req.user.is('Editor')) {
        req.reject(403, 'You do not have permission to modify books');
      }
    });

    // Custom logic — Admins can delete, Editors cannot
    this.before('DELETE', Books, (req) => {
      if (!req.user.is('Admin')) {
        req.reject(403, 'Only Admins can delete books');
      }
    });

    // Access user info
    this.on('READ', Books, async (req, next) => {
      console.log('User ID:', req.user.id);
      console.log('User roles:', req.user.roles);  // { Admin: true } or { Viewer: true }
      console.log('Is Admin?', req.user.is('Admin'));
      console.log('User attr:', req.user.attr);  // Custom XSUAA attributes
      return next();  // Continue with default READ handling
    });

    return super.init();
  }
};
```

**Key `req.user` APIs:**

| API | Returns | Description |
|---|---|---|
| `req.user.id` | `string` | Username / email |
| `req.user.is('Admin')` | `boolean` | Check if user has a specific role |
| `req.user.roles` | `object` | All roles as `{ RoleName: true }` |
| `req.user.attr` | `object` | Custom XSUAA attributes |
| `req.user.tenant` | `string` | Tenant ID (multi-tenant apps) |
| `req.user.tokenInfo` | `object` | Full decoded JWT token (production only) |

---

### Step 2.7: Wire Up Auth in package.json

**File:** `package.json` → `cds.requires.auth`

```json
{
  "cds": {
    "requires": {
      "auth": {
        "[production]": {
          "kind": "xsuaa"
        },
        "[development]": {
          "kind": "mocked",
          "users": {
            "admin": {
              "password": "admin",
              "roles": ["Admin"]
            },
            "viewer": {
              "password": "viewer",
              "roles": ["Viewer"]
            },
            "editor": {
              "password": "editor",
              "roles": ["Editor"]
            },
            "norole": {
              "password": "norole",
              "roles": []
            }
          }
        }
      }
    }
  }
}
```

**Important notes:**
- The `roles` array in mock users must contain the **exact same strings** used in CDS `@restrict → to:`.
- Always add a user with **no roles** (`"roles": []`) — useful for testing that unauthorized access returns 403.
- A user with `"roles": []` can still authenticate (gets past `@requires: 'authenticated-user'`) but will get **403 Forbidden** on any entity with `@restrict` since no rules match.

**All available auth kinds:**

| Kind | When | Description |
|---|---|---|
| `"mocked"` | Local dev | Fake Basic Auth with hardcoded users. No XSUAA needed. |
| `"xsuaa"` | BTP production | Real JWT validation against XSUAA service instance. |
| `"ias"` | BTP with SAP IAS | Uses SAP Identity Authentication Service instead of XSUAA. |
| `"jwt"` | Custom | Generic JWT validation. Bring your own identity provider. |
| `"basic"` | Testing | Real Basic Auth against a user store. |
| `"dummy"` | Quick tests | No auth at all. Every request gets a dummy user with all roles. **Never use in production.** |

---

### Step 2.8: Add Required npm Dependency

**File:** `package.json` → `dependencies`

```json
"dependencies": {
  "@sap/cds": "^9",
  "@sap/xssec": "^4"
}
```

- **`@sap/xssec`** is **required** for production XSUAA auth. Without it, `"kind": "xsuaa"` will fail at runtime.
- For local mocked auth, `@sap/xssec` is not needed but it's good practice to have it in your dependencies from the start.

---

## 4. Phase 3: VERIFY Roles

---

### Step 3.1: Local Verification (Mocked Auth)

Start the CAP server:

```bash
cd your-project
cds serve
```

You should see in the terminal output:

```
[cds] - using auth strategy {
  kind: 'mocked',
  ...
}
```

This confirms mocked auth is active. The server is at `http://localhost:4004`.

---

### Step 3.2: Verify via Browser

**Test 1: Unauthenticated → 401**

1. Open `http://localhost:4004/odata/v4/catalog/Books`
2. Browser shows a username/password popup (Basic Auth).
3. Click **Cancel**.
4. You get: `401 Unauthorized`.

✅ Proves `@(requires: 'authenticated-user')` is working.

**Test 2: Viewer can READ → 200**

1. Open `http://localhost:4004/odata/v4/catalog/Books`
2. Enter: username = `viewer`, password = `viewer`
3. You see the Books JSON data.

✅ Proves `{ grant: 'READ', to: 'Viewer' }` is working.

**Test 3: No-role user gets 403**

1. Open an incognito/private window (clears cached credentials).
2. Go to `http://localhost:4004/odata/v4/catalog/Books`
3. Enter: username = `norole`, password = `norole`
4. You get: `403 Forbidden`.

✅ Proves that authentication alone isn't enough — you also need the right role.

> **Note:** Browsers cache Basic Auth credentials for the session. To switch users, you must:
> - Open a new incognito/private window, OR
> - Close and reopen the browser, OR
> - Use curl/REST Client instead (much easier for testing).

---

### Step 3.3: Verify via curl

curl lets you send different credentials easily without browser caching issues.

**Test 1: No credentials → 401**

```bash
curl -i http://localhost:4004/odata/v4/catalog/Books
```

Expected: `HTTP/1.1 401 Unauthorized`

**Test 2: Viewer READ → 200**

```bash
curl -u viewer:viewer http://localhost:4004/odata/v4/catalog/Books
```

Expected: `HTTP/1.1 200 OK` with JSON data.

**Test 3: Viewer CREATE → 403**

```bash
curl -u viewer:viewer \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"ID": 10, "title": "Test Book", "author": "Test"}' \
  http://localhost:4004/odata/v4/catalog/Books
```

Expected: `HTTP/1.1 403 Forbidden`

**Test 4: Admin CREATE → 201**

```bash
curl -u admin:admin \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"ID": 10, "title": "Test Book", "author": "Test"}' \
  http://localhost:4004/odata/v4/catalog/Books
```

Expected: `HTTP/1.1 201 Created`

**Test 5: Admin DELETE → 204**

```bash
curl -u admin:admin \
  -X DELETE \
  http://localhost:4004/odata/v4/catalog/Books(10)
```

Expected: `HTTP/1.1 204 No Content`

**Test 6: Viewer DELETE → 403**

```bash
curl -u viewer:viewer \
  -X DELETE \
  http://localhost:4004/odata/v4/catalog/Books(1)
```

Expected: `HTTP/1.1 403 Forbidden`

**Complete test matrix:**

| User | READ | CREATE | UPDATE | DELETE |
|---|---|---|---|---|
| (none) | 401 | 401 | 401 | 401 |
| norole | 403 | 403 | 403 | 403 |
| viewer | ✅ 200 | ❌ 403 | ❌ 403 | ❌ 403 |
| editor | ✅ 200 | ✅ 201 | ✅ 200 | ❌ 403 |
| admin | ✅ 200 | ✅ 201 | ✅ 200 | ✅ 204 |

---

### Step 3.4: Verify via REST Client (VS Code)

Install the **REST Client** extension in VS Code (`humao.rest-client`). Create a file called `test.http`:

```http
### 1. No auth → 401
GET http://localhost:4004/odata/v4/catalog/Books

### 2. Viewer READ → 200
GET http://localhost:4004/odata/v4/catalog/Books
Authorization: Basic dmlld2VyOnZpZXdlcg==

### 3. Viewer CREATE → 403
POST http://localhost:4004/odata/v4/catalog/Books
Authorization: Basic dmlld2VyOnZpZXdlcg==
Content-Type: application/json

{"ID": 10, "title": "Test Book", "author": "Test"}

### 4. Admin CREATE → 201
POST http://localhost:4004/odata/v4/catalog/Books
Authorization: Basic YWRtaW46YWRtaW4=
Content-Type: application/json

{"ID": 10, "title": "Test Book", "author": "Test"}

### 5. Admin DELETE → 204
DELETE http://localhost:4004/odata/v4/catalog/Books(10)
Authorization: Basic YWRtaW46YWRtaW4=

### 6. Viewer DELETE → 403
DELETE http://localhost:4004/odata/v4/catalog/Books(1)
Authorization: Basic dmlld2VyOnZpZXdlcg==
```

**How to get the Base64 strings:**

```bash
# viewer:viewer in Base64
echo -n "viewer:viewer" | base64
# Output: dmlld2VyOnZpZXdlcg==

# admin:admin in Base64
echo -n "admin:admin" | base64
# Output: YWRtaW46YWRtaW4=

# editor:editor in Base64
echo -n "editor:editor" | base64
# Output: ZWRpdG9yOmVkaXRvcg==
```

Click **"Send Request"** above each section in the `.http` file to execute it.

---

### Step 3.5: Verify on BTP (Production)

After deploying to SAP BTP Cloud Foundry:

**Step A: Create the XSUAA service instance**

The `xs-security.json` is used when creating the service instance:

```bash
cf create-service xsuaa application my-app-xsuaa -c xs-security.json
```

Or if using MTA deployment, the `mta.yaml` handles this automatically.

**Step B: Assign Role Collections to users**

1. Go to **SAP BTP Cockpit** → your subaccount.
2. Navigate to **Security → Role Collections**.
3. You'll see `MyApp_Admin` and `MyApp_Viewer` (created from xs-security.json).
4. Click on a role collection → **Edit** → **Users** tab.
5. Add a user by their **email / IDP username**.
6. **Save**.

```
BTP Cockpit
└── Security
    └── Role Collections
        ├── MyApp_Admin
        │   └── Users: admin@company.com
        └── MyApp_Viewer
            └── Users: viewer@company.com
```

**Step C: Test the deployed app**

1. Open your app URL (via App Router or directly).
2. You'll be redirected to XSUAA login.
3. Log in with a user that has a role collection assigned.
4. Access is granted/denied based on the role.

**Step D: Verify role collection assignment**

```bash
# List all role collections in the subaccount
cf curl "/sap/rest/authorization/v2/rolecollections"

# Check a specific user's role collections
cf curl "/sap/rest/authorization/v2/users/{userId}/rolecollections"
```

---

### Step 3.6: Decode & Inspect JWT Tokens

In production, you can inspect what's inside a user's JWT to verify the roles.

**Option A: From the browser (after login)**

In your browser's DevTools → Network tab → find a request to your API → look at the `Authorization` header. It contains `Bearer <token>`. Copy the token.

**Option B: Decode with jwt.io**

1. Go to [https://jwt.io](https://jwt.io)
2. Paste the JWT token.
3. Look at the **payload** section. You'll see something like:

```json
{
  "sub": "john@company.com",
  "scope": [
    "backend-xsuaa-demo.Admin",
    "backend-xsuaa-demo.Viewer"
  ],
  "client_id": "sb-backend-xsuaa-demo",
  "iss": "https://your-subdomain.authentication.eu10.hana.ondemand.com",
  "exp": 1735689600
}
```

The `scope` array shows which XSUAA scopes the user has. CAP strips the `xsappname.` prefix and uses the remainder as role names.

**Option C: Decode with command line**

```bash
# Decode JWT payload (middle part between the two dots)
echo "eyJhbGciOiJSUzI1NiIs..." | cut -d'.' -f2 | base64 -d | jq .
```

---

### Step 3.7: Verify Programmatically in Handler

Add debug logging to your service handler to see exactly what CAP knows about the user:

**File:** `srv/cat-service.js`

```js
const cds = require('@sap/cds');

module.exports = class CatalogService extends cds.ApplicationService {
  init() {
    // Log user info on every request
    this.before('*', (req) => {
      console.log('═══════════════════════════════════════');
      console.log('  User ID:    ', req.user.id);
      console.log('  Roles:      ', JSON.stringify(req.user.roles));
      console.log('  Is Admin?   ', req.user.is('Admin'));
      console.log('  Is Viewer?  ', req.user.is('Viewer'));
      console.log('  Is Editor?  ', req.user.is('Editor'));
      console.log('  Attributes: ', JSON.stringify(req.user.attr));
      console.log('  Event:      ', req.event);  // READ, CREATE, UPDATE, DELETE
      console.log('  Target:     ', req.target?.name);
      console.log('═══════════════════════════════════════');
    });

    return super.init();
  }
};
```

Now when you send a request, the terminal will show:

```
═══════════════════════════════════════
  User ID:     viewer
  Roles:       {"Viewer":true,"authenticated-user":true,"any":true}
  Is Admin?    false
  Is Viewer?   true
  Is Editor?   false
  Attributes:  {}
  Event:       READ
  Target:      CatalogService.Books
═══════════════════════════════════════
```

This confirms exactly what role the user has and what operation they're attempting.

---

## 5. Quick Reference

### Adding a brand new role called "Auditor" that can only READ:

**Step 1:** Add scope in `xs-security.json`:

```json
// In "scopes" array, add:
{ "name": "$XSAPPNAME.Auditor", "description": "Audit access" }
```

**Step 2:** Add role template in `xs-security.json`:

```json
// In "role-templates" array, add:
{ "name": "Auditor", "scope-references": ["$XSAPPNAME.Auditor"] }
```

**Step 3:** Add role collection in `xs-security.json`:

```json
// In "role-collections" array, add:
{ "name": "MyApp_Auditor", "role-template-references": ["$XSAPPNAME.Auditor"] }
```

**Step 4:** Add restriction in `srv/cat-service.cds`:

```cds
@(restrict: [
  { grant: '*',    to: 'Admin'   },
  { grant: 'READ', to: 'Viewer'  },
  { grant: 'READ', to: 'Auditor' }   // ← new rule
])
entity Books as projection on db.Books;
```

**Step 5:** Add mock user in `package.json`:

```json
"auditor": {
  "password": "auditor",
  "roles": ["Auditor"]
}
```

**Step 6:** Verify:

```bash
curl -u auditor:auditor http://localhost:4004/odata/v4/catalog/Books
# → 200 OK

curl -u auditor:auditor -X POST -H "Content-Type: application/json" \
  -d '{"ID":99,"title":"X","author":"Y"}' \
  http://localhost:4004/odata/v4/catalog/Books
# → 403 Forbidden
```

---

## 6. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `401` for all requests | Service has `@requires` but no valid credentials sent | Check username/password in mock config |
| `403` even with correct user | Role name mismatch between CDS and mock config | Ensure `to: 'Admin'` in CDS matches `"roles": ["Admin"]` in package.json — case-sensitive! |
| `403` on BTP even after assigning role collection | User hasn't re-logged after assignment | User must log out and log back in to get a fresh JWT with the new scopes |
| No auth popup in browser | `@requires: 'any'` set, or `kind: "dummy"` in config | Check package.json auth config |
| `500` error about missing `@sap/xssec` | Running in production without the dependency | Run `npm install @sap/xssec` |
| Auth works locally but not on BTP | Mock roles don't match XSUAA scope names | The part after `$XSAPPNAME.` must exactly match the CDS role names |
| Role collection not visible in BTP Cockpit | `xs-security.json` not applied | Re-create or update the XSUAA service instance: `cf update-service my-xsuaa -c xs-security.json` |
