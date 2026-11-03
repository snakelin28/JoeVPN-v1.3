# Joe's Lightsail Installer v1.3 (JoeVPN)

一键在 Lightsail / 任意 Ubuntu·Debian VPS 上部署 **Hysteria2 + VLESS Reality + AnyTLS**，
自带 BBR、IPv4/IPv6 转发、QUIC/TCP 缓冲优化、按内存自适应，并自动生成客户端配置。

针对 **Apple TV+ / Netflix / Disney+ / YouTube** 这类长时间、高码率、持续
UDP/TCP 流量做了内核层优化。

| 节点 | 端口 | 定位 |
|---|---|---|
| Reality | TCP 443 | 主力，借用真实网站证书伪装 |
| Hysteria2 | UDP 8443 | 拼速度，丢包/晚高峰线路最快 |
| AnyTLS | TCP 8443 | 备用 TCP 通道，抗 TLS-in-TLS 识别（v1.3 新增） |

## 一键安装（Lightsail 网页 SSH）

1. 新建实例（Ubuntu 22.04/24.04）→ **立刻绑 Static IP**
2. Networking → IPv4 Firewall 放行：**TCP 443 / UDP 8443 / TCP 8443 / TCP 6060**
3. 实例页点 **Connect using SSH**，粘这一行：

```bash
curl -fsSL https://github.com/<你的GitHub用户名>/JoeVPN/archive/refs/heads/main.tar.gz | tar xz && cd JoeVPN-main && sudo bash install.sh
```

4. 终端里出现订阅二维码 → 小飞机扫码。扫不出就复制上面三条 vless:// / hysteria2:// / anytls:// 裸链接。
5. `sudo bash backup.sh`，把打印出来的凭据几行存进密码管理器。

实例刚建好就跑也没关系：脚本会先等开机初始化（apt 锁）结束再装。
网页 SSH 中途断了：重新连上，`cd JoeVPN-main && sudo bash install.sh` 再跑一次即可，
凭据会复用，不会重新生成。

## 换 VPS（复用同一套节点，客户端只需重新扫码/换 IP）

新机器上先下载、**先不装**：

```bash
curl -fsSL https://github.com/<你的GitHub用户名>/JoeVPN/archive/refs/heads/main.tar.gz | tar xz && cd JoeVPN-main
nano config.conf      # 把密码管理器里存的 UUID / REALITY_* / HY2_PASSWORD / ANYTLS_PASSWORD / SUB_TOKEN 填回去
sudo bash install.sh
```

> 想换全新凭据：什么都不填直接装。
> 旧备份里没有 `ANYTLS_PASSWORD` 也没关系：留空会自动生成一个，Reality / Hy2 照常复用。

## 已在跑 v1.2 的服务器升级到 v1.3（可选）

⚠ 重新下载会**覆盖** `JoeVPN-main/config.conf`（变回空白模板），所以先把旧的存出来：

```bash
sudo cp ~/JoeVPN-main/config.conf ~/joevpn-config.bak
cd ~ && curl -fsSL https://github.com/<你的GitHub用户名>/JoeVPN/archive/refs/heads/main.tar.gz | tar xz
sudo cp ~/joevpn-config.bak ~/JoeVPN-main/config.conf
cd JoeVPN-main && sudo bash install.sh
```

Reality / Hy2 凭据和订阅路径都不变，客户端里**更新一下订阅**就会多出 AnyTLS 节点。
别忘了 Lightsail 控制台防火墙加一条 TCP 8443。

## ⚠ 仓库是公开的

- 仓库里的 `config.conf` 凭据字段**永远保持为空**。
- 服务器上跑完后的 `config.conf` 已写入凭据，**不要**从服务器往 GitHub 推任何东西。
- 改脚本只在本地干净副本里改，再上传到 GitHub。

## 目录

| 文件/目录 | 作用 |
|---|---|
| `install.sh` | 一键安装（编排全流程） |
| `update.sh` | 只升级 sing-box 内核 |
| `uninstall.sh` | 卸载 |
| `backup.sh` | 打包配置+证书+凭据 |
| `restore.sh` | 从备份恢复 |
| `config.conf` | 所有可配置参数 + 凭据 |
| `lib/` | 各功能模块（`anytls.sh` 为 v1.3 新增） |
| `templates/` | 服务端/客户端配置模板 |
| `clients/` | 生成的客户端配置输出 |

## AnyTLS 说明

- **不需要域名**：复用 Hysteria2 的那张自签证书，客户端跳过证书验证（订阅/链接里已自动设好）。
- **需要 sing-box ≥ 1.12**：脚本装的是最新版，满足；若 `SB_VERSION` 固定了更老的版本，
  脚本会自动跳过 AnyTLS，只装另外两个节点，不会报错中断。
- **不想要 AnyTLS**：`config.conf` 里 `ENABLE_ANYTLS=0`，重跑 `install.sh`。
- **客户端要够新**：小飞机、Clash Verge Rev、mihomo、sing-box 的较新版本才认 `anytls`。
  扫码后如果这个节点报"不支持的类型"或者没出现，先升级客户端。

## 内存自适应

脚本按总内存自动分档：

| 档位 | 内存 | 处理 |
|---|---|---|
| small | <1GB (512MB) | QUIC/TCP 缓冲上限 16MB，自动建 2G swap，低 swappiness |
| medium | 1–2GB | 缓冲上限 25MB |
| large | 2GB+ | 缓冲上限 32MB |

## 重要提醒（脚本管不到的部分）

- **Lightsail 控制台防火墙**要手动放行 `TCP 443` + `UDP 8443` + `TCP 8443` + `TCP 6060`。
- 给实例绑 **Static IP**，否则重启后公网 IP 变、客户端全失效。
- Clash 端必须用新内核（Clash.Meta / mihomo / Verge Rev / Stash）才认
  hysteria2 / reality / anytls。
- 备份文件含全部凭据，存密码管理器或加密盘，别放公开网盘/Gist。

## 自托管订阅服务

安装完自动在 `SUB_PORT`(默认 6060)起一个订阅服务，生成 YAML 订阅链接
+ 终端二维码，小飞机/Clash 扫码即可添加订阅。

- 随机 32 位路径防扫描，链接形如 `http://IP:6060/<随机串>/JoeVPN.yaml`
- 同一路径下还有 base64 版 `http://IP:6060/<随机串>/sub.txt`（终端里一并打印），
  小飞机对 YAML 解析不全、缺节点时改用这条
- **Lightsail 控制台防火墙需额外放行 TCP 6060**，否则客户端拉不到订阅
- 换 VPS / 公网 IP 变了，订阅链接会变，需重新导入
- 链接含凭据且走明文 HTTP，别外传、别贴公开处；所有设备导入完后建议关掉
  6060 端口（或 `sudo systemctl stop joevpn-sub`），要再导入时再打开

> 裸链接(links.txt)始终可本地导入，不依赖订阅服务。

## 更新日志

- **v1.3**：新增 AnyTLS 节点（TCP 8443，复用自签证书，可用 `ENABLE_ANYTLS` 关闭）；
  订阅服务同时发布 base64 `sub.txt`；backup.sh 输出加入 `ANYTLS_PASSWORD`；
  README 统一版本号、补全防火墙端口说明。
- **v1.2**：Hysteria2 + VLESS Reality，自托管订阅 + 二维码。
