#!/bin/bash

# Open Source Monitor - 统一监控 GitHub Release 和 Docker Hub 更新
# 输出 JSON 供 agentTurn 处理（AI 整理 release notes 并发送）

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/log"
CACHE_DIR="$SCRIPT_DIR/.cache"

# 确保目录存在
mkdir -p "$LOG_DIR"
mkdir -p "$CACHE_DIR"

# 日志文件（按天分割）
LOG_FILE="$LOG_DIR/$(date +%Y-%m-%d).log"
TIMESTAMP=$(date -Iseconds)

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# 配置文件
CONFIG_FILE="$SCRIPT_DIR/config.json"

if [[ ! -f "$CONFIG_FILE" ]]; then
    log "错误：配置文件不存在：$CONFIG_FILE"
    exit 1
fi

# 检查依赖
if ! command -v git >/dev/null 2>&1; then
    log "错误：未找到 git 命令"
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    log "错误：未找到 curl 命令"
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    log "错误：未找到 jq 命令"
    exit 1
fi

# 读取配置
TARGET_CHANNEL=$(jq -r '.target_channel' "$CONFIG_FILE")
TARGET_USER=$(jq -r '.target_user' "$CONFIG_FILE")

# 获取当前时间（GMT+8）
CURRENT_TIME=$(date "+%Y-%m-%d %H:%M")

log "=== Open Source 监控开始 ==="

# 初始化 GitHub
GITHUB_HAS_NEW=false
GITHUB_TOTAL_CHECKED=0
GITHUB_TOTAL_NEW=0
declare -a GITHUB_RELEASES=()

# 初始化 Docker
DOCKER_HAS_NEW=false
DOCKER_TOTAL_CHECKED=0
DOCKER_TOTAL_NEW=0
declare -a DOCKER_UPDATES=()

# ============================================
# GitHub Release 检查
# ============================================
log "--- 检查 GitHub Release ---"

while IFS= read -r REPO_SLUG; do
    [[ -z "$REPO_SLUG" ]] && continue
    ((GITHUB_TOTAL_CHECKED++))

    log "检查 GitHub: $REPO_SLUG"

    # 缓存文件
    CACHE_FILE="$CACHE_DIR/github_$(echo "$REPO_SLUG" | tr '/' '_').json"

    # 读取缓存版本
    CACHED_VERSION=""
    if [[ -f "$CACHE_FILE" ]]; then
        CACHED_VERSION=$(jq -r '.version' "$CACHE_FILE" 2>/dev/null || echo "")
    fi

    # 使用 git ls-remote 获取最新标签
    LATEST_VERSION=$(git ls-remote --tags "https://github.com/${REPO_SLUG}" 2>/dev/null | \
        sed 's|.*refs/tags/||' | \
        grep -v '^{}$' | \
        grep -v '\-beta\.' | grep -v '\-alpha\.' | grep -v '\-rc\.' | \
        grep -v '\-test\.' | grep -v '\-dev\.' | \
        grep -v '\-[0-9]\+$' | \
        sort -V | \
        tail -1 | \
        sed 's/^{//' || echo "")

    if [[ -z "$LATEST_VERSION" ]]; then
        log "警告：$REPO_SLUG - 无法获取标签"
        continue
    fi

    log "$REPO_SLUG - 缓存版本：${CACHED_VERSION:-无}, 最新版本：$LATEST_VERSION"

    # 检查是否为新版本
    if [[ "$LATEST_VERSION" != "$CACHED_VERSION" ]]; then
        log "✨ 发现新版本：$REPO_SLUG $LATEST_VERSION"
        
        # 更新缓存
        echo "{\"version\": \"$LATEST_VERSION\", \"last_check\": \"$TIMESTAMP\"}" > "$CACHE_FILE"
        
        # 添加到数组
        REPO_NAME=$(echo "$REPO_SLUG" | cut -d'/' -f2)
        GITHUB_RELEASES+=("{\"repo\": \"$REPO_NAME\", \"owner_repo\": \"$REPO_SLUG\", \"version\": \"$LATEST_VERSION\", \"tag_url\": \"https://github.com/$REPO_SLUG/releases/tag/$LATEST_VERSION\"}")
        
        ((GITHUB_TOTAL_NEW++))
        GITHUB_HAS_NEW=true
    else
        log "$REPO_SLUG - 无新版本"
    fi
done < <(jq -r '.github[]' "$CONFIG_FILE")

log "GitHub 检查完成：共检查 $GITHUB_TOTAL_CHECKED 个项目，发现 $GITHUB_TOTAL_NEW 个新版本"

# ============================================
# Docker Hub 检查
# ============================================
log "--- 检查 Docker Hub ---"

