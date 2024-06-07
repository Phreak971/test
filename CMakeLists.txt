cmake_minimum_required(VERSION 3.25.1)
project(library_catalog)

file(GLOB BOOKDATA_SOURCES "src/BookData/src/*.cpp")
file(GLOB BOOKUTIL_SOURCES "src/BookUtil/src/*.cpp")

add_library(bookdata ${BOOKDATA_SOURCES})
add_library(bookutil SHARED ${BOOKUTIL_SOURCES})

target_include_directories(bookdata PUBLIC src/BookData/include)
target_include_directories(bookutil PUBLIC src/BookUtil/include)

add_executable(${PROJECT_NAME} src/main.cpp)

target_link_libraries(${PROJECT_NAME} bookdata bookutil)
