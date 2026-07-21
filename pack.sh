#!/usr/bin/env bash
# Build a self-contained tarball for one-click install on target machines.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="${VERSION:-$(date +%Y%m%d)}"
OUT_DIR="${OUT_DIR:-$ROOT/dist}"
NAME="rst-guard-${VERSION}"
STAGE="$OUT_DIR/$NAME"

log() { printf '[pack] %s\n' "$*"; }

mkdir -p "$STAGE/scripts" "$STAGE/deploy"
make -C "$ROOT" clean all

install -m 0644 "$ROOT/rst_guard.bpf.c" "$STAGE/"
install -m 0644 "$ROOT/rst_guard.bpf.o" "$STAGE/"
install -m 0644 "$ROOT/Makefile" "$STAGE/"
install -m 0644 "$ROOT/README.md" "$STAGE/"
install -m 0755 "$ROOT/install.sh" "$STAGE/"
install -m 0755 "$ROOT/uninstall.sh" "$STAGE/"
install -m 0755 "$ROOT/scripts/rst-guardd" "$STAGE/scripts/"
install -m 0644 "$ROOT/deploy/rst-guard.service" "$STAGE/deploy/"
install -m 0644 "$ROOT/deploy/config" "$STAGE/deploy/"

# Convenience wrapper inside the package root
cat >"$STAGE/install-one-click.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
exec sudo ./install.sh "$@"
EOF
chmod 0755 "$STAGE/install-one-click.sh"

mkdir -p "$OUT_DIR"
TAR="$OUT_DIR/${NAME}.tar.gz"
tar -C "$OUT_DIR" -czf "$TAR" "$NAME"
log "packed: $TAR"
log "on target: tar xzf $(basename "$TAR") && cd $NAME && sudo ./install.sh"
