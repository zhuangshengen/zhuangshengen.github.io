#!/usr/bin/env bash
#
# push-retry.sh — 重复执行 `git push` 直到成功为止。
#
# 用法:
#   ./push-retry.sh [remote] [branch] [max-attempts]
#
#   remote        默认 origin
#   branch        默认 main
#   max-attempts  默认 0 (0 = 无限重试,直到成功)
#
# 环境变量:
#   RETRY_DELAY   每次重试间隔秒数 (默认 5)
#
# 遇到重试也无法解决的"永久性错误"(认证失败、非快进拒绝等)会立即停止。

set -u

REMOTE="${1:-origin}"
BRANCH="${2:-main}"
MAX="${3:-0}"
DELAY="${RETRY_DELAY:-5}"

# 这些错误重试多少次都没用,出现即停止
PERMANENT_RE='authentication failed|access denied|permission denied|invalid username|invalid password|repository not found|does not appear to be a git repository|correct access rights|non-fast-forward|fetch first|cannot lock ref|failed to push some refs'

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "error: not inside a git repository (run this from a repo)." >&2
  exit 2
fi

attempt=0
while :; do
  attempt=$((attempt + 1))
  printf '[%s] attempt %d: git push %s %s ...\n' "$(date '+%H:%M:%S')" "$attempt" "$REMOTE" "$BRANCH"

  output="$(git push "$REMOTE" "$BRANCH" 2>&1)"
  if [ $? -eq 0 ]; then
    printf '[%s] OK: push succeeded on attempt %d.\n' "$(date '+%H:%M:%S')" "$attempt"
    exit 0
  fi

  printf '%s\n' "$output"

  if printf '%s' "$output" | grep -Eqi "$PERMANENT_RE"; then
    printf '[%s] permanent error detected (auth/rejected), stopping.\n' "$(date '+%H:%M:%S')"
    exit 1
  fi

  if [ "$MAX" -gt 0 ] && [ "$attempt" -ge "$MAX" ]; then
    printf '[%s] reached max attempts (%d), giving up.\n' "$(date '+%H:%M:%S')" "$MAX"
    exit 1
  fi

  printf '[%s] push failed, retrying in %ss ... (Ctrl+C to stop)\n' "$(date '+%H:%M:%S')" "$DELAY"
  sleep "$DELAY"
done
