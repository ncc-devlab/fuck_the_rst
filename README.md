# SSH RST Guard

这是一个 TC ingress eBPF 过滤器：进入本机的 TCP RST 只有在携带指定的尾部 TCP 选项时才会被接受，否则丢弃。过滤器只检查源端口或目的端口为 `22` 的 TCP 流量。

## 魔数格式

允许的最后一个 TCP option 为：

```text
kind = 254                 # TCP experimental option
length = 10
data = 52 53 54 47 55 41 52 44  # ASCII "RSTGUARD"
```

该 option 必须是 TCP options 中的最后一段。发送端需要在 RST 报文的 TCP 头部增加该 option；普通 RST 不会被接受。

## 构建与挂载

```sh
make
sudo tc qdisc replace dev eth0 clsact
sudo tc filter replace dev eth0 ingress bpf da obj rst_guard.bpf.o sec classifier
```

客户端还要在出口方向挂载同一个对象。它会把本机 TCP 栈生成的、无数据的 IPv4 SSH RST 改写为带 `RSTGUARD` option 的 RST；入口规则则继续丢弃没有魔数的远端 RST：

```sh
sudo tc filter replace dev eth0 egress bpf da obj rst_guard.bpf.o sec classifier/egress
```

出口程序只处理本机生成的 IPv4、无 TCP payload、端口为 22 的 RST。它不会把普通出站数据包改成 RST，也不会阻止本机释放连接。

卸载：

```sh
sudo tc filter del dev eth0 ingress
sudo tc qdisc del dev eth0 clsact
```

把 `eth0` 换成实际接收 SSH 流量的网卡。过滤器不会挂到 egress，因此本机内核主动发送的 RST、FIN 或普通 TCP 释放不会被拦截；SSH 没有心跳时，本机仍可正常释放连接。

## 限制

- 这是按网卡 ingress 方向过滤，不是按进程过滤；目标是端口 22 的所有 TCP RST。
- 程序只解析 Ethernet、单层 VLAN、IPv4 和 IPv6 的直接 TCP；IPv6 扩展头、隧道和多层 VLAN 会放行，不会误丢弃。
- 服务端需要发送端能够构造带实验性 TCP option 的 RST；普通 `sshd`、内核 TCP 栈或防火墙生成的远端 RST 通常不会自动带此 option。客户端挂载出口程序后，本机生成的符合条件的 IPv4 RST 会自动改写。
- 客户端出口改写支持 IPv4 的无数据 RST；IPv6、带 payload、GSO/分片或已有复杂封装的 RST 会保持原样。
- 如果想保护多个 SSH 端口，应修改 `SSH_PORT`；不要把该规则用于所有 TCP 端口。
