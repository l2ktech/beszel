# ZeroTier moon 核查与钉钉告警样式升级（2026-03-03）

## 1. 结论摘要

- 采集频率：`com.wzy.beszel.zt-latency-sync` 的 `StartInterval=60`（每 1 分钟）。
- 连通现状（2026-03-03 16:30:27 CST）：
  - `192`：`up=4`、`down=9`
  - `193`：`up=12`、`down=1`
- moon 核查结论：当前可采样设备未发现 moon 配置（`listmoons=[]` 或未启用），**“192 选择性不通”不符合 moon 导致特征**。
- 告警通知：已改为中文 markdown，带彩色标识（🔴/🟡/🟢），并保持钉钉加签与 `errcode` 校验。

## 2. moon 核查明细

### 2.1 可读取到 ZeroTier 配置的设备

- `friendlyWrt (192.168.192.15)`：`listmoons = []`
- `macmini (192.168.192.13)`：`listmoons = []`
- `ROCK5C (192.168.193.202)`：普通用户可登录，但 `zerotier-cli` 读取 token 需要 root（`authtoken.secret not found or readable`）

### 2.2 当前无法取证的设备

以下设备当前无法通过既有密钥 SSH 登录（含 192/193 双地址尝试）：

- `.1/.9/.10/.14/.16/.17/.20/.201/.203`

因此这些节点的 moon 状态尚未直接读取。

## 3. 为什么判断不是 moon 问题

- 官方文档说明 moon/roots 主要用于节点发现与根服务补充，不是业务流量常规转发路径。
- `ping` 选择性失败更常见于：
  - ZeroTier Flow Rules 策略限制
  - 设备本地防火墙/ICMP 策略
  - 部分节点未开放 ICMP

参考：
- https://docs.zerotier.com/roots/
- https://docs.zerotier.com/rules/
- https://docs.zerotier.com/faq/ping/

## 4. 告警样式升级说明

脚本：`scripts/zt_latency_sync.sh`

- 消息类型：`msgtype=markdown`
- 标题与正文：中文字段，结构化展示
- 彩色标识：
  - `🔴` 掉线告警
  - `🟡` 波动告警
  - `🟢` 恢复通知
- 安全与可靠性：
  - 支持钉钉加签（`timestamp + sign`）
  - 校验钉钉返回 `errcode == 0`

## 5. 复核命令

```bash
# 采集任务状态
launchctl print gui/$(id -u)/com.wzy.beszel.zt-latency-sync | sed -n '1,80p'

# 最新采样时间
sqlite3 /Users/wzy/projects/08-Beszel/beszel_data/data.db \
  "SELECT datetime(MAX(CAST(json_extract(info,'$.zt_probe_ts') AS INTEGER)), 'unixepoch', 'localtime') FROM systems;"

# 192/193 up/down 汇总
sqlite3 /Users/wzy/projects/08-Beszel/beszel_data/data.db \
"WITH s AS (SELECT json_extract(info,'$.z192_status') AS s192, json_extract(info,'$.z193_status') AS s193 FROM systems WHERE host GLOB '192.168.192.*' OR host GLOB '192.168.193.*')
 SELECT 'z192', s192, COUNT(*) FROM s GROUP BY s192
 UNION ALL
 SELECT 'z193', s193, COUNT(*) FROM s GROUP BY s193
 ORDER BY 1,2;"
```
