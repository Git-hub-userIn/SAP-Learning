namespace study;

entity Orders {
  key ID       : Integer;
  customer     : Association to Customers;
  amount       : Decimal(10,2);
  status       : String(20);
}

entity Customers {
  key ID      : UUID;
  name        : String(100);
  country     : String(50);
}