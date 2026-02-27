using {my.bookshop as db} from '../db/schema';

service CatalogService @(requires: 'authenticated-user') {

  @(restrict: [
    { grant: '*',    to: 'Admin'  },
    { grant: 'READ', to: 'Viewer' }
  ])
  entity Books as projection on db.Books;

  @(restrict: [{ grant: 'READ', to: 'Greeter' }])
  function hello() returns String;
}
