#include <iostream>
#include <BookStore.h>
#include <Display.h>

// Overloading operator<< to enable printing a Book
std::ostream& operator<<(std::ostream& os, const Book& book) {
    os << "Title: " << book.bookName << std::endl;
    os << "ISBN: " << book.isn << std::endl;
    os << "Author: " << book.author << std::endl;
    os << "Pages: " << book.pageCount << std::endl;
    return os;
}

int main() {
    BookStore store;

    // Adding sample books
    store.AddBook({"The Lord of the Rings", "978-0-618-64015-7", "J.R.R. Tolkien", 1178});
    store.AddBook({"Pride and Prejudice", "978-0-141-43951-8", "Jane Austen", 432});
    store.AddBook({"The Hitchhiker's Guide to the Galaxy", "978-0-345-39180-3", "Douglas Adams", 224});

    // Displaying books
    Display::displaySeparator();
    Display::displayItems(store.GetBooks(), "Bookstore Inventory:");
    Display::displaySeparator();

    return 0;
}
