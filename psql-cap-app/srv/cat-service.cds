using { BookStore } from '../db/data-model';

@odata service CatalogService {
  entity Books as projection on BookStore.Books;
} 
