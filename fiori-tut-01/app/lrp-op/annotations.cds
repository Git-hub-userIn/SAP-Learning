using CatalogService as service from '../../srv/cat-service';
annotate service.Products with @(
    UI.LineItem : [
        {
            $Type : 'UI.DataField',
            Value : ProductID,
            Label : 'ProductID',
            @UI.Importance : #High,
        },
        {
            $Type : 'UI.DataField',
            Value : image,
            Label : 'image',
            @UI.Importance : #High,
        },
        {
            $Type : 'UI.DataField',
            Value : ProductName,
            Label : 'ProductName',
            @UI.Importance : #High,
        },
        {
            $Type : 'UI.DataField',
            Value : UnitsInStock,
            Label : 'UnitsInStock',
            Criticality : UnitsInStock,
            CriticalityRepresentation : #WithIcon,
            @UI.Importance : #High,
        },
        {
            $Type : 'UI.DataField',
            Value : UnitsLeft,
            Label : 'Stocks',
            @UI.Importance : #High,
        },
        {
            $Type : 'UI.DataField',
            Value : category.CategoryName,
            Label : 'CategoryName',
            @UI.Importance : #High,
        },
        {
            $Type : 'UI.DataField',
            Value : UnitPrice,
            Label : 'Unit Price',
            @UI.Importance : #High,
        },
        {
            $Type : 'UI.DataFieldForAction',
            Action : 'CatalogService.continueProduct',
            Label : 'Continue Product',
        },
        {
            $Type : 'UI.DataFieldForAction',
            Action : 'CatalogService.discontinueProduct',
            Label : 'Discontinue Product',
        },
    ],
    UI.SelectionFields : [
        ProductName,
        SupplierID,
        UnitPrice,
        UnitsLeft,
    ],
);

annotate service.Products with {
    ProductName @(
        Common.Label : 'ProductName',
        )
};

annotate service.Products with {
    SupplierID @Common.Label : 'SupplierID'
};

annotate service.Products with {
    UnitPrice @Common.Label : 'UnitPrice'
};

annotate service.Products with {
    UnitsLeft @Common.Label : 'UnitsLeft'
};

