# NeverSleep 手动验证清单

对照系统设置（锁定屏幕）逐项验证。本机：Mac mini（M4，无电池，仅 AC），macOS 26.5.2，系统语言中文。

运行方式（Debug）：

```bash
xcodebuild -project NeverSleep.xcodeproj -scheme NeverSleep -configuration Debug build
open ~/Library/Developer/Xcode/DerivedData/NeverSleep-*/Build/Products/Debug/NeverSleep.app
```

## 基础

- [ ] 启动后仅菜单栏：月亮图标出现，**无 Dock 图标、无主窗口**
- [ ] 菜单栏图标旁显示当前值数字（本机 AC 下 = `pmset -g custom` 的 `displaysleep`）
- [ ] 值未知/读取失败时菜单栏只显图标或「—」
- [ ] 点图标弹出 popover；点外部/再点图标收起

## 读取（对照系统设置 → 锁定屏幕 → 不活跃时关闭显示器）

- [ ] popover 顶部标题与系统面板一致（中文「不活跃时关闭显示器」/ 英文 “Turn display off when inactive”）
- [ ] 当前值文案与系统措辞一致（如 60 → 「1 小时」；0 → 「永不」）
- [ ] 滑块吸附最近档位，刻度高亮当前档
- [ ] 在系统设置里改时间 → 重开 popover，值同步
- [ ] **列表外值**：`sudo pmset -c displaysleep 7` 后重开 popover → 滑块吸附 5 分钟档，文案显示「7 分钟」+ 旁注「系统设置中为其他值」；验证后恢复原值（`sudo pmset -c displaysleep <原值>`）
- [ ] 读失败态（可临时 `mv /usr/bin/pmset /usr/bin/pmset.bak` 复现，记得还原）：滑块禁用 + 「无法读取当前设置」 + 重试 + 深链按钮

## 写入

- [ ] 拖动滑块松手 → 首次出现「修改需输入管理员密码」提示（可勾选不再提示）
- [ ] 输管理员密码 → `pmset -g custom` 与系统设置面板值同步更新
- [ ] 取消/输错密码 → 滑块弹回旧值 + 红色错误行「写入失败（密码取消或未授权）」
- [ ] 深链按钮（在系统设置中打开…）→ 打开系统设置锁定屏幕页
- [ ] 再次拖动：不再提示，直接弹密码框（UserDefaults `NeverSleep.writeHintShown`）

## 登录时启动

- [ ] 开关默认关；打开 → 系统设置 → 通用 → 登录项出现 NeverSleep
- [ ] 关闭 → 从登录项移除
- [ ] 重启应用后开关反映真实注册状态
- [ ] 失败路径（如受 MDM 管控）→ 红色错误文案 + 开关回滚

## 本地化（英文系统验证，需一台英文系统）

- [ ] 系统语言为英文时，全部文案为英文且与 Apple 文档措辞一致（`docs/research/lock-screen-display-off-options.md` §3）
- [ ] 中文系统时保持中文原文

## 便携机专有（需一台 MacBook 验证）

- [ ] popover 出现「电池 / 电源适配器」展开器，每源一个滑块
- [ ] 默认滑块跟当前电源源（拔插电源切换）
- [ ] 展开器展开时重读两源值
- [ ] 菜单栏数字随当前源切换

## 退出

- [ ] popover 底部「退出」→ 进程结束、图标消失

## 已在本机验证（2026-08-03）

- 菜单栏仅图标 + 数字（60）、无 Dock
- popover 读取「1 小时」、写路径（拖动 → 密码 → `displaysleep 2`）
- 登录项注册/持久化（`sfltool dumpbtm` 确认；重启后开关保持）
- 单测 8 项通过（`xcodebuild test -only-testing:NeverSleepTests`）
