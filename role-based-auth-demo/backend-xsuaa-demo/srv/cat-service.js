const cds = require('@sap/cds');

module.exports = class CatalogService extends cds.ApplicationService {
  init() {

    // ---------- hello ----------
    this.on('hello', (req) => {
      return `Hello, ${req.user.id}! You have roles: ${JSON.stringify(req.user.roles)}`;
    });

    // ---------- securityAction ----------
    // Returns what the current user CAN do on Books.
    // The UI calls this on load → hides Create/Edit/Delete buttons for read-only users.
    this.on('securityAction', (req) => {
      const user = req.user;
      const permissions = {
        Read:   user.is('Admin') || user.is('Viewer') || user.is('Greeter'),
        Create: user.is('Admin'),
        Update: user.is('Admin'),
        Delete: user.is('Admin'),
      };
      return JSON.stringify(permissions);
    });

    // ---------- userInfo ----------
    // Returns identity details — useful for debugging and UI display.
    this.on('userInfo', (req) => {
      const user = req.user;
      return JSON.stringify({
        id:         user.id,
        roles:      user.roles,
        attributes: user.attr || {},
        tenant:     user.tenant || null,
      });
    });

    return super.init();
  }
};
