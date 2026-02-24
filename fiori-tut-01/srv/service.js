const cds = require('@sap/cds');

module.exports = async (srv) => {
    // Bind actions
    srv.on('continueProduct', 'Products', async (req) => {
        req.info(200, 'Product continued successfully');
    });

    srv.on('discontinueProduct', 'Products', async (req) => {
        req.info(200, 'Product discontinued successfully');
    });

    // Handle bound actions on Products entity
    srv.on('updatePaymentStatusFromOrder', 'Products', async (req) => {
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
    });
};