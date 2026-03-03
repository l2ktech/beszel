# 研究发现

## 192/193 连通现状
- **发现**：最新采样（2026-03-03 16:30:27 CST）显示 `z192 up=4/down=9`，`z193 up=12/down=1`，存在明显“192 选择性不通”。
- **来源**：`sqlite3 /Users/wzy/projects/08-Beszel/beszel_data/data.db` 查询。
- **影响**：问题仍集中在 192 网段，且不是全网双向中断。

## 逐设备 moon 配置核查结果
- **发现**：可采集到 ZeroTier 数据的设备中，`friendlyWrt(.15)` 与 `macmini(.13)` 的 `zerotier-cli listmoons` 均为 `[]`；`ROCK5C(.202)` 需 root 权限读取 token，普通用户下无法读取 moon 信息；`macbook(.18)` 未安装/未暴露 `zerotier-cli`。
- **来源**：批量核查日志 `/tmp/zt_moon_audit_20260303.txt`、快速核查日志 `/tmp/zt_moon_quick_20260303.txt`、单机校验命令输出。
- **影响**：当前可验证样本未发现“配置了 moon 的异常设备”，与“moon 导致选择性不通”不一致。

## 设备可达性与取证边界
- **发现**：以下节点当前 SSH 不可用（含 192/193 双地址与常见用户）：`.1/.9/.10/.14/.16/.17/.20/.201/.203`，无法直接读取其本机 moon 配置。
- **来源**：`/tmp/zt_moon_quick_20260303.txt`。
- **影响**：这部分节点需要补充凭据或在节点本机执行命令后回传结果，才能完成“全量设备”100%确认。

## 官方文档交叉验证（Grok 优先检索）
- **发现**：ZeroTier 官方文档说明 moon/roots 作用是对等发现与根服务补充，并非业务流量的常规转发路径；规则引擎与端侧防火墙可直接造成 ICMP/ping 选择性不通。
- **来源**：
  - https://docs.zerotier.com/roots/
  - https://docs.zerotier.com/rules/
  - https://docs.zerotier.com/faq/ping/
- **影响**：当前更可能是 Flow Rules/端侧防火墙/ICMP 策略导致的“选择性不通”，不是 moon 本身。

## 告警消息改造结果
- **发现**：`scripts/zt_latency_sync.sh` 已改为钉钉 `markdown` 消息，中文字段 + 彩色标识：`🔴掉线`、`🟡波动`、`🟢恢复`，并保留签名与 `errcode` 校验。
- **来源**：脚本代码与定向触发日志 `/tmp/zt_dingtalk_style_test.log`（`dingtalk send ok`）。
- **影响**：告警可读性与可区分性提升，满足“中文、格式化、美化”要求。
