# 🌐 VPS 工具箱 v3.0

> 🚀 一键优化、测速、管理你的 VPS — 让服务器运行更高效、更安全！

<div align="center">

[![版本](https://img.shields.io/badge/版本-v3.0-blue.svg?style=for-the-badge)](https://github.com/chengege666/bbr-gj)
[![系统支持](https://img.shields.io/badge/支持系统-Debian%20%7C%20Ubuntu%20%7C%20CentOS%20%7C%20Fedora-green.svg?style=for-the-badge)](https://github.com/chengege666/bbr-gj)
[![语言](https://img.shields.io/badge/语言-Bash-orange.svg?style=for-the-badge)](https://www.gnu.org/software/bash/)
[![许可证](https://img.shields.io/badge/许可证-MIT-lightgrey.svg?style=for-the-badge)](LICENSE)

</div>

---

## 📚 目录

- [📖 简介](#-简介)
- [🚀 一键安装与运行](#-一键安装与运行)
- [🧰 功能列表](#-功能列表)
  - [🟢 BBR 功能区](#-bbr-功能区)
  - [⚙️ VPS 系统管理](#️-vps-系统管理)
  - [🧩 服务与安全管理](#-服务与安全管理)
  - [🧹 其他功能](#-其他功能)
- [🧾 测速结果](#-测速结果)
- [🧠 系统兼容与依赖](#-系统兼容与依赖)
- [⚠️ 注意事项](#️-注意事项)
- [🧩 文件说明](#-文件说明)
- [🧰 卸载脚本](#-卸载脚本)
- [💡 作者与鸣谢](#-作者与鸣谢)
- [⭐ 建议反馈](#-建议反馈)

---

## 📖 简介

**VPS 工具箱 v3.0** 是一款集 **BBR 网络优化、系统管理、Docker 管理、GLIBC 管理、SSH 安全配置** 于一体的综合 VPS 优化脚本。  

支持自动检测包管理器，兼容多种 Linux 系统，交互式菜单清晰直观，功能强大，一键操作、无需复杂命令。  
非常适合 VPS 用户、站长、服务器运维人员使用。

---

## 🚀 一键安装与运行

### ✅ 推荐命令
```bash
bash <(curl -L -s https://raw.githubusercontent.com/chengege666/bbr-gj/main/vpsgj.sh)


wget -O vpsgj.sh https://raw.githubusercontent.com/chengege666/bbr-gj/main/vpsgj.sh
chmod +x vpsgj.sh
sudo ./vpsgj.sh
⚠️ 必须使用 root 权限 运行，否则脚本会自动退出。

| 编号 | 功能名称             | 说明                                                  |
| -- | ---------------- | --------------------------------------------------- |
| 1  | **BBR 综合测速**     | 自动测试并对比 BBR / BBR Plus / BBRv2 / BBRv3 的实际性能，输出结果文件 |
| 2  | **安装/切换 BBR 内核** | 调用 ylx2016/Linux-NetSpeed 脚本实现 BBR 内核切换             |

| 编号 | 功能名称             | 说明                                   |
| -- | ---------------- | ------------------------------------ |
| 3  | **查看系统信息**       | 显示 CPU、内存、磁盘、网络、GLIBC、BBR 算法、系统负载等信息 |
| 4  | **系统更新**         | 更新软件包列表并升级已安装软件（不升级内核）               |
| 5  | **系统清理**         | 清理系统缓存和无用依赖包（支持 apt/yum/dnf 自动识别）    |
| 6  | **IPv4/IPv6 切换** | 一键切换当前使用的 IP 协议版本                    |
| 7  | **系统时区调整**       | 快速设置上海/纽约/自定义时区                      |
| 8  | **系统重启**         | 安全重启系统                               |
| 9  | **GLIBC 管理**     | 查询与升级 GLIBC 版本（带风险提示）                |
| 10 | **全面系统升级**       | 升级系统内核及所有依赖包（建议提前备份）                 |


| 编号 | 功能名称          | 说明                              |
| -- | ------------- | ------------------------------- |
| 11 | **Docker 管理** | 一键安装、启动、查看 Docker 服务及容器状态       |
| 12 | **SSH 配置修改**  | 修改 SSH 登录端口、root 密码并自动重启 SSH 服务 |


| 编号 | 功能名称     | 说明          |
| -- | -------- | ----------- |
| 13 | **卸载脚本** | 一键卸载脚本及残留文件 |
| 0  | **退出脚本** | 返回系统命令行     |


🧾 测速结果

测速结果会自动保存到：

bbr_result.txt


示例：

BBR | Ping: 24.36ms | Down: 321.42 Mbps | Up: 142.13 Mbps
BBR Plus | Ping: 25.12ms | Down: 318.21 Mbps | Up: 139.77 Mbps

🧠 系统兼容与依赖

脚本自动检测系统并安装必要依赖：

curl wget git speedtest-cli net-tools build-essential


支持系统：

✅ Debian 8+

✅ Ubuntu 16.04+

✅ CentOS 7+

✅ Fedora 30+

⚠️ 其他 Linux 系统需手动安装依赖

⚠️ 注意事项

必须使用 root 权限 运行

测速功能 依赖 speedtest-cli（脚本自动安装）

GLIBC 升级有风险，请先备份系统

切换 SSH 端口后 请立刻用新端口连接

BBR 测试不会修改系统，只用于临时测速

Docker 管理功能需 systemd 支持

| 文件名                              | 说明               |
| -------------------------------- | ---------------- |
| `vpsgj.sh`                       | 主脚本文件            |
| `bbr_result.txt`                 | BBR 测速结果文件       |
| `tcp.sh`                         | 临时下载的 BBR 内核管理脚本 |
| `vps_toolbox_uninstall_done.txt` | 卸载完成标记文件         |


🧰 卸载脚本

执行主脚本后选择：

13) 卸载脚本及残留文件


或手动执行：

rm -f vpsgj.sh bbr_result.txt tcp.sh

💡 作者与鸣谢

👨‍💻 作者：陈哥哥（@chengege666
）

🧩 参考项目：ylx2016/Linux-NetSpeed

💬 语言：Bash

📜 开源协议：MIT License

⭐ 建议反馈

如果脚本对你有帮助，欢迎：

⭐ 给项目一个 Star

🧠 提交 Issue 建议新功能或报告问题

💬 分享给更多使用 VPS 的朋友！

<div align="center">

🌀 Made with ❤️ by 陈哥哥 🌀

</div> ```
