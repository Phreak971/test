#ifndef DISPLAY_H
#define DISPLAY_H

#include <iostream>
#include <vector>
#include <iomanip>

class Display
{
public:
    template <typename T>
    static void displayItems(const std::vector<T> &items, const std::string &title = "")
    {
        if (!title.empty())
        {
            std::cout << title << std::endl;
        }
        for (const T &item : items)
        {
            std::cout << item << std::endl;
        }
    }
    static void displaySeparator();
};

#endif