#!/bin/bash
# =============================================================================
#  Cai dat MOT LAN cho moi thanh vien (Linux / macOS / Git Bash).
#  Windows nen dung scripts/setup.ps1. CI dung:  bash scripts/setup.sh --keys-only
#
#   1. Sinh khoa SSH rieng vao ssh-key/ o goc repo (khong dua len Git)
#   2. Them "ssh may1".."ssh may4" vao ~/.ssh/config (tru khi --keys-only)
# =============================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"   # goc repo (script nam trong scripts/)
KEYDIR="$ROOT/ssh-key"
mkdir -p "$KEYDIR"

echo "==> Khoa SSH ($KEYDIR)"
SINH_MOI=0
for k in id_ed25519:btl-hadoop ssh_host_ed25519_key:btl-host; do
  f="$KEYDIR/${k%%:*}"
  if [ ! -f "$f" ]; then
    ssh-keygen -q -t ed25519 -N '' -C "${k##*:}" -f "$f"; SINH_MOI=1
    echo "    Da sinh ${k%%:*}"
  else
    echo "    Da co ${k%%:*} - giu nguyen"
  fi
done
chmod 600 "$KEYDIR/id_ed25519" "$KEYDIR/ssh_host_ed25519_key"
# Container doc khoa duoi user root nen khong can quyen gi them.

[ "${1:-}" = "--keys-only" ] && exit 0
[ "$SINH_MOI" = 1 ] && ssh-keygen -R btl-hadoop-cluster >/dev/null 2>&1 || true

echo "==> Them may1..may4 vao ~/.ssh/config"
CFG="$HOME/.ssh/config"; mkdir -p "$HOME/.ssh"; touch "$CFG"
BAT_DAU='# >>> btl-cluster (sinh boi scripts/setup.ps1 - dung sua tay) >>>'
KET_THUC='# <<< btl-cluster <<<'
ID="$KEYDIR/id_ed25519"
command -v cygpath >/dev/null && ID="$(cygpath -m "$ID")"   # Git Bash: D:/... cho ca OpenSSH Windows

# Bo khoi cu (nhan theo tien to "# >>> btl-cluster") roi them khoi moi
awk -v b="$KET_THUC" 'index($0, "# >>> btl-cluster") == 1 {skip=1} !skip{print} $0==b{skip=0}' "$CFG" > "$CFG.tmp"
cat >> "$CFG.tmp" <<EOF

$BAT_DAU
#   ssh may1 = masternode | may2 = datanode1 | may3 = datanode2 | may4 = datanode3
Host may1
    Port 2201
Host may2
    Port 2202
Host may3
    Port 2203
Host may4
    Port 2204
Host may1 may2 may3 may4
    IgnoreUnknown WarnWeakCrypto
    WarnWeakCrypto no
    HostName 127.0.0.1
    User hadoop
    IdentityFile $ID
    IdentitiesOnly yes
    HostKeyAlias btl-hadoop-cluster
    StrictHostKeyChecking accept-new
    ServerAliveInterval 60
$KET_THUC
EOF
mv "$CFG.tmp" "$CFG"; chmod 600 "$CFG"
echo "    Da ghi $CFG"
echo
echo "XONG. Tiep theo: cd $ROOT && docker compose pull && docker compose up -d && ssh may1"
