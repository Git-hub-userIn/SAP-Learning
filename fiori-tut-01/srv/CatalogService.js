const cds = require('@sap/cds');
const { UPDATE } = cds.ql;

module.exports = class ProductsService extends cds.ApplicationService {
    async init() {
        // Bind actions
        this.on('continueProduct', this.continueProduct);
        this.on('discontinueProduct', this.discontinueProduct);
        this.on('updatePaymentStatusFromOrder', this.updatePaymentStatusFromOrder);

        await super.init();
    }

    async continueProduct(req) {
        req.info(200, 'Product continued successfully');
    }

    async discontinueProduct(req) {
        req.info(200, 'Product discontinued successfully');
    }

    async updatePaymentStatusFromOrder(req) {
        const product = req.data;

        // Determine payment status based on UnitsOnOrder
        let newPaymentStatus;
        if (product.UnitsOnOrder === 0) {
            newPaymentStatus = 'None';
        } else if (product.UnitsOnOrder < 10) {
            newPaymentStatus = 'Pending';
        } else {
            newPaymentStatus = 'Paid';
        }

        // Update the PaymentStatus
        product.PaymentStatus = newPaymentStatus;

        console.log(`Payment status updated to: ${newPaymentStatus} for product based on ${product.UnitsOnOrder} units ordered`);

        // Return the updated product data
        return product;
    }
};