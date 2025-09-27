# bbr-speedtest   自己测试BBR用的，看选那个合适

一个自动切换 **BBR / BBR Plus / BBRv2 / BBRv3** 拥塞控制算法并进行 **网络测速对比** 的脚本。
可用于在 VPS 上快速测试不同 TCP 拥塞控制算法在你网络环境下的性能差别。

---

## 特性

* 自动加载 / 切换 BBR、BBR Plus（如果内核支持）
* 使用 `speedtest-cli` 进行 Ping / 下行 / 上行 测速
* 测试结果保存到 `bbr_result.txt`
* **自动检测 root 权限**，不是 root 会提示退出
* **自动安装依赖**（curl、wget、git、speedtest-cli）

---

## 系统要求

* Linux 系统（Debian / Ubuntu / CentOS / RHEL 等）
* 内核需支持 BBR 或 BBR Plus
* 需要 **root 权限** 运行

---

## 使用方法

### 一键运行（推荐）

在 VPS 上执行：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/chengege666/bbr-speedtest/main/bbr_speedtest.sh)
```

脚本会自动：

1. 检查 root 权限
2. 安装依赖（curl / wget / git / speedtest-cli）
3. 切换不同 BBR 算法并测速
4. 输出结果并保存到 `bbr_result.txt`

---

### 手动运行

```bash
git clone https://github.com/chengege666/bbr-speedtest.git
cd bbr-speedtest
chmod +x bbr_speedtest.sh
sudo ./bbr_speedtest.sh
```

---

## 输出示例

```
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
```

---

## 注意事项

* 必须以 **root 权限** 运行
* 并非所有内核都支持 BBR Plus / BBRv2 / BBRv3
* 如果 `speedtest-cli` 安装失败，需要手动安装

---

## 许可协议

MIT License

---

## 作者

* 作者：[chengege666](https://github.com/chengege666)
