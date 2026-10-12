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
  --from markdown-auto_identifiers+lists_without_preceding_blankline --reference-doc reference.docx \
  --resource-path .:/work/report/sections --toc --toc-depth 3 -M toc-title="MỤC LỤC" -M lang=vi-VN

ls -l report/build/BaoCao.docx
echo "Xong. Mo report/build/BaoCao.docx bang Word, bam 'Yes' khi duoc hoi cap nhat muc luc."
