# CGG-VPS 脚本管理菜单

## 1. 项目概述

CGG-VPS 脚本管理菜单是一个功能丰富的 Bash 脚本，旨在简化 VPS（虚拟专用服务器）的日常管理、优化和测试任务。它提供了一个交互式菜单界面，用户可以通过简单的数字选择来执行各种操作，从而无需记忆复杂的 Linux 命令。该脚本集成了系统信息查看、系统更新与清理、BBR 加速管理、Docker 容器管理、多种系统工具、网络性能测试、安全扫描以及文件完整性检查等功能，极大地提高了 VPS 管理的效率和便捷性。

**主要特点：**

*   **一站式管理：** 整合了 VPS 管理所需的绝大多数功能，避免了频繁切换工具的麻烦。
*   **交互式菜单：** 提供清晰易懂的菜单界面，操作简单直观，适合不同经验水平的用户。
*   **自动化操作：** 许多复杂的操作（如 BBR 安装、Docker 安装、系统清理）都已自动化，减少了手动干预。
*   **性能优化：** 包含 BBR 加速、内存清理、Swap 管理等功能，帮助提升服务器性能。
*   **安全增强：** 提供防火墙管理、安全扫描、文件完整性检查等工具，增强服务器安全性。
*   **网络测试：** 集成多种网络测速和路由追踪工具，方便用户评估网络质量。
*   **跨平台兼容：** 兼容主流 Linux 发行版（如 Debian, Ubuntu, CentOS, RHEL, Fedora）。

## 2. 安装指南

### 2.1 准备工作

*   确保您的 VPS 具有 `root` 权限。
*   确保您的系统已安装 `curl` 或 `wget`。如果未安装，脚本会尝试自动安装。您也可以手动安装，例如对于 Debian/Ubuntu 系统使用 `sudo apt update && sudo apt install -y curl wget`，对于 CentOS/RHEL 系统使用 `sudo yum install -y curl wget` 或 `sudo dnf install -y curl wget`。

### 2.2 下载并运行脚本

您可以通过以下命令下载并运行脚本：

```bash
wget -O vpsgj.sh https://raw.githubusercontent.com/cggos/vpsgj/main/vpsgj.sh && chmod +x vpsgj.sh && bash vpsgj.sh
```
或者
```bash
curl -o vpsgj.sh https://raw.githubusercontent.com/cggos/vpsgj/main/vpsgj.sh && chmod +x vpsgj.sh && bash vpsgj.sh
```

脚本将自动检查并安装所需的依赖项，然后显示主菜单。

## 3. 使用说明

运行脚本后，您将看到一个主菜单，其中列出了所有可用的功能。通过输入对应的数字并按回车键即可选择并执行相应的功能。

### 3.1 主菜单概览

```
==========================================
           CGG-VPS 脚本管理菜单 v5.1
==========================================
1. 查看系统信息
2. 系统更新
3. 系统清理
4. 基本工具
5. BBR 加速管理
6. Docker 管理
7. 系统工具菜单
8. VPS 网络全面测试
0. 退出脚本
==========================================
```

### 3.2 功能模块详解

#### 3.2.1 系统信息 (选项 1)

显示操作系统、CPU、内存、磁盘、网络、BBR 状态、GLIBC 版本、系统运行时间、系统负载和进程信息等详细系统信息。

#### 3.2.2 系统更新 (选项 2)

根据您的 Linux 发行版（Debian/Ubuntu 或 CentOS/RHEL），执行系统软件包更新。

#### 3.2.3 系统清理 (选项 3)

执行深度系统清理，包括：

*   清理旧内核
*   清理日志文件
*   删除临时文件
*   清理缓存（缩略图、浏览器、软件包列表）
*   删除崩溃报告
*   通用清理操作

并显示清理前后磁盘空间对比。

#### 3.2.4 基本工具 (选项 4)

此菜单下包含以下功能：

*   **VPS 测试 IP 网络：** 提供多个测试 IP，用于测试 VPS 的网络连通性。
*   **Docker 管理：** 进入 Docker 管理子菜单。
*   **系统工具：** 进入系统工具子菜单。

#### 3.2.5 BBR 加速管理 (选项 5)

此菜单下包含以下功能：

*   **BBR 综合测速：** 对 BBR、BBR Plus、BBRv2、BBRv3 模式进行综合速度测试。
*   **BBR 内核安装/切换：** 使用 `ylx2016/Linux-NetSpeed` 脚本安装或切换 BBR 内核。
*   **查看系统信息 (含 BBR 状态)：** 显示包含 BBR 状态和 GLIBC 版本的系统信息。
*   **Speedtest-cli 管理：** 安装、更新或卸载 `speedtest-cli`。

#### 3.2.6 Docker 管理 (选项 6)

此菜单下包含以下功能：

*   **查看 Docker 状态：** 显示 Docker 安装状态、运行中的容器、镜像、网络和卷的数量。
*   **安装/更新 Docker：** 使用官方脚本安装或更新 Docker，并启用其服务。
*   **Docker 卷管理：** 创建、删除、清理 Docker 卷。
*   **Docker 容器管理：** 启动、停止、重启、查看日志、进入、删除、检查容器。
*   **Docker 镜像管理：** 拉取、删除、查看历史、导出、导入镜像。
*   **Docker 网络管理：** 创建、删除、检查、连接、断开网络。
*   **Docker 清理：** 清理 Docker 资源。
*   **修改 Docker 镜像源：** 修改 Docker 的注册表镜像源。
*   **编辑 daemon.json：** 编辑 Docker 的 `daemon.json` 配置文件。
*   **启用/禁用 Docker IPv6：** 控制 Docker 的 IPv6 功能。
*   **Docker 环境备份/恢复：** 备份容器为镜像、导出镜像、备份 Docker 卷，并提供手动恢复说明。
*   **卸载 Docker：** 彻底卸载 Docker 及其相关组件。

