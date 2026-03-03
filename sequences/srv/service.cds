using study from '../db/schema';

service OrderService {
  entity Orders as projection on study.Orders;
  action createOrder(
    customer_ID : UUID,
    amount      : Decimal(10,2),
    status      : String(20)
  ) returns {
    ID : Integer;
  };
}