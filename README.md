# open-source-monitor-openclaw-skill

统一监控开源项目更新（GitHub Release + Docker Hub）

## 🚀 快速开始

### 1️⃣ 安装 Skill

```bash
clawhub install open-source-monitor-openclaw-skill
```

或手动克隆：

```bash
git clone <repo-url> ~/.openclaw/workspace/skills/open-source-monitor-openclaw-skill
```

---

### 2️⃣ 配置监控目标

**步骤 1：复制样例配置文件**

```bash
cd ~/.openclaw/workspace/scripts/open-source-monitor
cp config-sample.json config.json
```

**步骤 2：编辑配置文件**

```bash
nano config.json
```

**修改以下内容：**

```json
{
  "github": [
    "openclaw/openclaw",    // ⚠️ 改为你的 GitHub 仓库
    "nodejs/node"
  ],
  "docker": [
    "ubuntu/nginx:latest",  // ⚠️ 改为你的 Docker 镜像
    "google/cloud-sdk:stable"
  ],
  "schedule": "30 6,14,22 * * *",
  "target_channel": "telegram",
  "target_user": "YOUR_TELEGRAM_USER_ID"  // ⚠️ 改为你的 Telegram 用户 ID
}
```

**⚠️ 必须修改的字段：**

| 字段 | 说明 | 示例 |
|------|------|------|
| `github` | 要监控的 GitHub 仓库列表 | `["openclaw/openclaw", "nodejs/node"]` |
| `docker` | 要监控的 Docker 镜像列表 | `["ubuntu/nginx:latest"]` |
| `target_user` | 你的 Telegram 用户 ID | `"314556018"` |

**可选字段：**

| 字段 | 默认值 | 说明 |
|------|--------|------|
| `schedule` | `"30 6,14,22 * * *"` | Cron 表达式，控制检查频率 |

---

### 3️⃣ 运行安装脚本

**配置完成后**，运行安装脚本：

```bash
cd ~/.openclaw/workspace/skills/open-source-monitor-openclaw-skill
chmod +x install.sh
./install.sh
```

**安装脚本会：**
- ✅ 检查 `config.json` 是否存在
- ✅ 验证配置是否有效（非样例配置）
- ✅ 创建缓存和日志目录
- ✅ 设置脚本执行权限
- ✅ 自动添加 Cron Job

---

### 4️⃣ 验证安装

**检查 Cron Job：**

```bash
crontab -l
# 应该看到：
# 30 6,14,22 * * * /Users/webleon/.openclaw/workspace/scripts/open-source-monitor/run.sh
```

**手动测试运行：**

```bash
~/.openclaw/workspace/scripts/open-source-monitor/run.sh
```

**查看日志：**

```bash
ls -la ~/.openclaw/workspace/scripts/open-source-monitor/log/
cat ~/.openclaw/workspace/scripts/open-source-monitor/log/$(date +%Y-%m-%d).log
```

---

## 📋 配置示例

### GitHub 监控

```json
"github": [
  "openclaw/openclaw",
  "nodejs/node",
  "CherryHQ/cherry-studio",
  "webleon/my-project"
]
```

### Docker Hub 监控

```json
"docker": [
  "ubuntu/nginx:latest",      // Ubuntu 官方 Nginx
  "google/cloud-sdk:stable",  // Google Cloud SDK
  "library/redis:alpine",     // Docker 官方 Redis (Alpine)
  "grafana/grafana:latest"    // Grafana
]
```

### 自定义检查频率

```json
"schedule": "0 * * * *"    // 每小时整点检查
```

```json
"schedule": "0 9 * * *"    // 每天早上 9 点检查
```

```json
"schedule": "0 */2 * * *"  // 每 2 小时检查
```

```json
"schedule": "*/15 * * * *" // 每 15 分钟检查
```

---

## 🗑️ 卸载

### 移除 Cron Job

```bash
crontab -e
# 删除包含 "open-source-monitor" 的行
```

### 删除 Skill

```bash
rm -rf ~/.openclaw/workspace/skills/open-source-monitor-openclaw-skill
rm -rf ~/.openclaw/workspace/scripts/open-source-monitor
```

---

## 📁 文件结构

