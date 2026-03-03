using study as db from '../db/schema';

service CatalogService {
  entity Orders    as projection on db.Orders;
  entity Customers as projection on db.Customers;

  function getOrderSummary(status : String) returns array of {
    customer_id   : UUID;
    customer_name : String;
    order_count   : Integer;
    total_amount  : Decimal(10,2);
  };
}