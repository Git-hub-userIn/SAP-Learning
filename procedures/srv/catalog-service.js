const cds = require('@sap/cds')

module.exports = class CatalogService extends cds.ApplicationService { async init() {

  const db = await cds.connect.to('db')

  const { Orders, Customers } = cds.entities('CatalogService')

  this.before (['CREATE', 'UPDATE'], Orders, async (req) => {
    console.log('Before CREATE/UPDATE Orders', req.data)
  })
  this.after ('READ', Orders, async (orders, req) => {
    console.log('After READ Orders', orders)
  })
  this.before (['CREATE', 'UPDATE'], Customers, async (req) => {
    console.log('Before CREATE/UPDATE Customers', req.data)
  })
  this.after ('READ', Customers, async (customers, req) => {
    console.log('After READ Customers', customers)
  })

  this.on('getOrderSummary', async (req) => {
  const { status } = req.data
  const result = await db.run(
    `CALL "get_order_summary"(iv_status => ?, ot_results => ?)`,
    [status]
  )
  return result.ot_results
})

  return super.init()
}}
