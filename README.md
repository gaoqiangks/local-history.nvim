# local-history.nvim

这个项目是AI生成的,  vscode的插件local-history的的neovim版本.  基本功能都可用.

一个为 Neovim 提供“本地历史快照（Local History）”能力的插件，目标是尽量对齐 VSCode Local History 的工作流：  
在你编辑文件时自动保存历史版本，支持查看、对比、恢复、清理。 

---

## 目录

- [1. 这个插件解决什么问题](#1-这个插件解决什么问题)
- [2. 核心能力总览](#2-核心能力总览)
- [3. 安装](#3-安装)
- [4. 快速开始](#4-快速开始)
- [5. 命令详解](#5-命令详解)
- [6. 配置详解（每个字段）](#6-配置详解每个字段)
- [7. VSCode 字段映射兼容](#7-vscode-字段映射兼容)
- [8. 快照存储结构](#8-快照存储结构)
- [9. 工作机制说明](#9-工作机制说明)
- [10. 常见配置方案](#10-常见配置方案)
- [11. 故障排查](#11-故障排查)
- [12. 性能建议](#12-性能建议)
- [13. 路线图](#13-路线图)
- [14. License](#14-license)

---

## 1. 这个插件解决什么问题

在日常编码中，你可能会遇到：

- 刚改坏了文件，想回到几分钟前版本；
- 改动很多但还不想提交 Git；
- 想快速比较“当前版本”和“之前某个瞬间”的差异。

`local-history.nvim` 提供的是 **文件级、时间序列的本地快照**，不替代 Git，但能作为非常实用的补充层。

---

## 2. 核心能力总览

- 自动触发快照：保存/编辑变化/失焦
- 内容去重：与最新快照内容相同则不重复存
- 历史浏览：列出当前文件所有快照
- 历史对比：选中快照后与当前 buffer 做 diff
- 历史恢复：将快照内容恢复到当前 buffer
- 清理策略：
  - 按每文件最大快照数裁剪
  - 按保留天数清理
- 跳过策略：
  - 路径匹配排除
  - 大文件跳过
  - 二进制跳过
- 通知：
  - 快照写入成功可通知
  - 操作结果可通知
- 兼容 VSCode 风格配置字段名

---

## 3. 安装

## 3.1 lazy.nvim

```lua
{
  "gaoqiangks/local-history.nvim",
  config = function()
    require("local_history").setup({
      enabled = true,
      save_on = { "BufWritePost" },
      notify = true,
    })
  end,
}
```

## 3.2 packer.nvim

```lua
use({
  "gaoqiangks/local-history.nvim",
  config = function()
    require("local_history").setup()
  end,
})
```

---

## 4. 快速开始

1. 安装插件并执行 `setup()`
2. 打开一个普通文本文件，保存几次（`:w`）
3. 执行命令：
   - `:LocalHistoryList`
   - `:LocalHistoryDiff`
   - `:LocalHistoryRestore`

若看到快照条目，说明插件已正常工作。

---

## 5. 命令详解

> 当前命令都是“基于当前 buffer 对应文件”工作。

## 5.1 `:LocalHistoryList`

**作用**：列出当前文件的历史快照列表（按时间倒序展示）。  
**典型用途**：确认有没有快照、挑选目标时间点。  
**输出行为**：通过 `vim.notify` 显示列表（如果 `notify=true`）。

---

## 5.2 `:LocalHistoryDiff`

**作用**：先选择一个快照，再显示“快照 vs 当前 buffer”的 unified diff。  
**典型用途**：查看某次改动到底差了什么。  
**实现方式**：使用 `vim.diff(..., { result_type = "unified" })` 生成差异文本并在新窗口打开。  
**注意**：当前是统一 diff 文本视图，不是 side-by-side 双窗。

---

## 5.3 `:LocalHistoryRestore`

**作用**：选择一个快照并恢复到当前 buffer。  
**典型用途**：快速回退文件到某个历史版本。  
**重要说明**：
- 恢复后 **buffer 会变为 modified**（未自动写盘）
- 你可以先检查内容，再手动 `:w` 决定是否落盘
- 该恢复可以继续通过 Neovim 的 undo 进行回退

---

## 5.4 `:LocalHistoryPurge`

**作用**：删除当前文件的所有本地历史快照与索引文件。  
**典型用途**：清理某个文件过多历史，或重置其历史。  
**注意**：不可恢复（除非你另有备份）。

---

## 6. 配置详解（每个字段）

完整示例：

```lua
require("local_history").setup({
  enabled = true,
  save_on = { "BufWritePost" },

  on_change_debounce_ms = 800,
  min_snapshot_interval_ms = 500,

  root_dir = vim.fn.stdpath("state") .. "/local-history",

  max_entries_per_file = 200,
  retention_days = 30,

  exclude_patterns = {
    "%.git/",
    "node_modules/",
    "%.cache/",
    "%.swp$",
    "~$",
  },

  max_file_size_kb = 1024,
  skip_binary = true,
  notify = true,
})
```

下面逐项说明：

---

### `enabled` (boolean)

- **含义**：是否启用插件。
- **默认**：`true`
- **建议**：
  - 临时停用可设 `false`
  - 长期使用保持 `true`

---

### `save_on` (string[])

- **含义**：触发快照的 Neovim 自动命令事件列表。
- **默认**：`{ "BufWritePost" }`
- **可选常见值**：
  - `BufWritePost`：保存后（推荐，最稳）
  - `TextChanged` / `TextChangedI`：文本变更（频率高）
  - `FocusLost`：Neovim 失焦时
- **建议**：
  - 对性能敏感项目优先 `BufWritePost`
  - 用 `TextChanged` 时务必配合 debounce 和最小间隔

---

### `on_change_debounce_ms` (number)

- **含义**：当触发事件是 `TextChanged*` 时，延迟多少毫秒后才真正写快照。
- **默认**：`800`
- **作用**：避免每次按键都产生快照。
- **建议范围**：`600 ~ 1500`

---

### `min_snapshot_interval_ms` (number)

- **含义**：同一文件两次快照写入的最小时间间隔（毫秒）。
- **默认**：`500`
- **作用**：即使连续触发，也限制快照写入频率。
- **建议范围**：`500 ~ 1500`

---

### `root_dir` (string)

- **含义**：快照根目录。
- **默认**：`stdpath('state') .. '/local-history'`
- **建议**：
  - 保持默认即可
  - 如果你有高速磁盘，可改到更快路径

---

### `max_entries_per_file` (number)

- **含义**：每个文件最多保留多少条快照。
- **默认**：`200`
- **行为**：超出后删除最旧快照。
- **建议**：
  - 小项目：100~200
  - 大项目长期使用：200~500

---

### `retention_days` (number)

- **含义**：快照按天数保留，超过天数的老快照会清理。
- **默认**：`30`
- **行为**：写入新快照后执行按天清理。
- **建议**：
  - 日常：14~30
  - 想保留更久：60~90

---

### `exclude_patterns` (string[])

- **含义**：排除路径/文件的 Lua 模式列表，匹配则不保存快照。
- **默认**：
  - `%.git/`
  - `node_modules/`
  - `%.cache/`
  - `%.swp$`
  - `~$`
- **注意**：这里是 **Lua pattern**，不是完整 glob。
- **建议**：
  - 加入 `dist/`, `build/`, `target/` 等生成目录
  - 加入你不需要追踪的临时文件后缀

---

### `max_file_size_kb` (number)

- **含义**：大于此大小的文件跳过（单位 KB）。
- **默认**：`1024`（1MB）
- **建议**：
  - 文本代码仓库：1024~4096
  - 如果经常编辑大文本：适当调大

---

### `skip_binary` (boolean)

- **含义**：是否跳过二进制文件（通过检测 `\0` 字节判断）。
- **默认**：`true`
- **建议**：保持 `true`

---

### `notify` (boolean)

- **含义**：是否显示操作通知（包括快照保存成功通知）。
- **默认**：`true`
- **你关心的行为**：
  - 当新快照写入成功时，会显示  
    `Snapshot saved: <timestamp>.snap (<filename>)`
  - 若内容无变化（去重命中），不会产生新快照，也不会显示“保存成功”通知。

---

## 7. VSCode 字段映射兼容

你可以直接使用 VSCode 风格字段，插件自动映射。

示例：

```lua
require("local_history").setup({
  ["local-history.enabled"] = true,
  ["local-history.path"] = vim.fn.stdpath("state") .. "/local-history",
  ["local-history.maxEntries"] = 300,
  ["local-history.retentionDays"] = 14,
  ["local-history.exclude"] = { "%.git/", "node_modules/" },
  ["local-history.maxFileSizeKB"] = 2048,
  ["local-history.trigger"] = "onChange",
  ["local-history.debounceMs"] = 1000,
  ["local-history.minIntervalMs"] = 600,
  ["local-history.notify"] = true,
})
```

映射表：

| VSCode 字段 | Neovim 字段 |
|---|---|
| `local-history.enabled` | `enabled` |
| `local-history.path` / `local-history.root` | `root_dir` |
| `local-history.maxEntries` / `local-history.maxFileEntries` | `max_entries_per_file` |
| `local-history.daysLimit` / `local-history.retentionDays` | `retention_days` |
| `local-history.exclude` / `excludePattern(s)` | `exclude_patterns` |
| `local-history.maxFileSizeKB` | `max_file_size_kb` |
| `local-history.maxFileSize`(bytes) | 自动换算成 `max_file_size_kb` |
| `local-history.trigger=onSave` | `save_on={"BufWritePost"}` |
| `local-history.trigger=onChange` | `save_on={"TextChanged","TextChangedI"}` |
| `local-history.trigger=onFocusLost` | `save_on={"FocusLost"}` |
| `local-history.debounceMs` | `on_change_debounce_ms` |
| `local-history.minIntervalMs` | `min_snapshot_interval_ms` |
| `local-history.notify` | `notify` |

**优先级**：若同时传了原生字段和 VSCode 字段，原���字段优先。

---

## 8. 快照存储结构

根目录：

```text
<stdpath('state')>/local-history/
```

结构：

```text
<workspace_hash>/<relative_file_path>/<timestamp>.snap
<workspace_hash>/<relative_file_path>/index.json
```

示例：

```text
~/.local/state/nvim/local-history/ab12cd34ef56/src/main.ts/20260301-103045.snap
~/.local/state/nvim/local-history/ab12cd34ef56/src/main.ts/index.json
```

---

## 9. 工作机制说明

1. 自动命令事件触发（如保存）
2. 根据配置判断是否应跳过（exclude/大小/二进制）
3. 读取当前文件内容
4. 与最新快照做内容比较（相同则跳过）
5. 生成时间戳快照文件并写入
6. 更新 `index.json`
7. 执行清理策略（按天数、按最大条数）
8. 若 `notify=true`，显示保存通知

---

## 10. 常见配置方案

### 10.1 稳定低开销（推荐）

```lua
require("local_history").setup({
  save_on = { "BufWritePost" },
  max_entries_per_file = 300,
  retention_days = 30,
  notify = true,
})
```

### 10.2 高频追踪（更细粒度）

```lua
require("local_history").setup({
  save_on = { "TextChanged", "TextChangedI" },
  on_change_debounce_ms = 1200,
  min_snapshot_interval_ms = 800,
  max_entries_per_file = 500,
})
```

### 10.3 静默模式

```lua
require("local_history").setup({
  notify = false,
})
```

---

## 11. 故障排查

### 问题 A：`vim.notify` 正常，但保存时没有“Snapshot saved”通知

检查：

1. `notify` 是否为 `true`
2. 本次是否真的创建了新快照（内容未变会被去重跳过）
3. 文件是否被排除：
   - 命中 `exclude_patterns`
   - 文件过大
   - 被识别为二进制

---

### 问题 B：`:LocalHistoryList` 显示无快照

- 当前 buffer 必须有真实文件路径（不是临时 nofile）
- 触发模式若是 `BufWritePost`，请先至少 `:w` 一次

---

### 问题 C：快照太多

- 增大 `on_change_debounce_ms`
- 增大 `min_snapshot_interval_ms`
- 优先使用 `BufWritePost`
- 下调 `max_entries_per_file`
- 缩短 `retention_days`

---

### 问题 D：恢复后文件被改了但没写盘

这是预期行为。恢复只改当前 buffer，保留你确认机会。  
确认后手动 `:w` 即可。

---

## 12. 性能建议

- 大仓库优先 `BufWritePost`
- 合理设置排除目录（构建产物、依赖目录）
- 保持 `skip_binary=true`
- 对大文件设定合适 `max_file_size_kb`

---

## 13. 路线图

- Telescope picker 集成（更好列表/预览）
- Side-by-side diff 模式
- 恢复到新 buffer / 新文件
- workspace 级别 purge
- 更完整 VSCode 配置 1:1 校验与文档化

---

## 14. License

MIT
