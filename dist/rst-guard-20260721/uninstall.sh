#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-/opt/rst-guard}"
CONF_DIR="${CONF_DIR:-/etc/rst-guard}"
UNIT_DIR="${UNIT_DIR:-/etc/systemd/system}"
SERVICE_NAME="rst-guard.service"
REMOVE_CONF="${REMOVE_CONF:-0}"

log() { printf '[uninstall] %s\n' "$*"; }
die() { printf '[uninstall] ERROR: %s\n' "$*" >&2; exit 1; }

[[ "$(id -u)" -eq 0 ]] || die "请用 root 运行: sudo $0"

if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
	systemctl disable --now "$SERVICE_NAME" 2>/dev/null || true
	rm -f "$UNIT_DIR/$SERVICE_NAME"
	systemctl daemon-reload || true
	log "已停止并移除 $SERVICE_NAME"
fi

if [[ -x "$PREFIX/rst-guardd" ]]; then
	"$PREFIX/rst-guardd" detach-all || true
else
	log "WARN: $PREFIX/rst-guardd 不存在，跳过自动 detach"
fi

rm -rf "$PREFIX"
if [[ "$REMOVE_CONF" == "1" ]]; then
	rm -rf "$CONF_DIR"
	log "已删除 $CONF_DIR"
else
	log "保留配置 $CONF_DIR (如需删除: REMOVE_CONF=1 $0)"
fi

log "卸载完成"
