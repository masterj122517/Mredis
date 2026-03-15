#include <arpa/inet.h>
#include <errno.h>
#include <netinet/ip.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>
static void msg(const char* message)
{
  fprintf(stderr, "%s\n", message);
}

static void die(const char* message)
{
  int err = errno;

  fprintf(stderr, "[%d] %s \n", err, message);
}

static void do_something(int connfd)
{
  char rbuf[64] = {};
  ssize_t n = read(connfd, rbuf, sizeof(rbuf) - 1);
  if (n < 0) {
    msg("read() error");
    return;
  }
  fprintf(stderr, "client says %s\n", rbuf);
  char wbuf[] = "world";
  write(connfd, wbuf, strlen(wbuf));
}

int main()
{
  int fd = socket(AF_INET, SOCK_STREAM, 0);
  if (fd < 0) {
    die("socket()");
  }
  // 让socket能复用
  int val = 1;
  setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &val, sizeof(val));
  // bind
  struct sockaddr_in addr = {};
  addr.sin_family = AF_INET;
  addr.sin_port = ntohs(1234);
  addr.sin_addr.s_addr = ntohl(0); // wildcard address 0.0.0.0
  int rv = bind(fd, (const struct sockaddr*)&addr, sizeof(addr));
  if (rv) {
    die("bind()");
  }
  // listen

  rv = listen(fd, SOMAXCONN);
  if (rv) {
    die("listen()");
  }
  while (true) {
    // accept
    struct sockaddr_in client_addr = {};
    socklen_t addrlen = sizeof(client_addr);
    int connfd = accept(fd, (struct sockaddr*)&client_addr, &addrlen);
    if (connfd < 0) {
      continue;
    }
    do_something(connfd);
    close(connfd);
  }
  return 0;
}
