#!/usr/bin/env bash
# Ghep report/sections/*.md thanh report/build/BaoCao.docx (chay tren may that, can Docker).
#   bash scripts/build-report.sh
# Moi cong cu chay trong container: python (btl-node), mermaid-cli, pandoc.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export MSYS_NO_PATHCONV=1   # Git Bash: khong doi duong dan /work/...
HOSTDIR="$ROOT"
if command -v cygpath >/dev/null 2>&1; then HOSTDIR="$(cygpath -m "$ROOT")"; fi

NODE_IMG=${NODE_IMG:-ghcr.io/ariushieu/ecommerce-bigdata-pipeline/btl-node:latest}
PANDOC_IMG=${PANDOC_IMG:-pandoc/core:3.5}
MERMAID_IMG=${MERMAID_IMG:-minlag/mermaid-cli:11.4.2}
UIDGID="$(id -u):$(id -g)"
run() { docker run --rm -u "$UIDGID" -v "$HOSTDIR:/work" -w /work "$@"; }

rm -rf report/build
mkdir -p report/build/mermaid

echo "== 1/4 Ghep cac muc"
run --entrypoint python3 "$NODE_IMG" -I report/tools/assemble.py report/sections report/build

echo "== 2/4 Ve so do mermaid"
shopt -s nullglob
mmd=(report/build/mermaid/*.mmd)
if [ ${#mmd[@]} -gt 0 ]; then
  for f in "${mmd[@]}"; do
    run "$MERMAID_IMG" -i "/work/$f" -o "/work/${f%.mmd}.png" -w 1600 -b white -q
  done
fi

echo "== 3/4 Tao reference.docx theo mau CTKU122"
run "$PANDOC_IMG" -o report/build/default-ref.docx --print-default-data-file reference.docx
run --entrypoint python3 "$NODE_IMG" -I report/tools/make_reference.py \
  report/build/default-ref.docx report/build/reference.docx

echo "== 4/4 pandoc -> BaoCao.docx"
run -w /work/report/build "$PANDOC_IMG" BaoCao.md -o BaoCao.docx \
  --from markdown-auto_identifiers+lists_without_preceding_blankline --reference-doc reference.docx --no-highlight \
  --resource-path .:/work/report/sections -M lang=vi-VN

run --entrypoint python3 "$NODE_IMG" -I report/tools/postprocess.py report/build/BaoCao.docx

ls -l report/build/BaoCao.docx

# --pdf: xuat BaoCao.pdf bang LibreOffice (font Times New Roman that, muc luc + danh muc
# co so trang, khung vien trang bia). Lan dau mat vai phut de tai LibreOffice va font.
if [ "${1:-}" = "--pdf" ]; then
  echo "== 5/5 LibreOffice -> BaoCao.pdf"
  docker run --rm -v "$HOSTDIR:/work" -w /work ubuntu:22.04 bash -c '
    export DEBIAN_FRONTEND=noninteractive
    sed -i "s/ main restricted$/ main restricted multiverse/" /etc/apt/sources.list
    apt-get update -qq >/dev/null 2>&1
    echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" | debconf-set-selections
    apt-get install -y -qq --no-install-recommends libreoffice-writer python3-uno fonts-liberation \
      ttf-mscorefonts-installer >/dev/null 2>&1
    soffice --headless --invisible --norestore --accept="socket,host=localhost,port=2002;urp;" >/dev/null 2>&1 &
    python3 report/tools/export_pdf.py report/build/BaoCao.docx report/build/BaoCao.pdf
    chown "'"$UIDGID"'" report/build/BaoCao.pdf'
  ls -l report/build/BaoCao.pdf
  echo "Xong: report/build/BaoCao.pdf (ban nop) va report/build/BaoCao.docx (ban sua bang Word)."
else
  echo "Xong. Mo report/build/BaoCao.docx bang Word, bam 'Yes' khi duoc hoi cap nhat muc luc."
  echo "Hoac chay: bash scripts/build-report.sh --pdf  de xuat luon BaoCao.pdf."
fi
