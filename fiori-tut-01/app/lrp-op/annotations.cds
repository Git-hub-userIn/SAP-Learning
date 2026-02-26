using CatalogService as service from '../../srv/cat-service';
annotate service.Products with @(
    UI.LineItem : [
        {
            $Type : 'UI.DataField',
            Value : ProductID,
            Label : 'Product ID',
        },
        {
            $Type : 'UI.DataField',
            Value : image,
            Label : 'Image',
            ![@UI.Importance] : #High,
        },
        {
            $Type : 'UI.DataField',
            Value : ProductName,
            Label : 'Product Name',
            ![@UI.Importance] : #High,
        },
        {
            $Type : 'UI.DataField',
            Value : UnitsInStock,
            Label : 'Stock',
            Criticality : stockCriticality,
            CriticalityRepresentation : #WithIcon,
            ![@UI.Importance] : #High,
        },
        {
            $Type : 'UI.DataFieldForAnnotation',
            Target : '@UI.Chart#StockBullet',
            Label : 'Stock Chart',
        },
        {
            $Type : 'UI.DataField',
            Value : UnitsOnOrder,
            Label : 'On Order',
        },
        {
            $Type : 'UI.DataField',
            Value : UnitsLeft,
            Label : 'Units Left',
            Criticality : stockCriticality,
            CriticalityRepresentation : #WithIcon,
            ![@UI.Importance] : #High,
        },
        {
            $Type : 'UI.DataField',
            Value : category.CategoryName,
            Label : 'Category',
        },
        {
            $Type : 'UI.DataField',
            Value : UnitPrice,
            Label : 'Unit Price',
            ![@UI.Importance] : #High,
        },
        {
            $Type : 'UI.DataField',
            Value : PaymentStatus,
            Label : 'Payment',
            Criticality : paymentCriticality,
            CriticalityRepresentation : #WithIcon,
        },
        {
            $Type : 'UI.DataField',
            Value : Discontinued,
            Label : 'Discontinued',
            Criticality : discontinuedCriticality,
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
        category_ID,
        UnitPrice,
        PaymentStatus,
        UnitsLeft,
    ],
    // --- Micro Chart: Bullet chart for stock levels ---
    UI.DataPoint #StockBullet : {
        $Type : 'UI.DataPointType',
        Value : UnitsInStock,
        TargetValue : 50,
        Criticality : stockCriticality,
    },
    UI.Chart #StockBullet : {
        $Type : 'UI.ChartDefinitionType',
        Title : 'Stock Level',
        Description : 'Stock vs Target',
        ChartType : #Bullet,
        Measures : [UnitsInStock],
        MeasureAttributes : [{
            $Type : 'UI.ChartMeasureAttributeType',
            Measure : UnitsInStock,
            Role : #Axis1,
            DataPoint : '@UI.DataPoint#StockBullet',
        }],
    },

    // --- DataPoint: Radial chart for stock on Object Page header ---
    UI.DataPoint #StockRadial : {
        $Type : 'UI.DataPointType',
        Value : UnitsInStock,
        TargetValue : 100,
        Criticality : stockCriticality,
    },
    UI.Chart #StockRadial : {
        $Type : 'UI.ChartDefinitionType',
        Title : 'Stock Level',
        ChartType : #Donut,
        Measures : [UnitsInStock],
        MeasureAttributes : [{
            $Type : 'UI.ChartMeasureAttributeType',
            Measure : UnitsInStock,
            Role : #Axis1,
            DataPoint : '@UI.DataPoint#StockRadial',
        }],
    },

    // --- DataPoints for header KPIs ---
    UI.DataPoint #UnitPrice : {
        $Type : 'UI.DataPointType',
        Value : UnitPrice,
        Title : 'Unit Price',
        Criticality : 3, // Green
    },
    UI.DataPoint #PaymentStatus : {
        $Type : 'UI.DataPointType',
        Value : PaymentStatus,
        Title : 'Payment Status',
        Criticality : paymentCriticality,
    },
    UI.DataPoint #StockInfo : {
        $Type : 'UI.DataPointType',
        Value : UnitsInStock,
        Title : 'Units In Stock',
        Criticality : stockCriticality,
    },

    // --- Object Page Header ---
    UI.HeaderInfo : {
        Title : {
            $Type : 'UI.DataField',
            Value : ProductName,
        },
        TypeName : 'Product',
        TypeNamePlural : 'Products',
        Description : {
            $Type : 'UI.DataField',
            Value : category.CategoryName,
        },
        ImageUrl : image,
    },
    UI.HeaderFacets : [
        {
            $Type : 'UI.ReferenceFacet',
            ID : 'PriceHeader',
            Target : '@UI.DataPoint#UnitPrice',
        },
        {
            $Type : 'UI.ReferenceFacet',
            ID : 'StockHeader',
            Target : '@UI.Chart#StockRadial',
        },
        {
            $Type : 'UI.ReferenceFacet',
            ID : 'PaymentHeader',
            Target : '@UI.DataPoint#PaymentStatus',
        },
    ],

    // --- Object Page Sections ---
    UI.DeleteHidden : true,
    UI.Facets : [
        {
            $Type : 'UI.CollectionFacet',
            ID : 'ProductDetailsFacet',
            Label : 'Product Details',
            Facets : [
                {
                    $Type : 'UI.ReferenceFacet',
                    ID : 'BasicInfoFacet',
                    Label : 'Basic Information',
                    Target : '@UI.FieldGroup#BasicInfo',
                },
                {
                    $Type : 'UI.ReferenceFacet',
                    ID : 'StatusInfoFacet',
                    Label : 'Status',
                    Target : '@UI.FieldGroup#StatusInfo',
                },
            ],
        },
        {
            $Type : 'UI.ReferenceFacet',
            Label : 'Suppliers',
            ID : 'Suppliers',
            Target : 'suppliers/@UI.LineItem#Suppliers1',
        },
    ],

    // --- Field Groups ---
    UI.FieldGroup #BasicInfo : {
        $Type : 'UI.FieldGroupType',
        Data : [
            {
                $Type : 'UI.DataField',
                Value : ProductID,
                Label : 'Product ID',
            },
            {
                $Type : 'UI.DataField',
                Value : ProductName,
                Label : 'Product Name',
            },
            {
                $Type : 'UI.DataField',
                Value : category_ID,
                Label : 'Category',
            },
            {
                $Type : 'UI.DataField',
                Value : UnitPrice,
                Label : 'Unit Price',
            },
        ],
    },
    UI.FieldGroup #StatusInfo : {
        $Type : 'UI.FieldGroupType',
        Data : [
            {
                $Type : 'UI.DataField',
                Value : UnitsInStock,
                Label : 'Units In Stock',
                Criticality : stockCriticality,
            },
            {
                $Type : 'UI.DataField',
                Value : UnitsOnOrder,
                Label : 'Units On Order',
            },
            {
                $Type : 'UI.DataField',
                Value : UnitsLeft,
                Label : 'Units Left',
                Criticality : stockCriticality,
            },
            {
                $Type : 'UI.DataField',
                Value : PaymentStatus,
                Label : 'Payment Status',
                Criticality : paymentCriticality,
            },
            {
                $Type : 'UI.DataField',
                Value : OrderStatus,
                Label : 'Order Status',
            },
            {
                $Type : 'UI.DataField',
                Value : DeliveryStatus,
                Label : 'Delivery Status',
            },
            {
                $Type : 'UI.DataField',
                Value : Discontinued,
                Label : 'Discontinued',
                Criticality : discontinuedCriticality,
            },
        ],
    },
);

