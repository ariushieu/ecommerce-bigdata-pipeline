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
IMAGE = re.compile(r"^!\[[^\]]*\]\(([^)]+)\)(\{[^}]*\})?\s*$")
IMG_WIDTH = "{width=78%}"   # mac dinh hinh rong 78% kho chu; ghi {width=...} ngay sau anh de doi
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


SEP_ROW = re.compile(r"^\|(\s*:?-+:?\s*\|)+\s*$")
CELL_SPLIT = re.compile(r"(?<!\\)\|")


def column_weights(longest, total=9071, char=130, pad=230):
    """Do rong cot (twip, tren kho chu A4 9.071 twip): cot ngan duoc du cho noi dung dai nhat
    (khong xuong dong), phan con lai chia cho cot dai theo do dai noi dung. Tra ve so dau '-'."""
    natural = [n * char + pad for n in longest]
    if sum(natural) <= total:
        widths = natural
    else:
        share = total / len(natural)
        short = [w <= share for w in natural]
        rest = total - sum(w for w, s in zip(natural, short) if s)
        long_len = [min(n, 80) for n, s in zip(longest, short) if not s]
        it = iter(long_len)
        widths = [w if s else rest * next(it) / sum(long_len) for w, s in zip(natural, short)]
    return [max(3, round(100 * w / sum(widths))) for w in widths]


def rebalance_tables(lines):
    """Chia lai do rong cot cua bang Markdown theo do dai noi dung.
    pandoc lay ti le cot tu so dau '-' o dong phan cach (khi bang rong hon 72 ky tu);
    tac gia thuong viet '|---|---|' nen cac cot bang nhau -> cot noi dung bi bop hep."""
    out, i = [], 0
    while i < len(lines):
        if lines[i].startswith("|") and i + 1 < len(lines) and SEP_ROW.match(lines[i + 1]):
            j = i
            while j < len(lines) and lines[j].startswith("|"):
                j += 1
            rows = [CELL_SPLIT.split(l.strip().strip("|")) for l in lines[i:j]]
            seps = rows[1]
            n = len(seps)
            longest = [3] * n
            for k, r in enumerate(rows):
                if k == 1:
                    continue
                for c, cell in enumerate(r[:n]):
                    text = re.sub(r"\*\*|`|\[(Bảng|Hình|TL):[a-z0-9-]+\]", "xx", cell.strip())
                    longest[c] = max(longest[c], len(text))
            weights = column_weights(longest)
            new_sep = "|" + "|".join(
                (":" if s.strip().startswith(":") else "") + "-" * w + (":" if s.strip().endswith(":") else "")
                for s, w in zip(seps, weights)) + "|"
            out += [lines[i], new_sep] + lines[i + 2:j]
            i = j
        else:
            out.append(lines[i])
            i += 1
    return out


def toc_field(style, items):
    """Truong TOC cua Word lay theo kieu chu thich (Word tu dien so trang khi cap nhat truong).
    Ket qua tam thoi (truoc khi cap nhat) la danh sach chu thich, de ban xem truoc van doc duoc."""
    esc = lambda s: s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    items = items or ["(chưa có)"]
    ps = []
    for i, it in enumerate(items):
        r = ""
        if i == 0:
            r += ('<w:r><w:fldChar w:fldCharType="begin" w:dirty="true"/></w:r>'
                  f'<w:r><w:instrText xml:space="preserve"> TOC \\h \\z \\t "{style},1" </w:instrText></w:r>'
                  '<w:r><w:fldChar w:fldCharType="separate"/></w:r>')
        r += f'<w:r><w:t xml:space="preserve">{esc(it)}</w:t></w:r>'
        if i == len(items) - 1:
            r += '<w:r><w:fldChar w:fldCharType="end"/></w:r>'
        ps.append(f'<w:p><w:pPr><w:ind w:firstLine="0"/><w:jc w:val="left"/></w:pPr>{r}</w:p>')
    return "```{=openxml}\n" + "\n".join(ps) + "\n```"


# 3) Chuyen chu thich, mermaid, anh
os.makedirs(os.path.join(BUILD, "mermaid"), exist_ok=True)
out, n_mmd = [], 0
for f, t in texts:
    if f.startswith("02-"):
        for kind, title, style in (("Hình", "DANH MỤC HÌNH", "Image Caption"),
                                   ("Bảng", "DANH MỤC BẢNG", "Table Caption")):
            out += [f"# {title}", "", toc_field(style, captions[kind]), ""]
    lines = rebalance_tables(t.splitlines())
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
                    block[k] = f"![{title}]({im.group(1)}){im.group(2) or IMG_WIDTH}"
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
