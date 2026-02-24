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
            $Type : 'UI.DataFieldForAnnotation',
            Target : '@UI.Chart#UnitsInStock',
            Label : 'UnitsInStock',
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
    UI.DataPoint #UnitsInStock : {
        Value : UnitsInStock,
        MinimumValue : 0,
        MaximumValue : 100,
    },
    UI.Chart #UnitsInStock : {
        ChartType : #Bullet,
        Measures : [
            UnitsInStock,
        ],
        MeasureAttributes : [
            {
                DataPoint : '@UI.DataPoint#UnitsInStock',
                Role : #Axis1,
                Measure : UnitsInStock,
            },
        ],
    },
    UI.HeaderInfo : {
        Title : {
            $Type : 'UI.DataField',
            Value : ProductName,
        },
        TypeName : '',
        TypeNamePlural : '',
        Description : {
            $Type : 'UI.DataField',
            Value : ProductID,
        },
        ImageUrl : image,
    },
    UI.HeaderFacets : [
        {
            $Type : 'UI.ReferenceFacet',
            ID : 'UnitPrice',
            Target : '@UI.DataPoint#UnitPrice',
        },
        {
            $Type : 'UI.ReferenceFacet',
            ID : 'CategoryName',
            Target : 'category/@UI.DataPoint#CategoryName',
        },
    ],
    UI.FieldGroup #GeneralInformation : {
        $Type : 'UI.FieldGroupType',
        Data : [
        ],
    },
    UI.DeleteHidden : true,
    UI.Facets : [
        {
            $Type : 'UI.ReferenceFacet',
            Label : 'General Information',
            ID : 'GeneralInformation',
            Target : '@UI.FieldGroup#GeneralInformation1',
        },
        {
            $Type : 'UI.ReferenceFacet',
            Label : 'Suppliers',
            ID : 'Suppliers',
            Target : 'suppliers/@UI.LineItem#Suppliers1',
        },
    ],
    UI.FieldGroup #Name : {
        $Type : 'UI.FieldGroupType',
        Data : [
        ],
    },
    UI.FieldGroup #Name1 : {
        $Type : 'UI.FieldGroupType',
        Data : [
        ],
    },
    UI.DataPoint #UnitPrice : {
        $Type : 'UI.DataPointType',
        Value : UnitPrice,
        Title : 'Unit Price',
    },
    UI.FieldGroup #GeneralInformation1 : {
        $Type : 'UI.FieldGroupType',
        Data : [
            {
                $Type : 'UI.DataField',
                Value : ProductID,
                Label : 'ProductID',
            },
            {
                $Type : 'UI.DataField',
                Value : UnitPrice,
            },
            {
                $Type : 'UI.DataField',
                Value : ProductName,
            },
        ],
    },
    UI.FieldGroup #Suppliers : {
        $Type : 'UI.FieldGroupType',
        Data : [
        ],
    },
    UI.FieldGroup #Attachments : {
        $Type : 'UI.FieldGroupType',
        Data : [
            {
                $Type : 'UI.DataField',
                Value : suppliers.product.attachments.content,
                Label : 'content',
            },
        ],
    },
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

annotate service.Suppliers with @(
    UI.LineItem #Details : [
    ],
    UI.LineItem #Suppliers : [
        {
            $Type : 'UI.DataField',
            Value : Address,
            Label : 'Address',
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
            Value : Fax,
            Label : 'Fax',
        },
        {
            $Type : 'UI.DataField',
            Value : ID,
            Label : 'ID',
        },
    ],
    UI.LineItem #Suppliers1 : [
        {
            $Type : 'UI.DataField',
            Value : product.suppliers.City,
            Label : 'City',
        },
        {
            $Type : 'UI.DataField',
            Value : product.suppliers.Address,
            Label : 'Address',
        },
        {
            $Type : 'UI.DataField',
            Value : product.suppliers.CompanyName,
            Label : 'CompanyName',
        },
        {
            $Type : 'UI.DataField',
            Value : product.suppliers.ContactName,
            Label : 'ContactName',
        },
        {
            $Type : 'UI.DataField',
            Value : product.suppliers.Country,
            Label : 'Country',
        },
        {
            $Type : 'UI.DataField',
            Value : product.suppliers.ID,
            Label : 'ID',
        },
        {
            $Type : 'UI.DataField',
            Value : product.suppliers.Phone,
            Label : 'Phone',
        },
    ],
);

annotate service.ProductAttachments with @(
    UI.LineItem #UploadedFiles : [
    ]
);

annotate service.Categories with @(
    UI.DataPoint #CategoryName : {
        $Type : 'UI.DataPointType',
        Value : CategoryName,
        Title : 'CategoryName',
    }
);

