# Build Your Own Redis — 完整学习笔记

> 基于 [build-your-own.org/redis](https://build-your-own.org/redis/) 全书整理
> 包含：知识点 · 要点 · 注意事项 · 面试高频问题

---

## 目录

1. [Ch01 — 概述与背景](#ch01--概述与背景)
2. [Ch02 — Socket 编程基础](#ch02--socket-编程基础)
3. [Ch03-04 — TCP Server/Client & 请求响应协议](#ch03-04--tcp-serverclient--请求响应协议)
4. [Ch05 — 并发 IO 模型](#ch05--并发-io-模型)
5. [Ch06 — Event Loop 实现](#ch06--event-loop-实现)
6. [Ch07 — 基础 KV 服务器](#ch07--基础-kv-服务器)
7. [Ch08 — 哈希表](#ch08--哈希表)
8. [Ch09 — 数据序列化](#ch09--数据序列化)
9. [Ch10 — 平衡二叉树（AVL Tree）](#ch10--平衡二叉树avl-tree)
10. [Ch11 — 有序集合（Sorted Set）](#ch11--有序集合sorted-set)
11. [Ch12 — 定时器与超时](#ch12--定时器与超时)
12. [Ch13 — TTL 与缓存过期（Heap）](#ch13--ttl-与缓存过期heap)
13. [Ch14 — 线程池](#ch14--线程池)

---

## Ch01 — 概述与背景

### 📚 知识点

- Redis 是最流行的 **内存键值存储**，核心用途是缓存（caching）
- Redis 的"值"不仅是字符串，还支持 hash、list、sorted set 等数据结构，因此被称为 **数据结构服务器**
- 缓存服务器本质是网络上的一个 `map<string, string>`，但 Redis 的 value 更丰富
- 从零构建的价值：理解网络编程、数据结构的实际应用、低级 C 编程
- Feynman 名言：`"What I cannot create, I do not understand"` — 创建即理解

### ⚡ 要点

- 高性能软件需要低级控制（C/C++）
- 构建 Redis 能覆盖三个核心技能：网络编程、数据结构、低级 C
- 最终产物约 **1200 行代码**，聚焦原理，不是真实 Redis 的克隆

### ⚠️ 注意事项

- 本书实现与真实 Redis **不兼容**，很多细节被简化或用不同方式实现
- 使用 Python/Go 可以学习部分内容，但无法完整体验网络编程和数据结构的低级实现

### 🎤 面试官可能问的点

- Redis 是什么？为什么被称为"数据结构服务器"？
- Redis 的主要使用场景是什么？为什么缓存是数据库扩展的首选手段？
- 内存存储和磁盘存储的性能差异在哪里？

---

## Ch02 — Socket 编程基础

### 📚 知识点

**网络协议分层：**
- IP 层：处理小的、离散的数据包（packet-based）
- Port：实现多路复用（demultiplexing），16-bit 端口号区分不同应用
- TCP：在 IP 之上提供可靠、有序的字节流（reliable & ordered byte stream）
- 四元组 `(src_ip, src_port, dst_ip, dst_port)` 唯一标识一条"流"

**Socket 基础：**
- `socket()` — 申请一个 socket 文件描述符（fd）
- `bind()` — 绑定监听的 IP:Port
- `listen()` — 创建监听 socket
- `accept()` — 接受 TCP 连接，返回连接 socket
- `connect()` — 客户端创建连接
- `read()` / `write()` — 读写字节流
- `close()` — 释放资源

**TCP vs UDP：**
- TCP：字节流，可靠，有序
- UDP：消息，不可靠，无序，语义上不兼容

### ⚡ 要点

- TCP 不产生"消息"，只产生**连续字节流**，将字节流分割成消息是应用协议的职责
- Socket 是跨 API 边界的句柄（handle），在 Linux 中称为文件描述符（fd）
- 有两种 socket：监听 socket 和连接 socket
- 大多数 request-response 协议（Redis、HTTP/1.1）基于 TCP

### ⚠️ 注意事项

- 忽略 OSI 模型，只需掌握 TCP/IP 模型（TCP / UDP / IP / Port）
- Socket 文件描述符使用完必须 `close()`，否则资源泄漏
- TCP 和 UDP 语义**不兼容**，选型是网络应用的第一决定

### 🎤 面试官可能问的点

- TCP 和 UDP 的区别？分别适合什么场景？
- 什么是端口？为什么需要端口？
- 描述一个 TCP 连接从建立到关闭的完整流程（三次握手、四次挥手）
- 为什么 Redis 使用 TCP 而不是 UDP？
- 文件描述符（fd）是什么？

---

## Ch03-04 — TCP Server/Client & 请求响应协议

### 📚 知识点

**服务器端流程：**
```
fd = socket()
bind(fd, address)
listen(fd)
while True:
    conn_fd = accept(fd)
    do_something_with(conn_fd)
    close(conn_fd)
```

**客户端流程：**
```
fd = socket()
connect(fd, address)
do_something_with(fd)
close(fd)
```

**请求响应协议设计：**
- 需要定义消息边界（message framing）
- 常见方式：固定长度头部 + 变长内容（length-prefixed）
- Redis 自定义二进制协议（RESP 的简化版本）

### ⚡ 要点

- 从字节流中正确解析消息，需要处理**部分读取**（partial read）的情况
- 服务端的读写操作可能无法一次完成，需要循环直到读完或写完

### ⚠️ 注意事项

- `read()` 和 `write()` 返回值可能小于请求的字节数，必须循环处理
- 连接断开时 `read()` 返回 0，错误时返回 -1

### 🎤 面试官可能问的点

- 如何在 TCP 字节流中区分消息边界？
- 常见的消息分帧（framing）方式有哪些？（分隔符、固定长度、长度前缀）
- 为什么 `read()` 可能返回少于请求的字节数？

---

## Ch05 — 并发 IO 模型

### 📚 知识点

**三种并发模型：**

| 类型 | 方法 | API | 可扩展性 |
|------|------|-----|----------|
| Socket | 每连接一个线程 | `pthread` | 低 |
| Socket | 每连接一个进程 | `fork()` | 低 |
| Socket | Event Loop | `poll()`, `epoll` | 高 |
| File | 线程池 | `pthread` | 中 |
| Any | Event Loop | `io_uring` | 高 |

**事件循环（Event Loop）核心机制：**
- 就绪通知（Readiness notification）：`poll()` / `epoll_wait()` / `kqueue()`
- 非阻塞读：`read()` 加 `O_NONBLOCK`，buffer 为空时返回 `EAGAIN`
- 非阻塞写：`write()` 加 `O_NONBLOCK`，buffer 满时返回 `EAGAIN`

**就绪 API 对比：**
- `select()`：最多 1024 个 fd，不推荐
- `poll()`：无 fd 上限，简单，但每次传入整个 fd 列表
- `epoll()`：Linux 特有，fd 列表存储在内核，更高效，生产首选
- `kqueue()`：BSD 特有，类似 epoll

**`O_NONBLOCK` 设置方式：**
```c
int flags = fcntl(fd, F_GETFL, 0);
flags |= O_NONBLOCK;
fcntl(fd, F_SETFL, flags);
```

### ⚡ 要点

- 多线程的缺点：每个线程占用独立的栈内存，大量连接时内存压力大
- 事件循环只需一个线程，通过等待多个 socket 就绪来处理并发
- 就绪通知 API **不能用于磁盘文件**，因为磁盘文件没有内核缓冲区，IO 永远报告就绪但实际会阻塞

### ⚠️ 注意事项

- 非阻塞 IO 中，`EAGAIN` 不是错误，而是"暂时不可用，稍后重试"
- 磁盘文件的 IO 必须放到线程池中，不能在 event loop 里直接操作
- `epoll` 在生产环境是默认选择，`poll` 仅用于学习/简单场景

### 🎤 面试官可能问的点

- 为什么 Redis 是单线程的？单线程如何支持高并发？
- `select` / `poll` / `epoll` 的区别和各自的优缺点？
- 什么是非阻塞 IO？`EAGAIN` 是什么意思？
- 事件循环是什么？Nginx、Redis、Node.js 中事件循环有何相似之处？
- C10K 问题是什么？如何解决？

---

## Ch06 — Event Loop 实现

### 📚 知识点

**Event Loop 结构：**
```
while running:
    want_read = [...]
    want_write = [...]
    can_read, can_write = poll(want_read, want_write)
    for fd in can_read:
        handle_read(fd)
    for fd in can_write:
        handle_write(fd)
    process_timers()
```

**连接状态机（Connection State Machine）：**
- 每个连接维护状态：读取请求中、处理请求、发送响应
- 状态转换通过 `want_read` / `want_write` 标志驱动

**Read/Write Buffer 管理：**
- 每个连接维护读缓冲区和写缓冲区
- 非阻塞读：将数据追加到读缓冲区，当读缓冲区有完整请求时触发处理
- 非阻塞写：将响应放入写缓冲区，等待 socket 可写时发送

### ⚡ 要点

- Event Loop 的关键假设：**每次循环中的操作必须快速完成**，不能阻塞
- 使用状态机（State Machine）追踪每个连接的当前状态
- 回调（Callback）是 event-based 编程的核心模式

### ⚠️ 注意事项

- 不能在 event loop 中执行任何阻塞操作（阻塞 IO、长时间 CPU 计算）
- 写缓冲区未发完时，需要继续注册写就绪事件，不能丢弃

### 🎤 面试官可能问的点

- 如何在 event loop 中管理多个连接的状态？
- 什么是回调式编程（callback-based programming）？
- 为什么 event loop 中的每个回调必须尽快返回？
- 请描述一个基于 `poll()` 的简单事件循环的伪代码实现

---

## Ch07 — 基础 KV 服务器

### 📚 知识点

- 用标准容器（如 `std::map`）作为占位实现 KV 存储
- 支持基本命令：`GET`、`SET`、`DEL`
- 命令解析：从字节流中解析命令字符串和参数
- 响应编码：状态码 + 数据

### ⚡ 要点

- 服务器架构：socket 接受连接 → event loop 驱动 → 命令解析 → KV 操作 → 返回响应
- fd-to-connection 映射可以用 `std::vector<Conn *> fd2conn` 实现（以 fd 为下标的数组）

### ⚠️ 注意事项

- `std::map` 是 O(log N) 的，后续章节会替换为 O(1) 的哈希表

### 🎤 面试官可能问的点

- Redis 的命令处理流程是什么？
- 为什么 `std::map` 不适合作为 Redis 的底层存储？

---

## Ch08 — 哈希表

### 📚 知识点

**两类哈希表：**
- 链式哈希（Chaining）：每个 slot 是一个链表/数组，冲突的 key 放在同一 slot
- 开放地址（Open Addressing）：冲突时探测下一个空 slot（线性探测、双重哈希等）

**哈希表核心概念：**
- 负载因子（Load Factor） = keys / slots
- 超过最大负载因子时触发 **rehashing**（扩容）
- 哈希函数的作用：将任意类型的 key 映射为均匀分布的整数，减少碰撞

**渐进式 Rehashing（Progressive Resizing）：**
- 问题：直接扩容是 O(N) 操作，导致最坏延迟
- 解决：分配新表后，每次操作时迁移固定数量的 key，直到迁移完成
- 迁移期间需同时查询新旧两张表
- 用 `calloc()` 代替 `malloc() + memset()`，避免大数组初始化的 O(N) 开销（利用 mmap 懒初始化）

**侵入式数据结构（Intrusive Data Structures）：**
```c
// 普通方式：数据包含结构
struct Node { void *data; struct Node *next; };

// 侵入式：结构嵌入数据
struct HashNode { HashNode *next; };
struct MyData {
    int value;
    HashNode node;  // 嵌入的结构
};
// 获取数据：container_of(pnode, MyData, node)
```

**`container_of` 宏：**
```c
#define container_of(ptr, T, member) \
    ((T *)((char *)ptr - offsetof(T, member)))
```

**侵入式数据结构的优点：**
1. 直接访问数据，无指针跳转
2. 减少动态内存分配
3. 同一数据节点可同时属于多个数据结构（如 Redis sorted set 同时被 hash 和 tree 索引）
4. 同一集合中可存放不同类型

### ⚡ 要点

- 链式哈希比开放地址在碰撞处理上更健壮、更简单
- 使用链表的链式哈希：插入 O(1)，删除 O(1)（找到节点后），指针稳定性好
- Redis 使用渐进式 rehashing 来避免扩容时的高延迟峰值
- `calloc()` 在分配大数组时利用操作系统的懒初始化（mmap），性能远优于 `malloc + memset`

### ⚠️ 注意事项

- 哈希函数即使 key 已经是整数也是必要的（例如 key 是指针，按 8 字节对齐，直接取模会浪费大量 slot）
- 最坏情况：所有 key 映射到同一 slot，查找退化为 O(N)
- 吞吐量问题（throughput）和延迟问题（latency）需区别对待：延迟是最坏情况问题，更难解决
- STL 的 `std::unordered_map` 不支持渐进式 rehashing，不适合大规模生产部署

### 🎤 面试官可能问的点

- 哈希冲突是什么？如何解决？链式 vs 开放地址各有什么优缺点？
- 什么是负载因子？超过阈值后发生什么？
- Redis 哈希表扩容时为什么不会阻塞服务？（渐进式 rehashing）
- 为什么 `calloc()` 比 `malloc() + memset()` 在大数组上更优？
- 什么是侵入式数据结构？它有哪些优势？
- `container_of` 宏的原理是什么？

---

## Ch09 — 数据序列化

### 📚 知识点

**序列化的目的：**
- 网络只传输字节（0/1），需要将高层对象（字符串、整数、列表）转为字节，再从字节还原

**常见序列化方式：**
- 文本格式：JSON、XML（简单但低效）
- 二进制格式：Protobuf、MessagePack（高效但需 schema）
- 自定义二进制格式（本书方式）

**本书协议设计：**
- 请求：`[4字节长度][N字节内容]` (length-prefixed)
- 响应：`[1字节类型][内容]`，类型包括 Nil、Error、Integer、String、Array

### ⚡ 要点

- 自定义序列化是学习低级编程的好机会
- 协议设计需要考虑：边界检测、错误处理、向后兼容性

### ⚠️ 注意事项

- 多字节整数需要注意字节序（endianness），网络通常使用大端（big-endian）
- 解析时必须处理不完整数据（partial data）的情况

### 🎤 面试官可能问的点

- 什么是序列化和反序列化？
- 大端和小端的区别？网络传输一般用哪种？
- Redis 的 RESP（Redis Serialization Protocol）协议是什么？它的设计特点？

---

## Ch10 — 平衡二叉树（AVL Tree）

### 📚 知识点

**为什么需要排序数据结构：**
- Sorted Set 需要按 score 排序，哈希表无法提供顺序查询
- 排序数据结构：AVL tree、RB tree、B-tree、Skip list

**树的对比：**

| 树 | 最坏情况 | 分支数 | 随机性 | 难度 |
|----|----------|--------|--------|------|
| AVL tree | O(log N) | 2 | 否 | 中 |
| RB tree | O(log N) | 2 | 否 | 高 |
| B-tree | O(log N) | n | 否 | 高 |
| Skip list | O(N) | n | 是 | 中 |
| Treap | O(N) | 2 | 是 | 低 |

**不平衡树的问题：**
- 按升序插入时，树退化为链表，查找复杂度变为 O(N)

**AVL 树的不变量：**
- 任意节点的左右子树高度差不超过 1

**AVL 树核心操作：**
- **旋转（Rotation）**：在保持数据顺序的前提下改变树的形状
  - 左旋（rotate-left）、右旋（rotate-right）
- **平衡修复（avl_fix）**：在插入/删除后，从被修改节点向上传播，修复高度差为 2 的节点
  - 情况1（外侧更高）：单次旋转
  - 情况2（内侧更高）：先旋转子节点，再旋转当前节点（双旋）
- **节点删除**：
  - 简单情况（0或1个子节点）：用子节点替代
  - 复杂情况（2个子节点）：找到后继节点（右子树最左节点），与后继节点交换

**关键辅助数据：**
- 每个节点存储子树高度（`uint32_t height`）
- 父指针（`parent`）用于自底向上传播

**节点分离与插入伪代码：**
```c
// 插入
void search_and_insert(AVLNode **root, AVLNode *new_node, ...) {
    // 找到插入位置
    *from = new_node;
    new_node->parent = parent;
    *root = avl_fix(new_node);  // 修复平衡
}
```

**多索引数据（Multi-indexed Data）：**
- Sorted Set 同时按 name（哈希）和 score（AVL tree）索引
- 侵入式数据结构使得一个节点可同时属于两个数据结构

### ⚡ 要点

- AVL 树是最容易实现且保证最坏 O(log N) 的平衡二叉树
- 真实 Redis 的 Sorted Set 使用 Skip list；本书使用 AVL 树替代
- 数据库排序索引（B+tree、LSM-tree）也属于排序数据结构范畴

### ⚠️ 注意事项

- 旋转后，**父节点到子节点的链接由调用者负责更新**（旋转函数只更新子节点的父指针）
- 删除有两个子节点的节点时，必须先将后继节点取出，再与目标节点"交换位置"
- 高度存储的是子树最大深度，不是节点数量

### 🎤 面试官可能问的点

- AVL 树和红黑树的区别？各自适合什么场景？
- 二叉树旋转是什么？有什么作用？
- AVL 树插入后如何保持平衡？（高度差不超过1，通过旋转修复）
- Redis Sorted Set 底层用的是什么数据结构？为什么？
- B-tree 和 BST 在数据库索引中各有什么应用？

---

## Ch11 — 有序集合（Sorted Set）

### 📚 知识点

**Sorted Set 结构：**
```cpp
struct SortedSet {
    AVLTree  by_score;   // 按 (score, name) 排序
    HashMap  by_name;    // 按 name 查找
};
```

**操作：**
- `ZADD key score member`：添加/更新成员
- `ZREM key member`：删除成员
- `ZSCORE key member`：查询分数
- `ZQUERY key score name offset limit`：范围查询

**Tuple 比较：**
- `(score1, name1) < (score2, name2)` ⟺ `score1 < score2 || (score1 == score2 && name1 < name2)`
- score 相同时按 name 字典序排列

### ⚡ 要点

- name 唯一，score 不唯一
- 双索引设计：按 score 范围查询用 AVL tree，按 name 直接删除/更新用 HashMap
- 这是侵入式数据结构的典型应用场景

### ⚠️ 注意事项

- 更新 score 时必须同时更新两个索引
- score 使用 64-bit float（`double`），浮点比较需注意精度问题

### 🎤 面试官可能问的点

- Redis Sorted Set 支持哪些操作？
- 为什么 Sorted Set 需要两个数据结构（哈希 + 有序结构）？
- 如何实现 `ZRANGE`（按分数范围查询）？
- Skip List 相比 AVL/RB tree 的优势是什么？（实现简单、范围查询缓存友好）

---

## Ch12 — 定时器与超时

### 📚 知识点

**定时器的使用场景：**
- TTL / 缓存过期
- 网络 IO 超时
- 关闭空闲连接

**时间获取：**
```c
clock_gettime(CLOCK_MONOTONIC, &tv);
// CLOCK_REALTIME：挂钟时间，可被调整，不适合计时
// CLOCK_MONOTONIC：单调时间，只增不减，适合计时
```

**定时器数据结构选择：**
- 超时值固定时 → **有序链表（FIFO）**：添加到尾部，O(1)
- 超时值任意时 → **堆（Heap）** 或 AVL tree：找最小 O(1)/O(log N)，更新 O(log N)

**双向链表用于 idle timeout：**
```c
struct DList {
    DList *prev = NULL;
    DList *next = NULL;
};
```
- 用哨兵节点（dummy node）避免空链表特判
- 每次 IO 时将连接移到链表尾部（重置 timer）
- 检查链表头部节点是否超时

**poll() 的 timeout 参数：**
```c
int poll(struct pollfd *fds, nfds_t nfds, int timeout); // ms，-1 表示永不超时
```
- 每次进入 poll 前，计算最近定时器的剩余时间作为 timeout

### ⚡ 要点

- 排序问题的本质：让事情在特定时间发生 = 让事情按时间顺序发生
- 空闲连接 timeout 用 FIFO 链表更高效（因为超时值相同，按插入顺序即为排序顺序）
- 每次 event loop 循环结束后调用 `process_timers()` 处理到期的 timer

### ⚠️ 注意事项

- 必须使用 `CLOCK_MONOTONIC` 而非 `CLOCK_REALTIME`，因为 wall time 可能被 NTP 调整导致计时错误
- `poll()` 唤醒可能来自 IO 事件，此时定时器未必到期，`process_timers()` 必须检查实际时间

### 🎤 面试官可能问的点

- Redis 如何实现连接超时？
- `CLOCK_REALTIME` 和 `CLOCK_MONOTONIC` 的区别？为什么定时器用单调时钟？
- 如何在 event loop 中集成定时器？
- 为什么 idle 连接超时适合用 FIFO 链表而不是堆？

---

## Ch13 — TTL 与缓存过期（Heap）

### 📚 知识点

**堆（Heap）数据结构：**
- 最小堆：每个节点的值 ≤ 其子节点的值，根节点是最小值
- 用**数组**编码（隐式树），不需要指针
- 父子关系：`left(i) = 2i+1`，`right(i) = 2i+2`，`parent(i) = (i+1)/2 - 1`
- 约束：除最后一层外每层必须填满

**堆 vs BST：**
- 堆：找最小 O(1)，更新 O(log N)，数组存储，无指针开销
- BST（AVL）：找最小 O(log N)（可缓存为 O(1)），但实现复杂，有指针开销

**堆的核心操作：**
```c
heap_up(a, pos)    // 值变小时，向上冒泡
heap_down(a, pos)  // 值变大时，向下沉
heap_update(a, pos, len)  // 统一入口，判断方向
```

**删除堆中任意元素：**
1. 用最后一个元素替换目标元素
2. 从数组中弹出最后一个元素
3. 对替换后的位置调用 `heap_update()`

**TTL 实现细节：**
- `Entry` 结构中维护 `heap_idx`，记录在堆中的下标
- 堆中每个 `HeapItem` 的 `ref` 指向 `Entry::heap_idx`（而不是 `Entry*`）
- 堆内部移动元素时，通过 `*ref = new_pos` 更新 Entry 中的下标 → 无需知道 Entry 的具体类型（泛型设计）

**限制每次循环的工作量：**
```c
const size_t k_max_works = 2000;
// 防止大量 key 同时到期导致 event loop 卡顿
```

### ⚡ 要点

- Heap 是定时器的最优选择：比 FIFO 更通用（任意超时值），比 AVL 树更轻量
- 用 `HeapItem::ref` 指向 index 而非对象指针，使堆代码与业务数据解耦
- 删除元素时用"末尾替换"技巧（O(1) 删除节点，O(log N) 恢复堆性质）

### ⚠️ 注意事项

- 堆和 BST（二叉搜索树）完全不同：堆不维护全序，只能找最小/最大值
- 每次元素移动时必须同步更新 `Entry::heap_idx`，否则索引失效
- 大量 key 同时过期时需要限制单次处理量，分多次循环处理

### 🎤 面试官可能问的点

- 堆是什么？最小堆和最大堆的区别？
- 堆为什么可以用数组表示？父子关系如何计算？
- `heap_up` 和 `heap_down` 各在什么情况下触发？
- Redis 的 TTL 是如何实现的？懒删除（lazy expiration）和定时删除（active expiration）各自的优缺点？
- 如何从堆中删除任意位置的元素？时间复杂度是多少？

---

## Ch14 — 线程池

### 📚 知识点

**为什么 event loop 需要线程池：**
- 阻塞 IO（如 libc 的 DNS 解析 `getaddrinfo`、libcurl 等）无法在 event loop 中使用
- CPU 密集型操作（如析构大型有序集合）会使 event loop 卡顿

**生产者-消费者模型：**
- 生产者（event loop）提交任务到队列
- 消费者（worker 线程）从队列取任务执行

**同步原语（Synchronization Primitives）：**

| 层级 | 原语 | 特点 |
|------|------|------|
| 低级 | Linux futex / Windows WaitOnAddress | 最通用，难以直接使用 |
| 高级 | Mutex、Condition Variable、Semaphore | 必须掌握，解决大多数多线程问题 |
| 更高级 | Concurrent queue、Thread pool、Go channel | 易用但场景受限 |

**互斥锁（Mutex）：**
- 同一时刻只有一个线程持有锁
- Spinlock：忙等待（busy waiting），浪费 CPU，仅用于极短临界区
- 普通 mutex：持有者睡眠等待，适合一般场景

**信号量（Semaphore）：**
- 整数计数器，lock 减1，unlock 加1，为负时睡眠
- Mutex 是 Semaphore 的特例（初始值为1）
- 实践中不如 condition variable 直观

**条件变量（Condition Variable）：**
```c
// 消费者等待队列非空
mutex.lock()
while (queue.empty()) {
    cond.wait(mutex)  // 原子地: 释放锁 + 睡眠
                      // 唤醒后: 重新获取锁
}
// 生产者
mutex.lock()
queue.push(work)
cond.signal()         // 唤醒一个等待的消费者
mutex.unlock()
```

**为什么必须在循环中检查条件（spurious wakeup）：**
- 多个消费者时，被 `signal()` 唤醒的线程可能被其他消费者"抢先"，队列再次变空

**pthread API：**
```c
pthread_create()    // 创建线程
pthread_join()      // 等待线程结束
pthread_mutex_lock() / unlock()
pthread_cond_wait() / signal() / broadcast()
```

**线程池实现：**
```c
struct ThreadPool {
    std::vector<pthread_t> threads;
    std::deque<Work> queue;
    pthread_mutex_t mu;
    pthread_cond_t not_empty;
};
```

**向 event loop 发送结果（pipe 技巧）：**
- 其他线程写入 pipe 的写端（1字节垃圾数据）
- event loop `poll()` 监听 pipe 的读端
- event loop 被唤醒后处理结果
- 实际结果数据不通过 pipe 传输，只用 pipe 作为信号

### ⚡ 要点

- **条件变量是解决多线程等待问题的通用方案**，掌握 mutex + condition variable 就能解决绝大多数多线程问题
- `cond.wait()` 是原子操作：释放锁 + 睡眠，防止生产者在消费者睡眠之前 signal 而丢失信号
- 线程不可随意 kill（线程共享进程资源，kill 会导致资源泄漏），只能让线程自然结束

### ⚠️ 注意事项

- 条件变量的检查**必须在 while 循环中**，不能用 if（spurious wakeup）
- 线程池用于大型数据结构的异步析构时，需要设置大小阈值，小对象直接同步删除（避免频繁上下文切换）
- `pthread_cond_timedwait` 默认不使用单调时钟，需手动设置 `CLOCK_MONOTONIC`

### 🎤 面试官可能问的点

- 什么是生产者-消费者问题？如何用 mutex + condition variable 解决？
- 条件变量为什么要在 while 循环中检查条件？什么是 spurious wakeup？
- Mutex 和 Semaphore 的区别？
- Redis 是单线程的，那它为什么还需要线程池？（磁盘持久化、大型数据结构析构、异步 UNLINK）
- 如何安全地从工作线程向 event loop 发送通知？（pipe/eventfd）
- 什么是死锁（deadlock）？如何避免？

---

## 🔥 综合面试高频题

### 系统设计类

1. 从零设计一个 Redis，你会考虑哪些核心模块？
2. Redis 为什么这么快？（内存存储 + 单线程事件循环 + 高效数据结构）
3. Redis 如何保证单线程下的高并发？（event loop + 非阻塞 IO + epoll）
4. Redis 的内存如何管理？如何防止内存耗尽？（TTL + maxmemory + 淘汰策略）

### 数据结构类

5. Redis 中各种数据类型（String/Hash/List/Set/Sorted Set）的底层实现？
6. 哈希表扩容时如何保证低延迟？（渐进式 rehashing）
7. 为什么 Sorted Set 要同时维护一个哈希表和一个有序结构？
8. Heap 和 BST 在定时器场景下各有什么优缺点？

### 网络编程类

9. epoll 的工作原理？LT（水平触发）和 ET（边缘触发）的区别？
10. 什么是 C10K 问题？现代解决方案是什么？
11. TCP 粘包问题是什么？如何解决？
12. 非阻塞 IO 中如何处理 `EAGAIN`？

### 并发类

13. Redis 6.0 引入了多线程，它多线程处理什么？（网络 IO），什么仍然是单线程的？（命令执行）
14. 什么是原子操作？为什么它不能替代 mutex？
15. 如何避免多线程程序中的竞态条件（race condition）？

---

*文档整理自 [Build Your Own Redis with C/C++](https://build-your-own.org/redis/)，供学习和面试参考。*
