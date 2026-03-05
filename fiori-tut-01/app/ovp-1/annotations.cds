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
