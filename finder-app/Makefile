CC = $(CROSS_COMPILE)gcc
CFLAGS ?= -Wall -Wextra -Wpedantic -std=c11 -O2

.PHONY: all clean

all: writer

writer: writer.o
	$(CC) $(LDFLAGS) -o $@ $^ $(LDLIBS)

writer.o: writer.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

clean:
	rm -f writer *.o