using my.company as my from '../db/schema';

service CatalogService {
    entity Products           as
        projection on my.Products {
            *,
            case
                when UnitsInStock >= 50
                     then 3 // Good (Green) - High stock
                when UnitsInStock >= 20
                     then 2 // Warning (Orange) - Medium stock
                else 1 // Error (Red) - Low stock
            end                         as stockCriticality : Integer,
            UnitsInStock - UnitsOnOrder as UnitsLeft        : Integer
        }
        actions {
            action continueProduct();
            action discontinueProduct();
        };

    entity Suppliers          as projection on my.Suppliers;
    entity ProductAttachments as projection on my.ProductAttachments;
    entity Categories         as projection on my.Categories;
    entity Countries          as projection on my.Countries;
    entity Regions            as projection on my.Regions;
}

annotate CatalogService.Products with @odata.draft.enabled;
// annotate CatalogService.Suppliers with @odata.draft.enabled;
// annotate CatalogService.ProductAttachments with @odata.draft.enabled;
annotate CatalogService.Categories with @odata.draft.enabled;