```
~/.openclaw/workspace/
├── scripts/open-source-monitor/
│   ├── run.sh              # 主脚本（执行监控）
│   ├── config.json         # ⚠️ 个人配置（不提交到 Git）
│   ├── config-sample.json  # ✅ 配置模板（提交到 Git）
│   ├── .cache/             # 缓存目录（版本/digest）
│   └── log/                # 日志目录
└── skills/open-source-monitor-openclaw-skill/
    ├── SKILL.md            # Skill 定义
    ├── README.md           # 本文档
    └── install.sh          # 安装脚本
```

---

## 🔧 故障排查

### 安装脚本报错 "配置文件不存在"

**原因：** 还没有复制配置文件

**解决：**

```bash
cd ~/.openclaw/workspace/scripts/open-source-monitor
cp config-sample.json config.json
nano config.json  # 修改配置
./install.sh      # 重新运行
```

### 安装脚本报错 "target_user 未配置"

**原因：** 使用了样例配置，没有修改 `YOUR_TELEGRAM_USER_ID`

**解决：**

```bash
nano ~/.openclaw/workspace/scripts/open-source-monitor/config.json
# 将 "YOUR_TELEGRAM_USER_ID" 改为你的实际 Telegram 用户 ID
```

### Cron Job 不执行

**检查 Cron 服务：**

```bash
# macOS
sudo systemsetup -getusingnetworktime
```

**手动测试脚本：**

```bash
~/.openclaw/workspace/scripts/open-source-monitor/run.sh
```

**查看 Cron 日志：**

```bash
log show --predicate 'process == "cron"' --last 1h
```

### 脚本运行失败

**检查依赖：**

```bash
which git
which curl
which jq
```

**安装缺失依赖：**

```bash
brew install jq
```

**查看详细错误：**

```bash
bash -x ~/.openclaw/workspace/scripts/open-source-monitor/run.sh
```

### Docker 镜像监控失败

**检查镜像是否存在：**

```bash
curl -s "https://hub.docker.com/v2/repositories/ubuntu/nginx/tags/latest" | jq '.'
```

**检查镜像格式：**

- ✅ 正确：`"ubuntu/nginx:latest"`
- ✅ 正确：`"library/redis:alpine"`
- ❌ 错误：`"nginx"`（缺少命名空间）
- ❌ 错误：`"nginx:latest:extra"`（格式错误）

---

## 📊 输出示例

脚本输出 JSON，供 OpenClaw 处理：

```json
{
  "config": {
    "target_channel": "telegram",
    "target_user": "314556018",
    "current_time": "2026-03-08 08:57"
  },
  "github": {
    "has_new_version": true,
    "total_checked": 2,
    "total_new": 1,
    "releases": [
      {
        "repo": "openclaw",
        "owner_repo": "openclaw/openclaw",
        "version": "v2026.3.2",
        "tag_url": "https://github.com/openclaw/openclaw/releases/tag/v2026.3.2"
      }
    ]
  },
  "docker": {
    "has_new_version": false,
    "total_checked": 2,
    "total_new": 0,
    "images": []
  }
}
```

---

## 📝 Git 提交规范

**⚠️ 重要：** 不要提交包含个人配置的 `config.json`

```bash
# ✅ 正确：只提交 sample 文件
git add config-sample.json
git add install.sh
git add README.md

# ❌ 错误：不要提交 config.json
git add config.json  # 不要这样做！
```

**推荐 `.gitignore`：**

```
# 个人配置
config.json

# 运行时生成
.cache/
log/*.log

# macOS
.DS_Store
```

---

## ✅ 安装检查清单

安装完成后，确认以下项目：

- [ ] `config.json` 已创建并修改
- [ ] `target_user` 已改为实际 Telegram ID
- [ ] `github` 和/或 `docker` 列表已配置
- [ ] `install.sh` 运行成功
- [ ] Cron Job 已添加（`crontab -l` 可见）
- [ ] 手动测试运行成功
- [ ] 日志目录已创建

---

## 📞 支持

遇到问题？

1. 查看日志：`~/.openclaw/workspace/scripts/open-source-monitor/log/`
2. 检查配置：`jq '.' ~/.openclaw/workspace/scripts/open-source-monitor/config.json`
3. 手动测试：`~/.openclaw/workspace/scripts/open-source-monitor/run.sh`
