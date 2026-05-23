CC      = g++
CFLAGS  = -Wall -Wextra -O2 -g
LDFLAGS = -lpthread

OBJS = server.o hashtable.o avl.o zset.o heap.o thread_pool.o
TARGETS = server client

.PHONY: all clean

all: $(TARGETS)

server: $(OBJS)
	$(CC) $(OBJS) -o server $(LDFLAGS)

client: client.o
	$(CC) client.o -o client $(LDFLAGS)

%.o: %.cpp
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f *.o $(TARGETS)
