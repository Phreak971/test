CXX = g++

SOURCE_DIR = /home/nfakhar/work/book-store/src
PROJ_DIR = /home/nfakhar/work/book-store
OUT_DIR = /home/nfakhar/work/book-store/out

CXXFLAGS = -std=c++17 -Wall -I $(SOURCE_DIR)/BookData/include -I $(SOURCE_DIR)/BookUtil/include
LIBFLAGS = -L $(OUT_DIR) -lbookdata -lbookutil

TARGET = library_catalog

LIB_BOOKDATA = libbookdata.a
LIB_BOOKUTIL = libbookutil.so
OBJ_FILE = main.o

default: $(TARGET)

$(TARGET): $(OBJ_FILE) $(LIB_BOOKDATA) $(LIB_BOOKUTIL)
	$(CXX) $(OBJ_FILE) $(LIBFLAGS) -o $(TARGET)

$(OBJ_FILE): $(SOURCE_DIR)/main.cpp $(LIB_BOOKDATA) $(LIB_BOOKUTIL)
	$(CXX) $(CXXFLAGS) -c $(SOURCE_DIR)/main.cpp -o $(OBJ_FILE)

$(LIB_BOOKDATA): $(SOURCE_DIR)/BookData/src/BookStore.cpp
	$(CXX) $(CXXFLAGS) -c $(SOURCE_DIR)/BookData/src/BookStore.cpp -o bookdata.o
	ar rcs $(LIB_BOOKDATA) bookdata.o

$(LIB_BOOKUTIL): $(SOURCE_DIR)/BookUtil/src/Display.cpp
	$(CXX) $(CXXFLAGS) -fPIC -c $(SOURCE_DIR)/BookUtil/src/Display.cpp -o bookutil.o
	$(CXX) -shared -g -shared -Wl,-soname,$(LIB_BOOKUTIL) -o $(LIB_BOOKUTIL) bookutil.o

clean:
	rm -rf *.o *.a *.so $(TARGET)

run: $(TARGET)
	sudo cp $(LIB_BOOKUTIL) /usr/lib/
	./$(TARGET)
