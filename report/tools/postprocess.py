#!/usr/bin/env python3
"""Hau xu ly BaoCao.docx do pandoc sinh ra cho dung quy dinh trinh bay cua mau CTKU122.

    python3 postprocess.py <BaoCao.docx>

1. Bang (sinh tu Markdown): rong du kho chu A4, giu ti le cot; chu trong o gian dong don,
   can trai (cot so giu can phai); hang tieu de in dam, can giua.
2. Danh sach: ky hieu "-" (cap 1), "+" (cap 2) thay cho cham tron; thut le thang voi
   thut dau dong cua doan van (1 cm).
3. So trang: giua chan trang, trang bia khong danh so.
4. Bat cap nhat truong khi mo bang Word (muc luc, danh muc hinh/bang co so trang).
"""
import os
import re
import sys
import zipfile

PATH = sys.argv[1]
TEXT_WIDTH = 11906 - 1701 - 1134        # A4 - le trai 3 cm - le phai 2 cm (twip)
CELL_SPACING = '<w:spacing w:before="20" w:after="20" w:line="240" w:lineRule="auto"/>'


# ---------------------------------------------------------------- 1. bang
def grid(m):
    cols = [int(w) for w in re.findall(r'w:w="(\d+)"', m.group(0))]
    total = sum(cols) or 1
    return "<w:tblGrid>" + "".join(
        '<w:gridCol w:w="%d" />' % round(c * TEXT_WIDTH / total) for c in cols) + "</w:tblGrid>"


def cell_paragraphs(row, header):
    """Dat gian dong don cho moi doan trong hang; hang tieu de can giua."""
    def fix_p(m):
        p = m.group(0)
        if "<w:pPr>" not in p:
            p = p.replace("<w:p>", "<w:p><w:pPr></w:pPr>", 1)
        def fix_ppr(mm):
            body = re.sub(r"<w:spacing\b[^>]*/>", "", mm.group(1))
            jc = re.search(r"<w:jc\b[^>]*/>", body)
            body = re.sub(r"<w:jc\b[^>]*/>", "", body)
            align = '<w:jc w:val="center"/>' if header else (jc.group(0) if jc else '<w:jc w:val="left"/>')
            style = re.search(r"<w:pStyle\b[^>]*/>", body)
            rest = re.sub(r"<w:pStyle\b[^>]*/>", "", body)
            # thu tu schema: pStyle ... spacing, ind, jc
            return ("<w:pPr>" + (style.group(0) if style else "") + rest + CELL_SPACING
                    + '<w:ind w:firstLine="0"/>' + align + "</w:pPr>")
        return re.sub(r"<w:pPr>(.*?)</w:pPr>", fix_ppr, p, count=1, flags=re.S)
    return re.sub(r"<w:p>.*?</w:p>|<w:p [^>]*>.*?</w:p>", fix_p, row, flags=re.S)


def fix_table(tbl):
    # Chi sua bang pandoc sinh tu Markdown (kieu "Table"); bang viet tay bang OpenXML
    # (trang bia, phieu danh gia) da dat san dinh dang nen giu nguyen.
    if '<w:tblStyle w:val="Table"' not in tbl:
        return tbl
    if 'w:tblLayout w:type="fixed"' in tbl:
        cols = [int(w) for w in re.findall(r'<w:gridCol w:w="(\d+)"', tbl)]
        k = TEXT_WIDTH / (sum(cols) or 1)
        tbl = re.sub(r"<w:tblGrid>.*?</w:tblGrid>", grid, tbl, flags=re.S)
        tbl = re.sub(r'(<w:tcW w:type="dxa" w:w=")(\d+)(")',
                     lambda m: m.group(1) + str(round(int(m.group(2)) * k)) + m.group(3), tbl)
    else:
        tbl = re.sub(r'<w:tblW w:type="auto" w:w="0"\s*/>', '<w:tblW w:type="pct" w:w="5000" />', tbl)
    rows = re.findall(r"<w:tr\b.*?</w:tr>", tbl, flags=re.S)
    for i, row in enumerate(rows):
        tbl = tbl.replace(row, cell_paragraphs(row, header=(i == 0)), 1)
    return tbl


SPACER = '<w:p><w:pPr><w:spacing w:before="0" w:after="0" w:line="120" w:lineRule="exact"/></w:pPr></w:p>'


def fix_code_blocks(xml):
    """Khoi ma: bo kieu ky tu VerbatimChar (11 pt) trong doan Source Code de dung co 9 pt cua doan."""
    def para(m):
        p = m.group(0)
        if '<w:pStyle w:val="SourceCode"' not in p:
            return p
        return re.sub(r'<w:rStyle w:val="VerbatimChar"\s*/>', "", p)
    return re.sub(r"<w:p\b[^>]*>.*?</w:p>", para, xml, flags=re.S)


