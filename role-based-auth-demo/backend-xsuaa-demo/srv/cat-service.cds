using {my.bookshop as db} from '../db/schema';

service CatalogService @(requires: 'authenticated-user') {

  @(restrict: [
    { grant: '*',    to: 'Admin'  },
    { grant: 'READ', to: 'Viewer' }
  ])
  entity Books as projection on db.Books;

  @(restrict: [{ grant: 'READ', to: 'Greeter' }])
  function hello() returns String;

  // Returns the current user's effective permissions — UI can use this to show/hide buttons
  function securityAction() returns String;

  // Returns current user info (id, roles, attributes)
  function userInfo() returns String;
}
