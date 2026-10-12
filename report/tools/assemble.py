#!/usr/bin/env python3
"""Ghep report/sections/*.md thanh mot file Markdown cho pandoc.

    python3 assemble.py <thu-muc-sections> <thu-muc-build>

- Danh so bang/hinh theo chuong: [Bang:nhan] -> "Bảng 3.2", [Hinh:nhan] -> "Hình 3.1".
- Danh so tai lieu tham khao theo thu tu trong 90-*.md: [TL:nhan] -> [n].
- Doi khoi ```mermaid thanh tep .mmd (build/mermaid/) va chen anh .png thay the.
- Chu thich bang thanh "Table: ..." cua pandoc (dat tren bang),
  chu thich hinh thanh caption cua anh (dat duoi hinh).
- Sinh DANH MUC HINH / DANH MUC BANG truoc Loi mo dau.
Ket qua: <build>/BaoCao.md, <build>/mermaid/*.mmd
"""
import os
import re
import sys

SEC, BUILD = sys.argv[1], sys.argv[2]
KINDS = {"Bảng": "bang", "Hình": "hinh"}
TOKEN = re.compile(r"\[(Bảng|Hình):([a-z0-9-]+)\]")
CITE = re.compile(r"\[TL:([a-z0-9-]+)\]")
CHAPTER = re.compile(r"^# CHƯƠNG (\d+)")
APPENDIX = re.compile(r"^## Phụ lục ([A-Z])\.")
CAPTION = re.compile(r"^\*\[(Bảng|Hình):([a-z0-9-]+)\]\.\s*(.+?)\*\s*$")
IMAGE = re.compile(r"^!\[[^\]]*\]\(([^)]+)\)\s*$")
COMMENT = re.compile(r"<!--.*?-->", re.S)

files = sorted(f for f in os.listdir(SEC) if f.endswith(".md"))
texts = []
for f in files:
    with open(os.path.join(SEC, f), encoding="utf-8") as fh:
        texts.append((f, COMMENT.sub("", fh.read())))

# 1) Gan so cho moi nhan theo thu tu xuat hien cua chu thich
numbers, counters, captions = {}, {}, {"Bảng": [], "Hình": []}
chapter = "0"
for f, t in texts:
    for line in t.splitlines():
        m = CHAPTER.match(line) or APPENDIX.match(line)
        if m:
            chapter = m.group(1)
        c = CAPTION.match(line)
        if c:
            kind, label, title = c.groups()
            key = (kind, label)
            if key in numbers:
                sys.exit(f"Trung nhan {kind}:{label} ({f})")
            counters[(kind, chapter)] = counters.get((kind, chapter), 0) + 1
            numbers[key] = f"{chapter}.{counters[(kind, chapter)]}"
            captions[kind].append(f"{kind} {numbers[key]}. {title}")

# 2) Tai lieu tham khao (IEEE): danh so theo thu tu trich dan dau tien trong bai,
#    tai lieu khong duoc trich dan xep cuoi; muc 90-*.md duoc viet lai theo thu tu do.
entries = {}
for f, t in texts:
    if f.startswith("90-"):
        for m in re.finditer(r"^\[TL:([a-z0-9-]+)\]\s*(.+)$", t, re.M):
            entries[m.group(1)] = m.group(2).strip()
refs = {}
for f, t in texts:
    if not f.startswith("90-"):
        for m in CITE.finditer(t):
            if m.group(1) in entries:
                refs.setdefault(m.group(1), len(refs) + 1)
for label in entries:
    refs.setdefault(label, len(refs) + 1)
texts = [(f, "# TÀI LIỆU THAM KHẢO\n\n" + "\n\n".join(
            f"[{refs[k]}] {entries[k]}" for k in sorted(entries, key=refs.get)) + "\n")
         if f.startswith("90-") else (f, t) for f, t in texts]

missing = set()


def resolve(s):
    def tok(m):
        key = (m.group(1), m.group(2))
        if key not in numbers:
            missing.add(f"{key[0]}:{key[1]}")
            return f"{key[0]} ??"
        return f"{key[0]} {numbers[key]}"

    def cite(m):
        if m.group(1) not in refs:
            missing.add("TL:" + m.group(1))
            return "[??]"
        return f"[{refs[m.group(1)]}]"

    return CITE.sub(cite, TOKEN.sub(tok, s))


# 3) Chuyen chu thich, mermaid, anh
os.makedirs(os.path.join(BUILD, "mermaid"), exist_ok=True)
out, n_mmd = [], 0
for f, t in texts:
    if f.startswith("02-"):
        for kind, title in (("Hình", "DANH MỤC HÌNH"), ("Bảng", "DANH MỤC BẢNG")):
            out += [f"# {title}", ""] + [x for c in captions[kind] for x in (c, "")] + [""]
    lines = t.splitlines()
    i, block = 0, []
    while i < len(lines):
        line = lines[i]
        if line.strip() == "```mermaid":
            j = i + 1
            while j < len(lines) and lines[j].strip() != "```":
                j += 1
            n_mmd += 1
            name = f"so-do-{n_mmd:02d}"
            with open(os.path.join(BUILD, "mermaid", name + ".mmd"), "w", encoding="utf-8") as fh:
                fh.write("\n".join(lines[i + 1:j]) + "\n")
            block.append(f"![](mermaid/{name}.png)")
            i = j + 1
            continue
        c = CAPTION.match(line)
        if c and c.group(1) == "Hình":
            # gan chu thich vao anh gan nhat phia tren
            title = f"Hình {numbers[(c.group(1), c.group(2))]}. {resolve(c.group(3))}"
            for k in range(len(block) - 1, -1, -1):
                im = IMAGE.match(block[k])
                if im:
                    block[k] = f"![{title}]({im.group(1)})"
                    break
                if block[k].strip():
                    block.append(f"*{title}*")
                    break
            i += 1
            continue
        if c and c.group(1) == "Bảng":
            block.append(f"Table: Bảng {numbers[(c.group(1), c.group(2))]}. {resolve(c.group(3))}")
            i += 1
            continue
        block.append(resolve(line))
        i += 1
    out += block + [""]

with open(os.path.join(BUILD, "BaoCao.md"), "w", encoding="utf-8", newline="\n") as fh:
    fh.write("\n".join(out))

print(f"{len(files)} muc, {len(captions['Bảng'])} bang, {len(captions['Hình'])} hinh, "
      f"{len(refs)} tai lieu, {n_mmd} so do mermaid")
if missing:
    print("CANH BAO - nhan chua dinh nghia: " + ", ".join(sorted(missing)))
