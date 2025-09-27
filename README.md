# bbr-speedtest

一个自动切换 **BBR / BBR Plus / BBRv2 / BBRv3** 拥塞控制算法并进行 **网络测速对比** 的脚本。  
可用于在 VPS 上快速测试不同 TCP 拥塞控制算法在你网络环境下的性能差别。

---

## 特性

- 自动加载 / 切换 BBR、BBR Plus（如果内核支持）  
- 使用 `speedtest-cli` 进行 Ping / 下行 / 上行 测速  
- 测试结果保存到 `bbr_result.txt`  
- 适配 Debian / Ubuntu / CentOS（会自动尝试安装 `speedtest-cli`）

---

## 系统要求 & 依赖

- **Linux** 系统（Debian / Ubuntu / CentOS / RHEL 等）  
- 内核需支持 BBR 或 BBR Plus  
- 脚本需以 **root 权限** 运行  
- 依赖工具：`speedtest-cli`

---

## 用法

### ① 从 GitHub 直接运行

打开你的 VPS 终端，执行：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/chengege666/bbr-speedtest/main/bbr_speedtest.sh)
