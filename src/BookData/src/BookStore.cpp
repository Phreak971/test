#include "BookStore.h"

void BookStore::AddBook(Book book)
{
    booksList.push_back(book);
}

std::vector<Book> BookStore::GetBooks()
{
    return booksList;
}
