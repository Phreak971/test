#pragma once
#include <vector>
#include "Book.h"
class BookStore
{
public:
    void AddBook(Book book);
    std::vector<Book> GetBooks();
private:
    std::vector<Book> booksList;
};