annotate service.Products with {
    ProductName @Common.Label : 'Product Name';
    SupplierID  @Common.Label : 'Supplier';
    UnitPrice   @Common.Label : 'Unit Price';
    UnitsLeft   @Common.Label : 'Units Left';
    category    @(
        Common.Label : 'Category',
        Common.ValueList : {
            $Type : 'Common.ValueListType',
            CollectionPath : 'Categories',
            Parameters : [
                {
                    $Type : 'Common.ValueListParameterInOut',
                    LocalDataProperty : category_ID,
                    ValueListProperty : 'ID',
                },
                {
                    $Type : 'Common.ValueListParameterDisplayOnly',
                    ValueListProperty : 'CategoryName',
                },
            ],
        },
        Common.ValueListWithFixedValues : true,
        Common.Text : category.CategoryName,
        Common.Text.@UI.TextArrangement : #TextOnly,
    );
};

annotate service.Suppliers with @(
    UI.LineItem #Suppliers1 : [
        {
            $Type : 'UI.DataField',
            Value : CompanyName,
            Label : 'Company',
        },
        {
            $Type : 'UI.DataField',
            Value : ContactName,
            Label : 'Contact',
        },
        {
            $Type : 'UI.DataField',
            Value : City,
            Label : 'City',
        },
        {
            $Type : 'UI.DataField',
            Value : Country,
            Label : 'Country',
        },
        {
            $Type : 'UI.DataField',
            Value : Phone,
            Label : 'Phone',
        },
    ],
);

annotate service.Categories with {
    ID @(
        Common.Text : CategoryName,
        Common.Text.@UI.TextArrangement : #TextOnly,
    )
};

annotate service.Categories with @(
    UI.DataPoint #CategoryName : {
        $Type : 'UI.DataPointType',
        Value : CategoryName,
        Title : 'Category',
    }
);