def fix_document(xml):
    xml = fix_code_blocks(xml)
    # sau moi bang de mot khoang 6 pt, de doan "Nhan xet" khong dinh sat duoi bang
    xml = re.sub(r"<w:tbl>.*?</w:tbl>",
                 lambda m: fix_table(m.group(0)) + (SPACER if '<w:tblStyle w:val="Table"' in m.group(0) else ""),
                 xml, flags=re.S)
    # so trang o chan trang; trang bia (trang dau) khong danh so
    sect = list(re.finditer(r"<w:sectPr\b[^>]*>", xml))[-1]
    xml = xml[:sect.end()] + '<w:footerReference w:type="default" r:id="rIdBtlFooter"/>' + xml[sect.end():]
    tail = xml[sect.end():]
    if "<w:titlePg" not in tail:
        if "<w:docGrid" in tail:
            tail = tail.replace("<w:docGrid", "<w:titlePg/><w:docGrid", 1)
        else:
            tail = tail.replace("</w:sectPr>", "<w:titlePg/></w:sectPr>", 1)
        xml = xml[:sect.end()] + tail
    return xml


# ---------------------------------------------------------------- 2. danh sach
BULLET = {0: "-", 1: "+"}


def fix_numbering(xml):
    def lvl(m):
        x = m.group(0)
        i = int(m.group(1))
        left, hang = 851 + 567 * i, 284            # ky hieu o 1 cm (cap 1), 2 cm (cap 2)
        x = re.sub(r"<w:ind\b[^>]*/>", f'<w:ind w:left="{left}" w:hanging="{hang}"/>', x)
        if '<w:numFmt w:val="bullet"' in x:
            x = re.sub(r'<w:lvlText w:val="[^"]*"\s*/>', f'<w:lvlText w:val="{BULLET.get(i, "-")}"/>', x)
            font = '<w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:cs="Times New Roman" w:hint="default"/>'
            if "<w:rPr>" in x:
                x = re.sub(r"<w:rPr>.*?</w:rPr>", f"<w:rPr>{font}</w:rPr>", x, flags=re.S)
            else:
                x = x.replace("</w:lvl>", f"<w:rPr>{font}</w:rPr></w:lvl>")
        return x
    return re.sub(r'<w:lvl w:ilvl="(\d+)".*?</w:lvl>', lvl, xml, flags=re.S)


# ---------------------------------------------------------------- 3. so trang
FOOTER = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
          'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
          '<w:p><w:pPr><w:spacing w:before="0" w:after="0"/><w:ind w:firstLine="0"/><w:jc w:val="center"/></w:pPr>'
          '<w:r><w:fldChar w:fldCharType="begin"/></w:r>'
          '<w:r><w:instrText xml:space="preserve"> PAGE </w:instrText></w:r>'
          '<w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>1</w:t></w:r>'
          '<w:r><w:fldChar w:fldCharType="end"/></w:r></w:p></w:ftr>')
REL = ('<Relationship Id="rIdBtlFooter" '
       'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer1.xml"/>')
CT = ('<Override PartName="/word/footer1.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/>')


tmp = PATH + ".tmp"
n_tables = 0
with zipfile.ZipFile(PATH) as zin, zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as zout:
    names = zin.namelist()
    for item in zin.infolist():
        data = zin.read(item.filename)
        name = item.filename
        if name == "word/document.xml":
            text = data.decode("utf-8")
            n_tables = text.count('<w:tblStyle w:val="Table"')
            data = fix_document(text).encode("utf-8")
        elif name == "word/numbering.xml":
            data = fix_numbering(data.decode("utf-8")).encode("utf-8")
        elif name == "word/settings.xml":
            s = re.sub(r"<w:updateFields\b[^>]*/>", "", data.decode("utf-8"))
            s = re.sub(r"(<w:settings\b[^>]*>)", r'\1<w:updateFields w:val="true"/>', s, count=1)
            data = s.encode("utf-8")
        elif name == "word/_rels/document.xml.rels":
            data = data.decode("utf-8").replace("</Relationships>", REL + "</Relationships>").encode("utf-8")
        elif name == "[Content_Types].xml":
            data = data.decode("utf-8").replace("</Types>", CT + "</Types>").encode("utf-8")
        zout.writestr(item, data)
    if "word/footer1.xml" not in names:
        zout.writestr("word/footer1.xml", FOOTER)
os.replace(tmp, PATH)
print("Hau xu ly: %d bang, danh sach '-'/'+', so trang chan trang" % n_tables)
