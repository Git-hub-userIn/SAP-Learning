using {
    cuid,
    managed
} from '@sap/cds/common';

namespace my.company;

entity Products : cuid, managed {
    ProductID      : Int32;
    ProductName    : String(40)     @mandatory;
    SupplierID     : Int32;
    category       : Association to Categories;
    UnitPrice      : Decimal(19, 4) @mandatory;
    OrderStatus    : String(20)     @mandatory default 'None';
    PaymentStatus  : String(20)     @mandatory default 'None';
    DeliveryStatus : String(20)     @mandatory default 'None';
    UnitsInStock   : Int16          @mandatory;
    UnitsOnOrder   : Int16          @mandatory;
    Discontinued   : Boolean        @mandatory default false;
    // Product image with proper media type handling
    image          : LargeBinary    @Core.MediaType: imageType  @Core.ContentDisposition.Filename: imageName;
    imageType      : String         @Core.IsMediaType: true;
    imageName      : String;
    suppliers      : Composition of many Suppliers
                         on suppliers.product = $self;
    attachments    : Composition of many ProductAttachments
                         on attachments.product = $self;
}

entity Categories : cuid, managed {
    key ID           : UUID;
        CategoryID   : Int32;
        CategoryName : String(100) @mandatory;
        Description  : String(500);
        products     : Association to many Products
                           on products.category = $self;
}

entity Countries : cuid, managed {
    key ID          : UUID;
        CountryCode : String(3)   @mandatory;
        CountryName : String(100) @mandatory;
}

entity Regions : cuid, managed {
    key ID         : UUID;
        RegionCode : String(10)  @mandatory;
        RegionName : String(100) @mandatory;
        country    : Association to Countries;
}

entity Suppliers : cuid, managed {
    CompanyName  : String(100) @mandatory;
    ContactName  : String(100) @mandatory;
    ContactTitle : String(50);
    Address      : String(200);
    City         : String(50);
    Region       : String(50);
    PostalCode   : String(20);
    Country      : String(50);
    Phone        : String(30);
    Fax          : String(30);
    HomePage     : String(200);
    product      : Association to Products;
}

entity ProductAttachments : managed {
    key ID          : UUID         @auto;
        description : String(200)  @mandatory;
        mimeType    : String(100);
        content     : LargeBinary  @Core.MediaType: mimeType  @Core.ContentDisposition.Type: #inline; // actual image or file
        product     : Association to Products;
}
