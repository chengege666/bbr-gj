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


② 手动下载 & 运行
git clone https://github.com/chengege666/bbr-speedtest.git
cd bbr-speedtest
chmod +x bbr_speedtest.sh
sudo ./bbr_speedtest.sh

输出示例
=== BBR / BBR Plus / BBRv2 / BBRv3 自动测速对比 ===
>>> 切换到 BBR 并测速...
BBR | Ping: 20.3ms | Down: 150.45 Mbps | Up: 45.67 Mbps

>>> 切换到 BBR Plus 并测速...
BBR Plus | Ping: 21.1ms | Down: 148.33 Mbps | Up: 47.89 Mbps

⚠️ 你的内核可能不支持 BBRv2  
⚠️ 你的内核可能不支持 BBRv3  

=== 测试完成，结果汇总 ===
BBR | Ping: 20.3ms | Down: 150.45 Mbps | Up: 45.67 Mbps  
BBR Plus | Ping: 21.1ms | Down: 148.33 Mbps | Up: 47.89 Mbps  


测试结果会被写入 bbr_result.txt。

注意事项 & 已知问题

脚本必须 以 root 权限 执行

并非所有内核都支持 BBR Plus / BBRv2 / BBRv3

speedtest-cli 安装失败时要手动解决依赖

如果在防火墙 / 网络策略限制下测速失败，请检查网络连通性