#### 3.2.7 系统工具菜单 (选项 7)

此菜单下包含以下功能：

*   **高级防火墙管理：** （待完善，需手动插入命令）端口管理、IP 白名单/黑名单、防火墙激活/禁用、PING 控制、DDOS 防御、国家 IP 限制。
*   **修改登录密码：** 修改 `root` 用户的登录密码。
*   **修改 SSH 连接端口：** 修改 SSH 服务的端口，并尝试更新防火墙规则。
*   **切换优先 IPV4/IPV6：** 优先使用 IPv4 或 IPv6，启用/禁用 IPv6，并查看网络配置。
*   **修改主机名：** 修改系统主机名。
*   **系统时区调整：** 调整系统时区。
*   **修改虚拟内存大小 (Swap)：** 管理 Swap 文件，包括禁用、创建、调整大小和设置 `swappiness`。
*   **内存加速清理：** 执行多步内存清理操作，包括同步数据、清理缓存、优化 Swap。
*   **重启服务器：** 重启服务器。
*   **卸载本脚本：** 删除脚本文件本身。
*   **Nginx Proxy Manager 管理：** 安装/启动、停止/删除、查看日志、访问 Nginx Proxy Manager。
*   **查看端口占用状态：** 查看所有占用端口或查询特定端口。
*   **修改 DNS 服务器：** 选择公共 DNS 或自定义 DNS 服务器。
*   **磁盘空间分析：** 显示磁盘使用情况、大文件/目录、文件类型统计。
*   **服务器性能全面测试：** 运行 Bench.sh, SuperBench.sh, LemonBench 等性能测试。
*   **流媒体解锁检测：** 检测 RegionRestrictionCheck, NFCheck, Disney+ 解锁情况。
*   **回程路由测试：** 使用 BestTrace, NextTrace, MTR 进行路由追踪。
*   **炫酷系统信息显示：** 使用 Neofetch, ScreenFetch, Linux_Logo, Macchina 显示系统信息。
*   **实时系统监控仪表板：** 使用 Gtop, Bpytop, Htop, Vtop 进行实时系统监控。
*   **网速多节点测试：** 使用 Speedtest-cli, LibreSpeed, Speedtest-X 进行多节点网络速度测试。
*   **端口扫描工具：** 使用 Nmap 进行快速、全面、服务版本、操作系统检测扫描。
*   **证书管理工具：** 使用 Acme.sh 或 Certbot 管理 SSL 证书，并查看当前证书。
*   **服务器延迟测试：** 测试服务器到国内、国际或自定义节点的延迟。
*   **磁盘性能测试：** 使用 Fio 进行顺序读写、随机读写和 IOPS 测试。
*   **系统安全扫描：** 使用 Lynis, Rkhunter, Chkrootkit, ClamAV 进行安全扫描。
*   **文件完整性检查：** 使用 AIDE, Tripwire 或手动 MD5 校验进行文件完整性检查。

#### 3.2.8 VPS 网络全面测试 (选项 8)

此菜单下包含以下功能：

*   **网络速度测速（NodeQuality）：** 运行 NodeQuality.com 提供的脚本进行全面的网络速度测试。
*   **网络质量体检：** 运行 Check.Place 提供的脚本进行全面的网络质量诊断，包括路由追踪、延迟检测和稳定性评估。

## 4. 配置选项

本脚本的大部分配置通过交互式菜单进行，用户无需手动编辑脚本文件。以下是一些可能涉及的配置项及其作用：

*   **BBR 内核选择：** 在 BBR 管理菜单中，您可以选择安装不同版本的 BBR 内核。
*   **Docker 镜像源：** 在 Docker 管理菜单中，您可以修改 Docker 的注册表镜像源，以加速镜像拉取。
*   **SSH 端口：** 在系统工具菜单中，您可以修改 SSH 服务的监听端口。
*   **系统时区：** 在系统工具菜单中，您可以选择或自定义系统时区。
*   **Swap 大小：** 在系统工具菜单中，您可以调整虚拟内存 (Swap) 的大小。
*   **DNS 服务器：** 在系统工具菜单中，您可以选择公共 DNS 或自定义 DNS 服务器。
*   **防火墙规则：** 高级防火墙管理功能需要用户手动插入命令来配置具体的防火墙规则，例如开放端口、设置 IP 白名单等。

## 5. 贡献指南

我们欢迎并感谢所有对本项目感兴趣的贡献者。如果您希望为本项目做出贡献，请遵循以下步骤：

1.  **Fork** 本仓库到您的 GitHub 账户。
2.  **Clone** 您 Fork 的仓库到本地。
3.  创建一个新的 **Feature Branch** (`git checkout -b feature/your-feature-name`)。
4.  在您的分支上进行代码修改和功能实现。
5.  确保您的代码符合项目现有的编码风格。
6.  提交您的更改 (`git commit -m 'feat: Add new feature'`)。
7.  将您的更改推送到 GitHub (`git push origin feature/your-feature-name`)。
8.  创建一个 **Pull Request** 到本仓库的 `main` 分支，详细描述您的更改内容和目的。

**报告 Bug 或提出建议：**

如果您在使用过程中遇到任何问题或有任何改进建议，请随时在 GitHub Issues 页面提交。

## 6. 许可证信息

本项目采用 MIT 许可证。详情请参阅项目根目录下的 `LICENSE` 文件。

```
MIT License

Copyright (c) 2023 CGG-VPS

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
