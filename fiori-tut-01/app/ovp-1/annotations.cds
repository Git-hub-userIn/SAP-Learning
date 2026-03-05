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

annotate service.Products with @(
  UI.Chart #OVP_STOCK_BY_CATEGORY         : {
    ChartType          : #Donut,
    Dimensions         : [category_ID],
    Measures           : [UnitsInStock],

    MeasureAttributes  : [{
      Measure: UnitsInStock,
      Role   : #Axis1
    }],

    DimensionAttributes: [{
      Dimension: category_ID,
      Role     : #Category
    }]
  },

  UI.Identification #OVP_STOCK_BY_CATEGORY: [{
    $Type: 'UI.DataField',
    Value: category_ID
  }]
);



annotate service.Products with @(
  UI.Chart #OVP_PRICE_BY_CATEGORY: {
    ChartType: #Column,
    Dimensions: [category_ID],
    Measures: [UnitPrice],

    MeasureAttributes: [{
      Measure: UnitPrice,
      Role: #Axis1
    }],

    DimensionAttributes: [{
      Dimension: category_ID,
      Role: #Category
    }]
  },

  UI.Identification #OVP_PRICE_BY_CATEGORY: [
    {
      $Type: 'UI.DataField',
      Value: category_ID
    }
  ]
);