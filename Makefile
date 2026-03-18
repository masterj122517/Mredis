CC      = g++
CFLAGS  = -Wall -Wextra -O2 -g
LDFLAGS = 

TARGETS = server client

.PHONY: all clean

all: $(TARGETS)

server: server.o
	$(CC) server.o -o server $(LDFLAGS)

client: client.o
	$(CC) client.o -o client $(LDFLAGS)

%.o: %.cpp
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f *.o $(TARGETS)
