const cds = require('@sap/cds');

module.exports = class CatalogService extends cds.ApplicationService {
  init() {
    this.on('hello', (req) => {
      return `Hello, ${req.user.id}! You have roles: ${JSON.stringify(req.user.roles)}`;
    });

    return super.init();
  }
};
