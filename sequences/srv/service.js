const cds = require('@sap/cds')

module.exports = cds.service.impl(async function () {

  const { Orders } = this.entities

  this.on('createOrder', async (req) => {

    // Get next sequence value
    const result = await cds.run(
      `SELECT ORDER_SEQ.NEXTVAL AS ID FROM DUMMY`
    )

    const newId = result[0].ID

    // Insert into table
    await INSERT.into(Orders).entries({
      ID: newId,
      customer_ID: req.data.customer_ID,
      amount: req.data.amount,
      status: req.data.status
    })

    return { ID: newId }
  })

})