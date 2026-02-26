sap.ui.define([
    "sap/m/MessageToast"
], function(MessageToast) {
    'use strict';

    var oUploadDialog, oSelectedFile;

    function _createController(oExtAPI, oBindingContext) {
        return {
            onBeforeOpen: function(oEvent) {
                oUploadDialog = oEvent.getSource();
                oExtAPI.addDependent(oUploadDialog);
                if (oBindingContext) oUploadDialog.setBindingContext(oBindingContext);
            },
            onAfterClose: function() {
                oExtAPI.removeDependent(oUploadDialog);
                oUploadDialog.destroy();
                oUploadDialog = undefined;
                oSelectedFile = null;
            },
            onFileChange: function(oEvent) {
                oSelectedFile = oEvent.getParameter("files")[0] || null;
                var oText = sap.ui.core.Fragment.byId("productImageUploadDialog", "imageSelectedFileName");
                if (oText) oText.setText(oSelectedFile ? oSelectedFile.name : "No file selected");
            },
            onUploadPress: function() {
                var oCtx = oUploadDialog.getBindingContext();
                if (!oSelectedFile || !oCtx) {
                    MessageToast.show("Please select a file first");
                    return;
                }
                var reader = new FileReader();
                reader.onload = function(e) {
                    oCtx.setProperty("image", e.target.result.split(',')[1]);
                    oCtx.setProperty("imageType", oSelectedFile.type);
                    oCtx.setProperty("imageName", oSelectedFile.name);
                    MessageToast.show("Image uploaded");
                    oExtAPI.refresh();
                    oUploadDialog.close();
                };
                reader.readAsDataURL(oSelectedFile);
            },
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
            onUploadCancel: function() {
                oUploadDialog.close();
            }
        };
    }

    return {
        onUploadImage: function(oBindingContext) {
            if (!oBindingContext) { MessageToast.show("No context"); return; }
            this.loadFragment({
                id: "productImageUploadDialog",
                name: "sap.practice.lrpop.ext.fragment.ImageUploadDialog",
                controller: _createController(this, oBindingContext)
            }).then(function(oDialog) { oDialog.open(); });
        }
    };
});
