using CatalogService as service from '../../srv/cat-service';

annotate service.Products with @(UI.LineItem #OVP: [
  {
    Value: ProductName,
    Label: 'Product'
  },
  {
    Value: PaymentStatus,
    Label: 'Payment Status'
  }
]);

annotate service.Products with @(UI.LineItem #OVP_PRODUCT_TABLE: [
  {
    Value: ProductID,
    Label: 'ID'
  },
  {
    Value: ProductName,
    Label: 'Product'
  },
  {
    Value: UnitPrice,
    Label: 'Price'
  },
  {
    Value: UnitsInStock,
    Label: 'Stock'
  }
]);
