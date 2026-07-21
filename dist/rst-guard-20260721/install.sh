#!/usr/bin/env bash
# One-shot installer for SSH RST Guard: build (if needed), install files, enable daemon.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${PREFIX:-/opt/rst-guard}"
CONF_DIR="${CONF_DIR:-/etc/rst-guard}"
UNIT_DIR="${UNIT_DIR:-/etc/systemd/system}"
SERVICE_NAME="rst-guard.service"

log() { printf '[install] %s\n' "$*"; }
die() { printf '[install] ERROR: %s\n' "$*" >&2; exit 1; }

need_root() {
	if [[ "$(id -u)" -ne 0 ]]; then
		die "请用 root 运行: sudo $0"
	fi
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

install_build_deps_apt() {
	if ! have_cmd apt-get; then
		return 1
	fi
	log "安装构建依赖 (apt)..."
	export DEBIAN_FRONTEND=noninteractive
	apt-get update -y
	apt-get install -y clang llvm libbpf-dev linux-libc-dev iproute2 make
}

ensure_deps() {
	have_cmd tc || die "缺少 tc (iproute2)"
	have_cmd ip || die "缺少 ip (iproute2)"
	if [[ ! -f "$ROOT/rst_guard.bpf.o" ]]; then
		if ! have_cmd make; then
			install_build_deps_apt || die "无预编译 rst_guard.bpf.o，且无法安装 make/clang"
		fi
		if ! have_cmd clang && ! have_cmd clang-18 && ! have_cmd clang-17; then
			install_build_deps_apt || die "需要 clang 才能编译 eBPF"
		fi
	fi
}

build_obj() {
	if [[ -f "$ROOT/rst_guard.bpf.o" ]]; then
		log "使用已有对象: $ROOT/rst_guard.bpf.o"
		return 0
	fi
	log "编译 rst_guard.bpf.o ..."
	make -C "$ROOT"
	[[ -f "$ROOT/rst_guard.bpf.o" ]] || die "编译失败，未生成 rst_guard.bpf.o"
}

install_files() {
	log "安装到 $PREFIX"
	mkdir -p "$PREFIX" "$CONF_DIR"
	install -m 0644 "$ROOT/rst_guard.bpf.o" "$PREFIX/rst_guard.bpf.o"
	install -m 0755 "$ROOT/scripts/rst-guardd" "$PREFIX/rst-guardd"
	if [[ -f "$ROOT/README.md" ]]; then
		install -m 0644 "$ROOT/README.md" "$PREFIX/README.md"
	fi
	if [[ -f "$ROOT/rst_guard.bpf.c" ]]; then
		install -m 0644 "$ROOT/rst_guard.bpf.c" "$PREFIX/rst_guard.bpf.c"
	fi
	if [[ -f "$ROOT/Makefile" ]]; then
		install -m 0644 "$ROOT/Makefile" "$PREFIX/Makefile"
	fi
	if [[ ! -f "$CONF_DIR/config" ]]; then
		install -m 0644 "$ROOT/deploy/config" "$CONF_DIR/config"
		log "写入默认配置 $CONF_DIR/config"
	else
		log "保留已有配置 $CONF_DIR/config"
	fi
	install -m 0644 "$ROOT/deploy/rst-guard.service" "$UNIT_DIR/$SERVICE_NAME"
}

start_daemon() {
	if have_cmd systemctl && [[ -d /run/systemd/system ]]; then
		log "启用并启动 systemd 服务 $SERVICE_NAME"
		systemctl daemon-reload
		systemctl enable --now "$SERVICE_NAME"
		systemctl --no-pager --full status "$SERVICE_NAME" || true
	else
		log "无 systemd，立即执行一次挂载..."
		"$PREFIX/rst-guardd" once
		log "可手动后台运行: nohup $PREFIX/rst-guardd daemon >/var/log/rst-guardd.log 2>&1 &"
	fi
}

main() {
	need_root
	ensure_deps
	build_obj
	install_files
	# First attach immediately so network is protected even if unit start lags.
	RST_GUARD_PREFIX="$PREFIX" RST_GUARD_OBJ="$PREFIX/rst_guard.bpf.o" \
		RST_GUARD_CONF="$CONF_DIR/config" \
		"$PREFIX/rst-guardd" once || log "WARN: 首次挂载部分失败，守护进程会重试"
	start_daemon
	log "完成。"
	log "配置: $CONF_DIR/config"
	log "状态: $PREFIX/rst-guardd status"
	log "卸载: sudo $ROOT/uninstall.sh  或  sudo /opt/rst-guard/../ 见 uninstall.sh"
}

main "$@"
