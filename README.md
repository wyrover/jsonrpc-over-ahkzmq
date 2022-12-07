# jsonrpc-over-ahkzmq


在 ahkzmq 的基础上封装一个 jsonrpc 客户端

待实现:
1. jsonrpc 双向调用
2. 调用到 ahk 端，最好是 ui 线程，且是短任务，ahk 调用到服务器端可以是长任务
3. zeromq DEALER 和 ROUTER 模式本身支持异步消息，所以 jsonrpc 也是异步的