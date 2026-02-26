# 📸 Image Upload in SAP CAP Fiori Elements — Complete Step-by-Step Guide

> This guide explains how to add an "Upload Image" feature to a **CAP (Cloud Application Programming Model)** project with a **SAP Fiori Elements List Report + Object Page** frontend.
>
> It covers everything from the database schema to the UI controller logic. Each step explains **what**, **why**, and **how**.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Prerequisites](#2-prerequisites)
3. [Step 1: Database Schema — Add Image Fields](#3-step-1-database-schema--add-image-fields)
4. [Step 2: Service Layer — Expose Image Fields](#4-step-2-service-layer--expose-image-fields)
5. [Step 3: Increase Request Body Size Limit](#5-step-3-increase-request-body-size-limit)
6. [Step 4: CDS Annotations — Image Metadata](#6-step-4-cds-annotations--image-metadata)
7. [Step 5: CDS Annotations — Display Image in Header](#7-step-5-cds-annotations--display-image-in-header)
8. [Step 6: Add Custom Action Button via Page Map](#8-step-6-add-custom-action-button-via-page-map)
9. [Step 7: Create the Upload Dialog Fragment (XML)](#9-step-7-create-the-upload-dialog-fragment-xml)
10. [Step 8: Write the Upload Controller Logic (JS)](#10-step-8-write-the-upload-controller-logic-js)
11. [Step 9: Test the Feature](#11-step-9-test-the-feature)
12. [Appendix: How It All Connects](#12-appendix-how-it-all-connects)
13. [Appendix: Troubleshooting](#13-appendix-troubleshooting)

---

## 1. Architecture Overview

The image upload feature works across **four layers**:

```
┌──────────────────────────────────────────────────────────┐
│  BROWSER (Fiori Elements UI)                             │
│                                                          │
│  ┌─────────────┐   ┌──────────────────┐                  │
│  │ Upload      │──>│ UploadController │                  │
│  │ Button      │   │ (JS)             │                  │
│  │ (manifest)  │   │                  │                  │
│  └─────────────┘   │ 1. Opens dialog  │                  │
│                    │ 2. Reads file    │                  │
│  ┌─────────────┐   │ 3. Converts to   │                  │
│  │ Dialog      │<──│    Base64        │                  │
│  │ Fragment    │   │ 4. Sets props on │                  │
│  │ (XML)       │   │    draft context │                  │
│  └─────────────┘   └────────┬─────────┘                  │
│                              │                           │
│                    setProperty("image", base64Data)      │
│                    setProperty("imageType", "image/png") │
│                    setProperty("imageName", "photo.png") │
│                              │                           │
├──────────────────────────────┼───────────────────────────┤
│  OData V4 PATCH request      │                           │
│  (sent on Save/Activate)     ▼                           │
├──────────────────────────────────────────────────────────┤
│  CAP SERVICE LAYER (cat-service.cds)                     │
│                                                          │
│  - Exposes Products entity with image fields             │
│  - Draft-enabled (creates draft on Edit, activates       │
│    on Save)                                              │
│  - body_parser.limit = "10mb" (allows large payloads)    │
│                                                          │
├──────────────────────────────────────────────────────────┤
│  DATABASE (schema.cds → SQLite/HANA)                     │
│                                                          │
│  Products table:                                         │
│  - image     : LargeBinary (stores raw image bytes)      │
│  - imageType : String      (stores MIME type)            │
│  - imageName : String      (stores file name)            │
│                                                          │
│  + a DRAFT shadow table (auto-created by CAP)            │
└──────────────────────────────────────────────────────────┘
```

### How it flows:

1. User clicks **Edit** → CAP creates a **draft** copy of the entity
2. User clicks **Upload Image** → dialog opens
3. User picks a file → JS reads it as **Base64** via `FileReader`
4. JS calls `oContext.setProperty("image", base64)` → sends a **PATCH** to the **draft** entity
5. User clicks **Save** → CAP **activates** the draft → data moves to the real entity
6. The Object Page header shows the image via `UI.HeaderInfo > ImageUrl`

---

## 2. Prerequisites

Before starting, ensure you have:

- A **CAP project** with `@sap/cds` dependency
- A **Fiori Elements List Report + Object Page** app (generated via Fiori tools)
- **Draft enabled** on your target entity (`@odata.draft.enabled`)
- **SQLite** (for local dev) or **HANA** (for production) as the database

### Why is Draft required?

The upload controller uses `oContext.setProperty()` to write data. This only works on a **draft entity** (an entity in edit mode). Without draft:
- There's no "Edit" button, so no edit session
- `setProperty()` would attempt a direct PATCH on the active entity, which CAP blocks by default
- There's no Cancel/Discard safety net
- Multiple `setProperty()` calls (image + imageType + imageName) won't be atomic

---

## 3. Step 1: Database Schema — Add Image Fields

### File: `db/schema.cds`

You need **three fields** on your entity:

```cds
entity Products : cuid, managed {
    // ... your existing fields ...

    // The actual image binary data
    // @Core.MediaType tells CAP: "the MIME type for this binary is stored in the 'imageType' field"
    // @Core.ContentDisposition.Filename tells CAP: "the filename is stored in the 'imageName' field"
    image     : LargeBinary @Core.MediaType: imageType
                            @Core.ContentDisposition.Filename: imageName;

    // Stores the MIME type string, e.g. "image/png", "image/jpeg"
    // @Core.IsMediaType tells CAP: "this field holds a MIME type"
    // CAP uses this to set the Content-Type header when serving the image
    imageType : String      @Core.IsMediaType: true;

    // Stores the original file name, e.g. "photo.png"
    imageName : String;
}
```

### What each annotation does at the schema level:

| Annotation | On Field | Purpose |
|---|---|---|
| `@Core.MediaType: imageType` | `image` | Links the binary field to its MIME type companion field. CAP uses this to generate proper OData `$metadata` with `HasStream` semantics. |
| `@Core.ContentDisposition.Filename: imageName` | `image` | Links the binary field to its filename companion field. Used when the image is downloaded — sets the `Content-Disposition` HTTP header. |
| `@Core.IsMediaType: true` | `imageType` | Marks this field as a MIME type holder. CAP includes this in the OData metadata so clients know which field describes the media type. |

### Important notes:

- `LargeBinary` maps to `BLOB` in SQLite and `NCLOB`/`BLOB` in HANA
- The Base64-encoded image is sent as a string in the OData PATCH request, and CAP automatically decodes it to binary for storage
- These three fields work as a **set** — you always need all three together

---

## 4. Step 2: Service Layer — Expose Image Fields

### File: `srv/cat-service.cds`

Your service must:
1. **Project the image fields** (either via `*` or explicitly)
2. **Enable draft** on the entity

```cds
using my.company as my from '../db/schema';

service CatalogService {
    entity Products as projection on my.Products {
        *    // <-- This includes image, imageType, imageName automatically
             //     You could also list them explicitly:
             //     image, imageType, imageName, ProductName, ...
    };
}

// CRITICAL: Draft must be enabled for the upload to work
// This creates a shadow DRAFT table and enables the Edit/Save/Cancel lifecycle
annotate CatalogService.Products with @odata.draft.enabled;
```

### Why draft is critical (recap):

- Without draft, clicking Edit doesn't create an editable copy
- `setProperty()` in the controller modifies a **draft** entity
- The user can Cancel (discards the draft) or Save (activates the draft → writes to real table)
- All three property changes (image + imageType + imageName) are saved atomically on activation

---

## 5. Step 3: Increase Request Body Size Limit

### File: `package.json` (project root)

An image file grows ~33% when Base64-encoded (e.g., 85KB file → ~113KB payload). CAP's default body parser limit is too small for this.

Add to your root `package.json`:

```json
{
  "name": "your-project",
  "dependencies": { ... },
  "devDependencies": { ... },

  "cds": {
    "server": {
      "body_parser": {
        "limit": "10mb"
      }
    }
  }
}
```

### Why 10mb?

- Our fragment says "Max 5MB" for user uploads
- 5MB file × 1.33 (Base64 inflation) ≈ 6.65MB payload
- 10MB gives comfortable headroom
- You can adjust this based on your needs

### Important:

- This is a **server-side** config — you must **restart the CAP server** after changing it
- This only affects the CDS server's Express body parser, not any CDN or reverse proxy limits
- In production (Cloud Foundry / BTP), you may also need to configure the app router's body limit

---

## 6. Step 4: CDS Annotations — Image Metadata

### File: `app/<your-app>/annotations.cds`

These annotations tell the **Fiori Elements frontend** how to handle the image field:

```cds
using CatalogService as service from '../../srv/cat-service';

// Tell the UI framework about the image field's nature
annotate service.Products with {

    // UI.IsImageURL: false
    //   → Tells Fiori Elements: "The 'image' field contains RAW BINARY DATA,
    //     not a URL string."
    //   → Without this, the framework might try to put the Base64 string
    //     directly into an <img src="...">, which would break.
    //   → With this set to false, it knows to handle it as binary content
    //     and construct the proper data URI internally.
    //
    // Core.AcceptableMediaTypes
    //   → Declares which MIME types this field accepts.
    //   → Used for client-side validation and OData metadata.
    //   → If someone tries to upload a PDF, the framework can reject it.
    image @(
        UI.IsImageURL            : false,
        Core.AcceptableMediaTypes : ['image/jpeg', 'image/jpg', 'image/png', 'image/gif']
    );
};
```

### Can these be placed in `schema.cds` instead?

- `Core.AcceptableMediaTypes` → Yes, but it's a UI concern, so `annotations.cds` is conventional
- `UI.IsImageURL` → No, this is a **UI-only** annotation, has no meaning at the DB level
- `Core.IsMediaType` on `imageType` → Already in `schema.cds`, no need to repeat (CAP propagates it to the OData metadata automatically)

### What happens without these annotations?

- Without `UI.IsImageURL: false` → The header might show a broken image or raw text
- Without `Core.AcceptableMediaTypes` → No client-side MIME type validation (our JS controller still validates, but the OData layer won't)

---

## 7. Step 5: CDS Annotations — Display Image in Header

### File: `app/<your-app>/annotations.cds`

To show the uploaded image in the **Object Page header** (as an avatar/thumbnail):

```cds
annotate service.Products with @(
    UI.HeaderInfo : {
        Title : {
            $Type : 'UI.DataField',
            Value : ProductName,           // The main title
        },
        TypeName       : 'Product',
        TypeNamePlural : 'Products',
        Description : {
            $Type : 'UI.DataField',
            Value : category.CategoryName, // Subtitle
        },

        // THIS IS THE KEY LINE:
        // ImageUrl tells Fiori Elements to display this field as the
        // header avatar/thumbnail image.
        // It works with both URL strings and binary data (when UI.IsImageURL: false is set)
        ImageUrl : image,
    },
);
```

### What `ImageUrl : image` does:

- Renders a circular avatar in the top-left of the Object Page header
- When no image is uploaded → shows a generic icon (based on the entity type)
- When an image exists → shows the image as a circular thumbnail
- The framework automatically constructs the correct `src` attribute based on whether the data is a URL or binary

### Can I show the image elsewhere?

Yes, you can also show it in:

- **List Report table** → Add `{ $Type: 'UI.DataField', Value: image }` to `UI.LineItem`
  (It will show as a small thumbnail in the table row)
- **A FieldGroup** → Add it to any `UI.FieldGroup` to show in the Object Page body
- **A custom section** → Use a custom fragment to render it however you want

---

## 8. Step 6: Add Custom Action Button via Page Map

This step adds the **"Upload Image"** button to the Object Page header.

### Using SAP Fiori Tools Page Map (recommended):

1. Open **Command Palette** (`Ctrl+Shift+P`) → **"Fiori: Show Page Map"**
2. Click the **pencil icon (✏️)** on the **Object Page** tile
3. Find the **Header** section → **Actions**
4. Click **"+" (Add)** → **"Add Custom Action"**
5. Fill in:
   - **Action ID**: `uploadImage`
   - **Button Text**: `Upload Image`
   - **Handler File**: `ext/controller/UploadController.js` (auto-suggested)
   - **Handler Function**: `onUploadImage`
   - **Placement**: `Before`
   - **Anchor**: `EditAction`
6. Click **Add**

### What Page Map generates:

**In `webapp/manifest.json`** (under `ProductsObjectPage` target):

```json
"content": {
  "header": {
    "actions": {
      "uploadImage": {
        "press": "your.app.id.ext.controller.UploadController.onUploadImage",
        "visible": "{ui>/isEditable}",
        "enabled": true,
        "text": "Upload Image",
        "position": {
          "placement": "Before",
          "anchor": "EditAction"
        }
      }
    }
  }
}
```

**In `webapp/ext/controller/UploadController.js`** (a stub):

```javascript
sap.ui.define(["sap/m/MessageToast"], function(MessageToast) {
    'use strict';
    return {
        onUploadImage: function(oContext, aSelectedContexts) {
            MessageToast.show("Custom handler invoked.");
        }
    };
});
```

### Manual adjustments after Page Map:

1. Change `"visible": true` to `"visible": "{ui>/isEditable}"` in manifest.json
   - This hides the button when NOT in edit mode
   - The `{ui>/isEditable}` binding is a built-in Fiori Elements model that reflects the edit state
   - Alternatively, use `"enabled": "{ui>/isEditable}"` with `"visible": true` to show a grayed-out button

2. Replace the stub controller with the real upload logic (Step 8)

### Understanding the manifest action config:

| Property | Value | Purpose |
|---|---|---|
| `press` | `"your.app.id.ext.controller.UploadController.onUploadImage"` | Fully qualified path to the handler function. Uses the app's ID (from `sap.app.id` in manifest) as the module root. |
| `visible` | `"{ui>/isEditable}"` | Binds to the Fiori Elements internal `ui` model. `true` when in Edit mode, `false` in Display mode. |
| `enabled` | `true` | Whether the button is clickable (when visible). |
| `text` | `"Upload Image"` | Button label. Can use i18n: `"{i18n>UploadImage}"` |
| `position.placement` | `"Before"` | Places this button before the anchor button. Other option: `"After"`. |
| `position.anchor` | `"EditAction"` | The reference button. `"EditAction"` is the built-in Edit/Save button. |

---

## 9. Step 7: Create the Upload Dialog Fragment (XML)

### File: `webapp/ext/fragment/ImageUploadDialog.fragment.xml`

Create this file manually (Page Map cannot create fragments):

```xml
<!-- 
  This fragment defines the dialog that opens when the user clicks "Upload Image".
  It contains:
  - A FileUploader control to pick a file
  - A text showing the selected file name
  - Upload, Remove, and Cancel buttons
  
  The "." prefix on event handlers (e.g., .onFileChange) means:
  "Call this method on the controller object passed when loading this fragment"
  (NOT on the view's controller — on the custom controller object we create in JS)
-->
<core:FragmentDefinition
    xmlns="sap.m"
    xmlns:core="sap.ui.core"
    xmlns:u="sap.ui.unified">

    <!--
      Dialog: A modal popup.
      - beforeOpen: Called just before the dialog appears. We use it to bind the entity context.
      - afterClose: Called after the dialog closes. We use it to clean up (destroy dialog, reset state).
      - contentWidth: Fixed width so the dialog doesn't auto-size awkwardly.
    -->
    <Dialog
        id="imageUploadDialog"
        title="Upload Product Image"
        contentWidth="400px"
        beforeOpen=".onBeforeOpen"
        afterClose=".onAfterClose">

        <content>
            <VBox class="sapUiMediumMargin">
                <!--
                  FileUploader: The actual file picker control.
                  - From the sap.ui.unified library (hence the u: prefix).
                  - uploadOnChange="false": Do NOT auto-upload when a file is picked.
                    We handle the upload manually in our JS controller.
                  - change: Fires when the user selects a file. We validate it and store the reference.
                  - The "name" attribute is required by FileUploader but we don't use it for actual HTTP upload.
                -->
                <u:FileUploader
                    id="imageFileUploader"
                    name="file"
                    uploadUrl=""
                    uploadOnChange="false"
                    change=".onFileChange"
                    width="100%"
                    placeholder="Select Image File:" />

                <!--
                  Text: Shows the selected file name (or "No file selected").
                  Updated dynamically in onFileChange handler.
                  The id is important — the controller uses Fragment.byId() to find and update this control.
                -->
                <Text
                    id="imageSelectedFileName"
                    text="No file selected"
                    class="sapUiTinyMarginTop sapUiSmallMarginBottom" />

                <!-- Static helper text showing accepted formats -->
                <Text text="(JPG, PNG, GIF - Max 5MB)" class="sapUiTinyMarginTop" />
            </VBox>
        </content>

        <buttons>
            <!-- Upload: Reads the file, converts to Base64, sets on draft entity -->
            <Button
                text="Upload"
                type="Emphasized"
                press=".onUploadPress" />

            <!-- Remove: Clears the image data from the draft entity -->
            <Button
                text="Remove Image"
                type="Transparent"
                press=".onRemoveImage" />

            <!-- Cancel: Just closes the dialog without doing anything -->
            <Button
                text="Cancel"
                press=".onUploadCancel" />
        </buttons>

    </Dialog>

</core:FragmentDefinition>
```

### Key concepts:

**Why a Fragment and not a View?**
- Fragments are lightweight — no controller of their own, no routing
- Perfect for reusable dialog UIs
- We pass a custom controller object when loading the fragment

**Why `sap.ui.unified.FileUploader`?**
- It's SAP's standard file picker control
- Renders as a "Browse" button with a text input
- Provides the `files` array via the `change` event
- We don't use its built-in upload capability (which posts to a URL) — instead we read the file client-side

**The `id` attributes matter:**
- `imageUploadDialog` → Used to reference the dialog
- `imageFileUploader` → The file picker
- `imageSelectedFileName` → The text we update with the filename
- When loading the fragment, we use a **fragment ID** (`productImageUploadDialog`), so the actual DOM IDs become `productImageUploadDialog--imageUploadDialog`, etc.
- We use `sap.ui.core.Fragment.byId("productImageUploadDialog", "imageSelectedFileName")` to find controls within the fragment

---

## 10. Step 8: Write the Upload Controller Logic (JS)

### File: `webapp/ext/controller/UploadController.js`

Replace the Page Map stub with this:

```javascript
sap.ui.define([
    "sap/m/MessageToast"
], function(MessageToast) {
    'use strict';

    // Module-level variables to track state across the dialog lifecycle
    var oUploadDialog, oSelectedFile;

    /**
     * Creates a controller object for the upload dialog fragment.
     * 
     * WHY a factory function?
     * - Fiori Elements custom actions use a flat module pattern (return { handler: fn })
     * - But our dialog needs its own controller with multiple event handlers
     * - We can't use a proper Controller class because loadFragment() in FE
     *   extensions expects a plain object with handler methods
     * - This factory creates a closure that captures oExtAPI and oBindingContext
     * 
     * @param {object} oExtAPI - The extension API (basically 'this' from the action handler).
     *                           Provides addDependent(), removeDependent(), refresh().
     * @param {object} oBindingContext - The OData V4 context of the current entity (the Product).
     *                                   Provides setProperty() to modify draft fields.
     */
    function _createController(oExtAPI, oBindingContext) {
        return {

            /**
             * Called just before the dialog opens.
             * 
             * Two critical things happen here:
             * 1. addDependent() — Tells the Fiori Elements view that this dialog
             *    is a "dependent" control. This ensures the dialog participates in
             *    the view's model propagation (so {i18n>...} bindings work, etc.)
             * 2. setBindingContext() — Binds the product's OData context to the dialog.
             *    This is what allows oUploadDialog.getBindingContext() to work later,
             *    giving us access to the draft entity's properties.
             */
            onBeforeOpen: function(oEvent) {
                oUploadDialog = oEvent.getSource();
                oExtAPI.addDependent(oUploadDialog);
                if (oBindingContext) oUploadDialog.setBindingContext(oBindingContext);
            },

            /**
             * Called after the dialog closes (whether by Upload, Remove, or Cancel).
             * 
             * Cleanup is critical here:
             * - removeDependent() — Detaches from the view's lifecycle
             * - destroy() — Removes the dialog from the DOM and frees memory
             * - Reset variables — Prevents stale state on next open
             * 
             * WHY destroy?
             * Because loadFragment() creates a NEW dialog instance each time.
             * If we don't destroy, we'd leak DOM elements on every open/close cycle.
             */
            onAfterClose: function() {
                oExtAPI.removeDependent(oUploadDialog);
                oUploadDialog.destroy();
                oUploadDialog = undefined;
                oSelectedFile = null;
            },

            /**
             * Called when the user picks a file in the FileUploader.
             * 
             * We just store a reference to the File object and update the UI text.
             * Actual reading/upload happens in onUploadPress.
             * 
             * Note: oEvent.getParameter("files") returns a FileList (array-like).
             * We take [0] because our FileUploader only allows single file selection.
             */
            onFileChange: function(oEvent) {
                oSelectedFile = oEvent.getParameter("files")[0] || null;

                // Update the "No file selected" text with the actual filename
                // Fragment.byId(fragmentId, controlId) is how you find controls
                // inside a fragment that was loaded with a specific fragment ID
                var oText = sap.ui.core.Fragment.byId("productImageUploadDialog", "imageSelectedFileName");
                if (oText) {
                    oText.setText(oSelectedFile ? oSelectedFile.name : "No file selected");
                }
            },

            /**
             * THE CORE FUNCTION: Reads the file and writes it to the draft entity.
             * 
             * Flow:
             * 1. Get the binding context from the dialog (set in onBeforeOpen)
             * 2. Create a FileReader to read the file as a Data URL (Base64)
             * 3. Extract the Base64 string (strip the "data:image/png;base64," prefix)
             * 4. Use oContext.setProperty() to write to the draft entity
             * 
             * WHY Base64?
             * - OData doesn't have a native "file upload" mechanism for entity properties
             * - LargeBinary fields in OData accept Base64-encoded strings
             * - FileReader.readAsDataURL() gives us exactly that
             * - CAP automatically decodes Base64 back to binary for storage
             * 
             * WHY setProperty() instead of a custom action or direct PATCH?
             * - setProperty() on an OData V4 context is the standard way to modify draft fields
             * - It batches with other changes and participates in the draft lifecycle
             * - On Save (draft activation), all setProperty changes are committed together
             */
            onUploadPress: function() {
                var oCtx = oUploadDialog.getBindingContext();
                if (!oSelectedFile || !oCtx) {
                    MessageToast.show("Please select a file first");
                    return;
                }

                var reader = new FileReader();

                reader.onload = function(e) {
                    // e.target.result looks like: "data:image/png;base64,iVBORw0KGgo..."
                    // We split on comma and take the second part (pure Base64)
                    var sBase64 = e.target.result.split(',')[1];

                    // Set all three properties on the draft entity
                    // These will be sent as a PATCH request to the draft
                    oCtx.setProperty("image", sBase64);          // The actual image data
                    oCtx.setProperty("imageType", oSelectedFile.type);  // e.g. "image/png"
                    oCtx.setProperty("imageName", oSelectedFile.name);  // e.g. "photo.png"

                    MessageToast.show("Image uploaded");
                    oExtAPI.refresh();      // Refresh the page to show the new image
                    oUploadDialog.close();  // Close the dialog (triggers onAfterClose)
                };

                reader.onerror = function() {
                    MessageToast.show("Error reading file");
                };

                // Start reading the file — this is async, result comes in reader.onload
                reader.readAsDataURL(oSelectedFile);
            },

            /**
             * Clears the image from the draft entity.
             * Sets all three fields to empty strings.
             * The image will be removed when the user clicks Save.
             */
            onRemoveImage: function() {
                var oCtx = oUploadDialog.getBindingContext();
                if (!oCtx) return;
                oCtx.setProperty("image", "");
                oCtx.setProperty("imageType", "");
                oCtx.setProperty("imageName", "");
                MessageToast.show("Image removed");
                oExtAPI.refresh();
                oUploadDialog.close();
            },

            /**
             * Simply closes the dialog. No data changes.
             * onAfterClose will handle cleanup.
             */
            onUploadCancel: function() {
                oUploadDialog.close();
            }
        };
    }

    // ============================================================
    // The module's public API — this is what manifest.json points to
    // ============================================================
    return {
        /**
         * Entry point: Called when the user clicks the "Upload Image" button.
         * 
         * This is a Fiori Elements custom action handler. The framework calls it with:
         * @param {sap.ui.model.odata.v4.Context} oBindingContext 
         *        The OData context of the current entity (the Product being viewed).
         *        This is the DRAFT context when in edit mode.
         * 
         * What this function does:
         * 1. Validates that we have a context (we should, since the button is on Object Page)
         * 2. Loads the dialog fragment with our custom controller
         * 3. Opens the dialog
         * 
         * loadFragment() is a Fiori Elements extension API method that:
         * - Loads the XML fragment file
         * - Creates the UI controls
         * - Associates the given controller object with the fragment's event handlers
         * - Returns a Promise that resolves with the root control (the Dialog)
         */
        onUploadImage: function(oBindingContext) {
            if (!oBindingContext) {
                MessageToast.show("No context");
                return;
            }

            this.loadFragment({
                // Fragment ID: Used as a prefix for all control IDs inside the fragment
                // Important for Fragment.byId() to work correctly
                id: "productImageUploadDialog",

                // The fully qualified name of the fragment file
                // Maps to: webapp/ext/fragment/ImageUploadDialog.fragment.xml
                // Uses the app's module namespace (from sap.app.id in manifest.json)
                // YOUR_APP_ID.ext.fragment.ImageUploadDialog
                name: "sap.practice.lrpop.ext.fragment.ImageUploadDialog",
                //    ^^^^^^^^^^^^^^^^^^
                //    Replace this with YOUR app's sap.app.id from manifest.json

                // The controller object whose methods will handle fragment events
                controller: _createController(this, oBindingContext)
            }).then(function(oDialog) {
                oDialog.open();
            });
        }
    };
});
```

### The one thing you MUST customize:

In the `loadFragment()` call, the `name` property must match YOUR app's ID:

```javascript
// Find your app ID in manifest.json → sap.app → id
// Example: if your sap.app.id is "com.mycompany.products"
// Then: name: "com.mycompany.products.ext.fragment.ImageUploadDialog"

name: "<YOUR_SAP_APP_ID>.ext.fragment.ImageUploadDialog"
```

---

## 11. Step 9: Test the Feature

### Start the server:

```bash
npm run start
# or
cds watch
```

### Test flow:

1. Open the app in browser (e.g., `http://localhost:4004/sap.practice.lrpop/index.html`)
2. Navigate to a **Product** (click a row in the List Report)
3. You're on the **Object Page** in display mode
4. Click **Edit** → enters draft/edit mode
5. The **"Upload Image"** button appears (it's hidden in display mode)
6. Click **Upload Image** → dialog opens
7. Click **Browse** → pick a JPG/PNG/GIF file (< 5MB)
8. The filename appears in the dialog
9. Click **Upload** → "Image uploaded" toast message
10. The image appears in the header avatar
11. Click **Save** → draft is activated, image is persisted

### Verify the image is saved:

- Navigate away and come back — the image should still show in the header
- Check the List Report — if you have `image` in `UI.LineItem`, it shows as a thumbnail

---

## 12. Appendix: How It All Connects

### File relationship map:

```
db/schema.cds
  └── Defines: image (LargeBinary), imageType (String), imageName (String)
  └── Annotations: @Core.MediaType, @Core.IsMediaType, @Core.ContentDisposition.Filename
        │
        ▼
srv/cat-service.cds
  └── Projects: * (includes all image fields)
  └── Enables: @odata.draft.enabled
        │
        ▼
app/<app>/annotations.cds
  └── UI.HeaderInfo.ImageUrl: image  ← renders image in header
  └── image @UI.IsImageURL: false    ← tells UI it's binary, not a URL
  └── image @Core.AcceptableMediaTypes ← allowed MIME types
        │
        ▼
app/<app>/webapp/manifest.json
  └── ObjectPage target → content.header.actions.uploadImage
  └── Points to: ext/controller/UploadController.onUploadImage
  └── visible: "{ui>/isEditable}" ← only in edit mode
        │
        ▼
app/<app>/webapp/ext/controller/UploadController.js
  └── onUploadImage() → loads fragment → opens dialog
  └── onUploadPress() → FileReader → Base64 → setProperty()
        │
        ▼
app/<app>/webapp/ext/fragment/ImageUploadDialog.fragment.xml
  └── Dialog with FileUploader, buttons
  └── Event handlers → mapped to controller methods via "." prefix

package.json
  └── cds.server.body_parser.limit: "10mb" ← allows large payloads
```

---

## 13. Appendix: Troubleshooting

### Error: "request entity too large"
**Cause:** Image payload exceeds the body parser limit.
**Fix:** Add `cds.server.body_parser.limit: "10mb"` to `package.json` and restart server.

### Error: "cds.env.fiori.bypass_draft must be enabled..."
**Cause:** You clicked Upload Image without clicking Edit first.
**Fix:** Always click Edit first. Or set `"visible": "{ui>/isEditable}"` in manifest to hide the button in display mode.

### Error: "HTTP request was not processed because $batch failed"
**Cause:** Usually the body size limit. Can also be a draft state issue.
**Fix:** Check the server terminal for the actual backend error message.

### Image doesn't show in header after upload
**Possible causes:**
1. Missing `ImageUrl : image` in `UI.HeaderInfo`
2. Missing `UI.IsImageURL : false` annotation
3. Image data not saved — did you click **Save** after uploading?

### Upload button doesn't appear
**Possible causes:**
1. Wrong path in manifest's `press` property
2. The JS file doesn't export `onUploadImage`
3. If using `"{ui>/isEditable}"` for visibility — are you in edit mode?

### FileUploader shows but nothing happens on upload
**Possible causes:**
1. Check browser console for JS errors
2. The fragment `name` in `loadFragment()` doesn't match your app ID
3. The fragment file is in the wrong directory

### Image shows as broken icon
**Possible causes:**
1. `UI.IsImageURL` is not set to `false` (framework treats Base64 as a URL)
2. `imageType` wasn't set (framework doesn't know the MIME type)
3. The image data is corrupted — try a smaller file

---

## Quick Reference: Minimal Files Checklist

| # | File | Change | Can use Page Map? |
|---|------|--------|-------------------|
| 1 | `db/schema.cds` | Add `image`, `imageType`, `imageName` fields with annotations | ❌ No |
| 2 | `srv/*.cds` | Ensure fields are projected, draft enabled | ❌ No |
| 3 | `package.json` | Add `cds.server.body_parser.limit` | ❌ No |
| 4 | `app/*/annotations.cds` | Add `UI.IsImageURL`, `Core.AcceptableMediaTypes` | ❌ No |
| 5 | `app/*/annotations.cds` | Add `ImageUrl : image` in `UI.HeaderInfo` | ❌ No (but Page Map can add HeaderInfo) |
| 6 | `app/*/webapp/manifest.json` | Add custom action on ObjectPage header | ✅ Yes — Page Map |
| 7 | `app/*/webapp/ext/fragment/*.xml` | Create upload dialog | ❌ No |
| 8 | `app/*/webapp/ext/controller/*.js` | Write upload logic | ❌ No (Page Map creates stub only) |
