# open-source-monitor-openclaw-skill

OpenClaw Skill - 统一监控开源项目更新（GitHub Release + Docker Hub）

## 功能

- ✅ 监控 GitHub 仓库的最新 Release
- ✅ 监控 Docker Hub 镜像的最新版本
- ✅ 统一配置，统一输出
- ✅ 定时任务支持（默认一天三次：6:30, 14:30, 22:30）
- ✅ 发现更新自动发送 Telegram 通知

## 配置

编辑 `~/.openclaw/workspace/scripts/open-source-monitor/config.json`:

```json
{
  "github": [
    "openclaw/openclaw",
    "immich-app/immich"
  ],
  "docker": [
    "library/nginx:latest",
    "library/redis:alpine"
  ],
  "schedule": "30 6,14,22 * * *",
  "target_channel": "telegram",
  "target_user": "314556018"
}
```

### 配置说明

| 字段 | 说明 | 示例 |
|------|------|------|
| `github` | GitHub 仓库列表（格式：`owner/repo`） | `["openclaw/openclaw"]` |
| `docker` | Docker 镜像列表（格式：`namespace/image:tag`） | `["library/nginx:latest"]` |
| `schedule` | Cron 表达式 | `"30 6,14,22 * * *"` |
| `target_channel` | 通知渠道 | `"telegram"` |
| `target_user` | 目标用户 ID | `"314556018"` |

## 使用

### 手动检查

```bash
~/.openclaw/workspace/scripts/open-source-monitor/run.sh
```

### 输出格式

脚本输出 JSON，供 OpenClaw agentTurn 处理：

```json
{
  "config": { ... },
  "github": {
    "has_new_version": true,
    "total_checked": 4,
    "total_new": 1,
    "releases": [{"repo": "openclaw", "version": "v1.2.3", ...}]
  },
  "docker": {
    "has_new_version": false,
    "total_checked": 2,
    "total_new": 0,
    "images": []
  }
}
```

## 安装 Cron Job

编辑 crontab：

```bash
crontab -e
```

添加：

```bash
# Open Source Monitor - 一天三次（6:30, 14:30, 22:30 GMT+8）
30 6,14,22 * * * ~/.openclaw/workspace/scripts/open-source-monitor/run.sh
```

## 缓存

- GitHub 缓存：`~/.openclaw/workspace/scripts/open-source-monitor/.cache/github_*.json`
- Docker 缓存：`~/.openclaw/workspace/scripts/open-source-monitor/.cache/docker_*.json`

缓存文件记录上次检查到的版本/digest，用于比对更新。

## 日志

日志位置：`~/.openclaw/workspace/scripts/open-source-monitor/log/YYYY-MM-DD.log`

## 迁移自 github-release-monitor

原有配置自动迁移：
- `github-release-monitor/config.json` → `open-source-monitor/config.json` (github 部分)
- 缓存文件自动保留
