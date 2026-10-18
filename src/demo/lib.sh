#!/usr/bin/env bash
# Ham dung chung cho cac script demo (source, khong chay truc tiep).
#   tieude "Cau 5 - MapReduce"     -> khung tieu de
#   buoc   "Chay 3 job"            -> dong mo ta buoc, cho Enter truoc khi chay
#   lenh   'hdfs dfs -ls /btl'     -> in lenh (mau xanh) roi chay
# Bien moi truong:
#   NOPAUSE=1  khong cho Enter giua cac buoc (chay thu mot mach)
# Tham so dau tien cua moi script demo:
#   nhanh      bo qua cac buoc chay lau, chi in ket qua da co (khi may cham / het gio)

DEMO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC2034  # SRC dung trong cac script goi lib.sh
SRC=$(cd "$DEMO_DIR/.." && pwd)
NHANH=0
[ "${1:-}" = "nhanh" ] && NHANH=1

if [ -t 1 ]; then
  C_TD=$'\033[1;36m'; C_BUOC=$'\033[1;33m'; C_LENH=$'\033[0;32m'; C_HET=$'\033[0m'
else
  C_TD=; C_BUOC=; C_LENH=; C_HET=
fi

TEN_DEMO=
KQ=()
WEB=()

tieude() {
  local dong="=============================================================================="
  TEN_DEMO=$*
  printf '\n%s%s\n  %s\n%s%s\n' "$C_TD" "$dong" "$*" "$dong" "$C_HET"
}

buoc() {
  printf '\n%s>> %s%s\n' "$C_BUOC" "$*" "$C_HET"
  if [ "${NOPAUSE:-0}" != 1 ] && [ -t 0 ]; then
    read -r -p "   [Enter de chay] " _
  fi
}

lenh() {
  printf '%s$ %s%s\n' "$C_LENH" "$*" "$C_HET"
  eval "$*"
}

# chay_lau <phut> <lenh...>: buoc chay lau; o che do "nhanh" thi bo qua
chay_lau() {
  local phut=$1; shift
  if [ "$NHANH" = 1 ]; then
    printf '   (che do nhanh: bo qua "%s", dung ket qua lan chay truoc)\n' "$*"
  else
    printf '   (mat khoang %s phut)\n' "$phut"
    lenh "$@"
  fi
}

# kq "dong ket qua"            -> ghi lai, in o khung tong ket cuoi script
# web <url> "can bam vao dau"  -> ghi lai link giao dien web, in o khung tong ket
kq()  { KQ+=("$*"); }
web() { WEB+=("$1|$2"); }

# tong_ket: khung "XONG" cuoi moi script: ket qua chinh + link web can mo (Ctrl + click de mo)
tong_ket() {
  local dong="==============================================================================" k w
  printf '\n%s%s\n  XONG: %s\n%s%s\n' "$C_TD" "$dong" "$TEN_DEMO" "$dong" "$C_HET"
  printf '%sKet qua:%s\n' "$C_BUOC" "$C_HET"
  for k in "${KQ[@]}"; do printf '  - %s\n' "$k"; done
  if [ "${#WEB[@]}" -gt 0 ]; then
    printf '\n%sMo trinh duyet de xem:%s\n' "$C_BUOC" "$C_HET"
    for w in "${WEB[@]}"; do printf '  %s%-24s%s %s\n' "$C_LENH" "${w%%|*}" "$C_HET" "${w#*|}"; done
  fi
  printf '%s%s%s\n' "$C_TD" "$dong" "$C_HET"
}
