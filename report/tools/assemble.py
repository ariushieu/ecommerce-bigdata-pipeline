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
            captions[kind].append(f"{kind} {numbers[key]}. {title.replace('`', '')}")

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
# kieu "Tai lieu tham khao": can trai, so [n] treo o le (dinh nghia trong make_reference.py)
texts = [(f, "# TÀI LIỆU THAM KHẢO\n\n::: {custom-style=\"Tai lieu tham khao\"}\n" + "\n\n".join(
            f"[{refs[k]}]\t{entries[k]}" for k in sorted(entries, key=refs.get)) + "\n:::\n")
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


def width_of(s):
    """Do rong uoc luong theo 'ky tu thuong': chu in hoa va chu so rong hon ~30%."""
    return len(s) + 0.5 * sum(ch.isupper() for ch in s) + 0.1 * sum(ch.isdigit() for ch in s)


def column_weights(longest, longest_word, total=9071, char=110, pad=300):
    """Do rong cot (twip, kho chu A4 9.071 twip; chu trong bang 12 pt ~110-120 twip/ky tu, chu so rong hon). Moi cot truoc het du cho tu dai nhat
    (khong cat ngang tu/so); phan con lai chia theo phan noi dung con thieu de khoi xuong dong.
    Tra ve so dau '-' cho dong phan cach cua pandoc."""
    need = [min(n, 90) * char + pad for n in longest]          # ca o tren mot dong
    # khong cat tu; va cot nao cung du toi thieu ~8 ky tu (cum ngan nhu "Có cấu trúc" khong vo vun)
    floor = [max(w, min(n, 8)) * char + pad for w, n in zip(longest_word, longest)]
    if sum(need) <= total:
        widths = need
    elif sum(floor) >= total:
        widths = floor
    else:
        extra = total - sum(floor)
        flex = [max(nd - fl, 0) for nd, fl in zip(need, floor)]
        root = [fx ** 0.5 for fx in flex]          # can bac hai: uu tien cot vua, cot rat dai bot an het
        widths = [fl + extra * r / (sum(root) or 1) for fl, r in zip(floor, root)]
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
            longest, longest_word = [3] * n, [2] * n
            for k, r in enumerate(rows):
                if k == 1:
                    continue
                for c, cell in enumerate(r[:n]):
                    text = re.sub(r"\*\*|`", "", cell.strip())
                    text = re.sub(r"\[(Bảng|Hình) ?:[a-z0-9-]+\]", "Bảng 1.10", text)
                    text = re.sub(r"\[TL:[a-z0-9-]+\]", "[10]", text)
                    longest[c] = max(longest[c], width_of(text))
                    longest_word[c] = max([longest_word[c]] + [width_of(w) for w in text.split()])
            weights = column_weights(longest, longest_word)
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


LEAD = re.compile(r"^(\s*(?:[-*+]|\d+\.)\s+)?(\*\*[^*]+\*\*:?)?(.*)$")


def tidy(line):
    """Van phong bao cao: chi giu in dam o nhan dau doan/dau muc (vd. "**Nhan xet ...:**"),
    bo in dam rai rac giua cau. Bang, khoi ma va OpenXML giu nguyen."""
    s = line.lstrip()
    if not s or s.startswith(("|", "```", "<", "#", "!", "Table:")):
        return line
    lead, bold, rest = LEAD.match(line).groups()
    return (lead or "") + (bold or "") + re.sub(r"\*\*([^*]+?)\*\*", r"\1", rest)


# 3) Chuyen chu thich, mermaid, anh
os.makedirs(os.path.join(BUILD, "mermaid"), exist_ok=True)
out, n_mmd = [], 0
for f, t in texts:
    if f.startswith("02-"):
        for kind, title, style in (("Hình", "DANH MỤC HÌNH", "Image Caption"),
                                   ("Bảng", "DANH MỤC BẢNG", "Table Caption")):
            out += [f"# {title}", "", toc_field(style, captions[kind]), ""]
    lines = rebalance_tables(t.splitlines())
    i, block, in_fence = 0, [], False
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
            # so do ngang (LR) rat rong -> de 100% kho chu cho chu khong qua nho
            wide = re.search(r"^\s*(flowchart|graph)\s+LR", "\n".join(lines[i + 1:j]), re.M)
            block.append(f"![](mermaid/{name}.png)" + ("{width=100%}" if wide else ""))
            i = j + 1
            continue
        c = CAPTION.match(line)
        if c and c.group(1) == "Hình":
            # gan chu thich vao anh gan nhat phia tren
            title = f"Hình {numbers[(c.group(1), c.group(2))]}. {resolve(c.group(3)).replace('`', '')}"
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
            block.append(f"Table: Bảng {numbers[(c.group(1), c.group(2))]}. {resolve(c.group(3)).replace('`', '')}")
            i += 1
            continue
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
        block.append(resolve(line if in_fence else tidy(line)))
        i += 1
    out += block + [""]

with open(os.path.join(BUILD, "BaoCao.md"), "w", encoding="utf-8", newline="\n") as fh:
    fh.write("\n".join(out))

print(f"{len(files)} muc, {len(captions['Bảng'])} bang, {len(captions['Hình'])} hinh, "
      f"{len(refs)} tai lieu, {n_mmd} so do mermaid")
if missing:
    print("CANH BAO - nhan chua dinh nghia: " + ", ".join(sorted(missing)))