while IFS= read -r IMAGE_TAG; do
    [[ -z "$IMAGE_TAG" ]] && continue
    ((DOCKER_TOTAL_CHECKED++))

    # 解析 image:tag
    if [[ "$IMAGE_TAG" == *":"* ]]; then
        IMAGE_FULL=$(echo "$IMAGE_TAG" | cut -d':' -f1)
        TAG=$(echo "$IMAGE_TAG" | cut -d':' -f2)
    else
        IMAGE_FULL="$IMAGE_TAG"
        TAG="latest"
    fi

    # 解析 namespace/image
    if [[ "$IMAGE_FULL" == *"/"* ]]; then
        NAMESPACE=$(echo "$IMAGE_FULL" | cut -d'/' -f1)
        IMAGE_NAME=$(echo "$IMAGE_FULL" | cut -d'/' -f2)
    else
        # 官方镜像
        NAMESPACE="library"
        IMAGE_NAME="$IMAGE_FULL"
    fi

    log "检查 Docker: $NAMESPACE/$IMAGE_NAME:$TAG"

    # 缓存文件
    CACHE_FILE="$CACHE_DIR/docker_$(echo "$NAMESPACE"_"$IMAGE_NAME"_"$TAG" | tr '/' '_').json"

    # 读取缓存 digest
    CACHED_DIGEST=""
    if [[ -f "$CACHE_FILE" ]]; then
        CACHED_DIGEST=$(jq -r '.digest' "$CACHE_FILE" 2>/dev/null || echo "")
    fi

    # 调用 Docker Hub API v2
    API_URL="https://hub.docker.com/v2/repositories/${NAMESPACE}/${IMAGE_NAME}/tags/${TAG}"
    RESPONSE=$(curl -s "$API_URL" 2>/dev/null || echo "")

    if [[ -z "$RESPONSE" ]]; then
        log "警告：$NAMESPACE/$IMAGE_NAME:$TAG - API 返回空"
        continue
    fi

    # 检查是否 404
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL" 2>/dev/null || echo "000")
    if [[ "$HTTP_CODE" == "404" ]]; then
        log "警告：$NAMESPACE/$IMAGE_NAME:$TAG - 镜像或 tag 不存在 (404)"
        continue
    fi

    # 提取 digest 和更新时间
    # 结构：顶层 digest 是 manifest digest（最准确）
    NEW_DIGEST=$(echo "$RESPONSE" | jq -r '.digest // empty' 2>/dev/null || echo "")
    LAST_UPDATED=$(echo "$RESPONSE" | jq -r '.last_updated // empty' 2>/dev/null || echo "")

    if [[ -z "$NEW_DIGEST" ]]; then
        log "警告：$NAMESPACE/$IMAGE_NAME:$TAG - 无法获取 digest"
        continue
    fi

    log "$NAMESPACE/$IMAGE_NAME:$TAG - 缓存 digest: ${CACHED_DIGEST:-无}, 最新 digest: $NEW_DIGEST"

    # 检查是否有更新（digest 变化）
    if [[ "$NEW_DIGEST" != "$CACHED_DIGEST" ]]; then
        log "✨ 发现镜像更新：$NAMESPACE/$IMAGE_NAME:$TAG"
        
        # 更新缓存
        echo "{\"digest\": \"$NEW_DIGEST\", \"last_updated\": \"$LAST_UPDATED\", \"last_check\": \"$TIMESTAMP\"}" > "$CACHE_FILE"
        
        # 添加到数组
        DOCKER_UPDATES+=("{\"image\": \"$IMAGE_NAME\", \"namespace\": \"$NAMESPACE\", \"tag\": \"$TAG\", \"old_digest\": \"${CACHED_DIGEST:-null}\", \"new_digest\": \"$NEW_DIGEST\", \"last_updated\": \"$LAST_UPDATED\", \"hub_url\": \"https://hub.docker.com/r/$NAMESPACE/$IMAGE_NAME/tags\"}")
        
        ((DOCKER_TOTAL_NEW++))
        DOCKER_HAS_NEW=true
    else
        log "$NAMESPACE/$IMAGE_NAME:$TAG - 无更新"
    fi
done < <(jq -r '.docker[]' "$CONFIG_FILE")

log "Docker 检查完成：共检查 $DOCKER_TOTAL_CHECKED 个项目，发现 $DOCKER_TOTAL_NEW 个更新"

# ============================================
# 输出 JSON 供 agentTurn 处理
# ============================================
cat << JSON_OUTPUT
{
  "config": {
    "target_channel": "$TARGET_CHANNEL",
    "target_user": "$TARGET_USER",
    "current_time": "$CURRENT_TIME"
  },
  "github": {
    "has_new_version": $GITHUB_HAS_NEW,
    "total_checked": $GITHUB_TOTAL_CHECKED,
    "total_new": $GITHUB_TOTAL_NEW,
    "releases": [
$(if $GITHUB_HAS_NEW; then
  for i in "${!GITHUB_RELEASES[@]}"; do
    if [[ $i -gt 0 ]]; then echo ","; fi
    echo "    ${GITHUB_RELEASES[$i]}"
  done
fi)
    ]
  },
  "docker": {
    "has_new_version": $DOCKER_HAS_NEW,
    "total_checked": $DOCKER_TOTAL_CHECKED,
    "total_new": $DOCKER_TOTAL_NEW,
    "images": [
$(if $DOCKER_HAS_NEW; then
  for i in "${!DOCKER_UPDATES[@]}"; do
    if [[ $i -gt 0 ]]; then echo ","; fi
    echo "    ${DOCKER_UPDATES[$i]}"
  done
fi)
    ]
  }
}
JSON_OUTPUT

log "=== Open Source 监控任务已输出 ==="
