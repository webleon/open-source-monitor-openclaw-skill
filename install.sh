#!/bin/bash

# Open Source Monitor - 安装脚本
# 自动配置 Cron Job 和初始化目录

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_SCRIPTS="$HOME/.openclaw/workspace/scripts/open-source-monitor"
CONFIG_FILE="$WORKSPACE_SCRIPTS/config.json"
CONFIG_SAMPLE="$WORKSPACE_SCRIPTS/config-sample.json"

echo "🔧 Open Source Monitor 安装脚本"
echo "================================"

# 1. 检查配置文件（必须存在）
echo ""
echo "📄 检查配置文件..."

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "   ❌ 错误：配置文件不存在"
    echo ""
    echo "   请先完成以下步骤："
    echo ""
    echo "   1. 复制样例配置："
    echo "      cp $CONFIG_SAMPLE $CONFIG_FILE"
    echo ""
    echo "   2. 编辑配置文件："
    echo "      nano $CONFIG_FILE"
    echo ""
    echo "   3. 修改以下内容："
    echo "      - github: 添加你要监控的 GitHub 仓库（格式：owner/repo）"
    echo "      - docker: 添加你要监控的 Docker 镜像（格式：namespace/image:tag）"
    echo "      - target_user: 你的 Telegram 用户 ID"
    echo ""
    echo "   4. 重新运行此脚本"
    exit 1
fi

echo "   ✅ 配置文件已存在：$CONFIG_FILE"

# 2. 验证配置
echo ""
echo "🔍 验证配置..."

if ! command -v jq >/dev/null 2>&1; then
    echo "   ❌ 错误：未安装 jq 命令"
    echo "   请运行：brew install jq"
    exit 1
fi

# 检查必要字段
GITHUB_COUNT=$(jq -r '.github | length' "$CONFIG_FILE" 2>/dev/null || echo "0")
DOCKER_COUNT=$(jq -r '.docker | length' "$CONFIG_FILE" 2>/dev/null || echo "0")
TARGET_USER=$(jq -r '.target_user' "$CONFIG_FILE" 2>/dev/null || echo "")
SCHEDULE=$(jq -r '.schedule' "$CONFIG_FILE" 2>/dev/null || echo "")

# 验证 github 和 docker 列表
if [[ "$GITHUB_COUNT" == "0" ]] && [[ "$DOCKER_COUNT" == "0" ]]; then
    echo "   ❌ 错误：github 和 docker 列表都为空"
    echo "   请编辑配置文件添加监控目标"
    exit 1
fi

# 验证 target_user
if [[ "$TARGET_USER" == "YOUR_TELEGRAM_USER_ID" ]] || [[ -z "$TARGET_USER" ]]; then
    echo "   ❌ 错误：target_user 未配置"
    echo "   请编辑配置文件，将 \"YOUR_TELEGRAM_USER_ID\" 改为你的实际 Telegram 用户 ID"
    exit 1
fi

# 验证 schedule（可选，有默认值）
if [[ -z "$SCHEDULE" ]] || [[ "$SCHEDULE" == "null" ]]; then
    echo "   ⚠️  警告：schedule 未配置，使用默认值"
fi

echo "   ✅ GitHub 监控：$GITHUB_COUNT 个"
if [[ "$GITHUB_COUNT" -gt 0 ]]; then
    jq -r '.github[]' "$CONFIG_FILE" | while read -r repo; do
        echo "      - $repo"
    done
fi

echo "   ✅ Docker 监控：$DOCKER_COUNT 个"
if [[ "$DOCKER_COUNT" -gt 0 ]]; then
    jq -r '.docker[]' "$CONFIG_FILE" | while read -r image; do
        echo "      - $image"
    done
fi

echo "   ✅ 通知用户：$TARGET_USER"
echo "   ✅ 检查频率：${SCHEDULE:-30 6,14,22 * * *} (默认：一天三次)"

# 3. 确保脚本可执行
echo ""
echo "🔐 设置脚本权限..."

RUN_SCRIPT="$WORKSPACE_SCRIPTS/run.sh"
if [[ -f "$RUN_SCRIPT" ]]; then
    chmod +x "$RUN_SCRIPT"
    echo "   ✅ 已设置执行权限：$RUN_SCRIPT"
else
    echo "   ❌ 错误：找不到 run.sh"
    exit 1
fi

# 4. 创建缓存和日志目录
echo ""
echo "📁 创建目录..."

mkdir -p "$WORKSPACE_SCRIPTS/.cache"
mkdir -p "$WORKSPACE_SCRIPTS/log"
echo "   ✅ 缓存目录：$WORKSPACE_SCRIPTS/.cache"
echo "   ✅ 日志目录：$WORKSPACE_SCRIPTS/log"

# 5. 配置 Cron Job
echo ""
echo "⏰ 配置 Cron Job..."

# 使用配置中的 schedule，如果没有则用默认值
CRON_SCHEDULE="${SCHEDULE:-30 6,14,22 * * *}"

# 检查是否已存在
if crontab -l 2>/dev/null | grep -q "open-source-monitor"; then
    echo "   ⚠️  Cron job 已存在，跳过"
    echo "   如需更新，请先运行：crontab -e 删除旧的 open-source-monitor 条目"
else
    # 添加 cron
    CRON_ENTRY="$CRON_SCHEDULE $RUN_SCRIPT"
    (crontab -l 2>/dev/null | grep -v "open-source-monitor"; echo "# Open Source Monitor - GitHub Release + Docker Hub 监控") | crontab -
    (crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -
    echo "   ✅ Cron job 已添加"
    echo "   时间：$CRON_SCHEDULE"
fi

# 6. 测试运行
echo ""
echo "🧪 测试运行..."

if "$RUN_SCRIPT" > /dev/null 2>&1; then
    echo "   ✅ 脚本运行成功"
else
    echo "   ⚠️  脚本运行失败，请检查日志"
    echo "   日志位置：$WORKSPACE_SCRIPTS/log/"
fi

# 完成
echo ""
echo "================================"
echo "✅ 安装完成！"
echo ""
echo "📋 下一步："
echo "   1. 检查 Cron 状态：crontab -l"
echo "   2. 查看日志：ls -la $WORKSPACE_SCRIPTS/log/"
echo "   3. 手动测试：$RUN_SCRIPT"
echo ""
