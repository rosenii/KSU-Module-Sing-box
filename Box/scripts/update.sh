#!/system/bin/sh
# sing-box core updater (not the KernelSU module updater)
# Usage: sh /data/adb/Box/scripts/update.sh official|mod

BASE=/data/adb/Box
BIN="$BASE/sing-box"
WORK="$BASE/working"
LOG="$WORK/update.log"
TMP="$WORK/update-tmp"
SOURCE=${1:-official}
LOCK="$WORK/update.lock"

mkdir -p "$WORK" || exit 1
log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; }
fail() { log "ERROR: $*"; rm -rf "$TMP"; rmdir "$LOCK" 2>/dev/null; exit 1; }

case "$SOURCE" in
  official) REPO='SagerNet/sing-box'; SOURCE_NAME='官方最新版（含测试版）' ;;
  mod) REPO='reF1nd/sing-box-releases'; SOURCE_NAME='reF1nd Mod 版' ;;
  *) fail "未知更新源：$SOURCE（允许 official 或 mod）" ;;
esac

[ -x "$BIN" ] || fail "核心不存在或不可执行：$BIN"
if ! mkdir "$LOCK" 2>/dev/null; then
  log 'ERROR: 已有更新任务正在运行。'
  exit 1
fi
trap 'rm -rf "$TMP"; rmdir "$LOCK" 2>/dev/null' EXIT HUP INT TERM

# Android ROMs differ: use curl, wget, or BusyBox wget if available.
download() {
  url="$1"; out="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fLsS --retry 2 --connect-timeout 15 --max-time 300 "$url" -o "$out"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -T 300 -t 2 -O "$out" "$url"
  elif command -v busybox >/dev/null 2>&1 && busybox wget --help >/dev/null 2>&1; then
    busybox wget -T 300 -t 2 -O "$out" "$url"
  elif command -v toybox >/dev/null 2>&1 && toybox wget --help >/dev/null 2>&1; then
    toybox wget -T 300 -O "$out" "$url"
  else
    return 127
  fi
}

version_of() {
  "$1" version 2>/dev/null | sed -n \
    's/.*sing-box version[[:space:]]\{1,\}\([^[:space:]]*\).*/\1/p; s/^version[[:space:]]\{1,\}\([^[:space:]]*\).*/\1/p' | head -n 1
}
LOCAL_VERSION=$(version_of "$BIN")
[ -n "$LOCAL_VERSION" ] || fail '无法读取本地核心版本'
log "更新源：$SOURCE_NAME；本地版本：$LOCAL_VERSION"

mkdir -p "$TMP" || fail '无法创建临时目录'
API="https://api.github.com/repos/$REPO/releases?per_page=1"
download "$API" "$TMP/release.json"
rc=$?
if [ "$rc" -ne 0 ]; then
  [ "$rc" -eq 127 ] && fail '缺少下载工具：请提供 curl、wget 或 BusyBox/toybox wget'
  fail '获取 GitHub Release 信息失败'
fi

TAG=$(sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$TMP/release.json" | head -n 1)
[ -n "$TAG" ] || fail '未能解析最新发布版本（API 返回内容异常）'
VERSION=${TAG#v}

ABI=$(getprop ro.product.cpu.abi 2>/dev/null)
MACHINE=$(uname -m 2>/dev/null)
case "$ABI:$MACHINE" in
  arm64-v8a:*|*:aarch64|*:arm64) ARCH='arm64' ;;
  armeabi-v7a:*|armeabi:*|*:armv7l|*:armv8l) ARCH='armv7' ;;
  x86_64:*|*:x86_64|*:amd64) ARCH='amd64' ;;
  x86:*|*:i686) ARCH='386' ;;
  *) fail "不支持的设备架构：$ABI / $MACHINE" ;;
esac

log "远程版本：$VERSION（$TAG）；设备架构：$ARCH"
if [ "$LOCAL_VERSION" = "$VERSION" ]; then
  log '本地版本与远程版本一致，无需更新。'
  exit 0
fi

# Select the CLI archive matching the source. reF1nd publishes Android-native
# Both sources must use Android-native CLI archives on Android devices.
# Never select Linux/glibc builds for an Android installation.
case "$ARCH" in
  arm64) PATTERN='android-arm64' ;;
  armv7) PATTERN='android-armv7' ;;
  amd64) PATTERN='android-amd64' ;;
  386)   PATTERN='android-386' ;;
esac
ASSET_URL=$(grep '"browser_download_url"' "$TMP/release.json" | sed -n 's/.*"browser_download_url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | grep "$PATTERN" | grep -E '\.tar\.gz(["?]|$)' | head -n 1)
[ -n "$ASSET_URL" ] || fail "该 Release 未提供匹配的 CLI 压缩包（$PATTERN，tar.gz）；不会使用其他架构或 APK 替换核心。"
ASSET=${ASSET_URL##*/}
log "下载核心：$ASSET"
download "$ASSET_URL" "$TMP/core.tar.gz"
rc=$?
if [ "$rc" -ne 0 ]; then
  [ "$rc" -eq 127 ] && fail '缺少下载工具：请提供 curl、wget 或 BusyBox/toybox wget'
  fail "下载失败：$ASSET"
fi
[ -s "$TMP/core.tar.gz" ] || fail '下载文件为空'
command -v tar >/dev/null 2>&1 || fail '缺少 tar 命令，无法提取核心'
tar -tzf "$TMP/core.tar.gz" > "$TMP/archive-list.txt" 2>/dev/null || fail '下载文件不是有效的 tar.gz'
ENTRY=$(grep -E '(^|/)sing-box$' "$TMP/archive-list.txt" | head -n 1)
[ -n "$ENTRY" ] || fail '压缩包内未找到 sing-box 可执行文件'
tar -xOzf "$TMP/core.tar.gz" "$ENTRY" > "$TMP/sing-box.new" 2>/dev/null || fail '提取核心失败'
[ -s "$TMP/sing-box.new" ] || fail '提取出的核心文件为空'
chmod 0755 "$TMP/sing-box.new" || fail '无法设置新核心权限'
NEW_VERSION=$(version_of "$TMP/sing-box.new")
[ -n "$NEW_VERSION" ] || fail '新核心无法执行或无法读取版本'
[ "$NEW_VERSION" = "$VERSION" ] || fail "版本校验失败：预期 $VERSION，实际 $NEW_VERSION"

# Replace only after download and version validation. No backup is created.
# The temporary file is under the same filesystem as BIN for atomic rename.
if ! mv -f "$TMP/sing-box.new" "$BIN"; then
  fail '覆盖核心失败；原核心未被主动删除'
fi
chmod 0755 "$BIN" || fail '核心已替换，但设置可执行权限失败'
INSTALLED_VERSION=$(version_of "$BIN")
[ "$INSTALLED_VERSION" = "$VERSION" ] || fail "替换后复核失败（当前读到：${INSTALLED_VERSION:-未知}）"
log "更新成功：$LOCAL_VERSION -> $INSTALLED_VERSION；来源：$SOURCE_NAME"
log '未创建旧核心备份；当前运行中的进程不会自动重启。'
exit 0
