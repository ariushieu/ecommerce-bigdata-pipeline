#!/usr/bin/env python3
"""Hau xu ly BaoCao.docx do pandoc sinh ra: sua bang, bat cap nhat truong khi mo.

    python3 fix_tables.py <BaoCao.docx>

pandoc dat moi bang o che do "fixed", cot chia deu theo kho giay 5,5 inch (7.920 twip),
nen bang chi rong ~2/3 trang A4 (le 3/2 cm, kho chu 9.071 twip) va chu bi xuong dong nhieu.
Script chuyen bang sang tu co gian theo noi dung (autofit), rong 100% kho chu.
"""
import os
import re
import sys
import zipfile

PATH = sys.argv[1]
TEXT_WIDTH = 11906 - 1701 - 1134        # A4 - le trai 3 cm - le phai 2 cm (twip)


def grid(m):
    cols = [int(w) for w in re.findall(r'w:w="(\d+)"', m.group(0))]
    total = sum(cols) or 1
    return "<w:tblGrid>" + "".join(
        '<w:gridCol w:w="%d" />' % round(c * TEXT_WIDTH / total) for c in cols) + "</w:tblGrid>"


def fix_one(tbl):
    # Chi sua bang pandoc sinh tu Markdown (co kieu "Table"); bang viet tay bang OpenXML
    # (trang bia, phieu danh gia) da dat san do rong cot nen giu nguyen.
    if '<w:tblStyle w:val="Table"' not in tbl:
        return tbl
    if 'w:tblLayout w:type="fixed"' not in tbl:
        # bang ngan (pandoc khong dat do rong cot): cho tu co gian, rong het kho chu
        return re.sub(r'<w:tblW w:type="auto" w:w="0"\s*/>', '<w:tblW w:type="pct" w:w="5000" />', tbl)
    # bang dai: giu ti le cot pandoc tinh tu dong phan cach (assemble.py da chia theo noi dung),
    # gian ra du kho chu A4 thay vi 5,5 inch
    cols = [int(w) for w in re.findall(r'<w:gridCol w:w="(\d+)"', tbl)]
    k = TEXT_WIDTH / (sum(cols) or 1)
    tbl = re.sub(r"<w:tblGrid>.*?</w:tblGrid>", grid, tbl, flags=re.S)
    tbl = re.sub(r'(<w:tcW w:type="dxa" w:w=")(\d+)(")',
                 lambda m: m.group(1) + str(round(int(m.group(2)) * k)) + m.group(3), tbl)
    return re.sub(r'(<w:tcW w:w=")(\d+)(" w:type="dxa")',
                  lambda m: m.group(1) + str(round(int(m.group(2)) * k)) + m.group(3), tbl)


def fix(xml):
    tables = re.findall(r"<w:tbl>.*?</w:tbl>", xml, flags=re.S)
    xml = re.sub(r"<w:tbl>.*?</w:tbl>", lambda m: fix_one(m.group(0)), xml, flags=re.S)
    return xml, sum('<w:tblStyle w:val="Table"' in t for t in tables)


tmp = PATH + ".tmp"
with zipfile.ZipFile(PATH) as zin, zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as zout:
    for item in zin.infolist():
        data = zin.read(item.filename)
        if item.filename == "word/document.xml":
            text, n = fix(data.decode("utf-8"))
            data = text.encode("utf-8")
        elif item.filename == "word/settings.xml":
            # Word hoi cap nhat truong khi mo file -> muc luc, danh muc hinh/bang co so trang
            s = re.sub(r"<w:updateFields\b[^>]*/>", "", data.decode("utf-8"))
            s = re.sub(r"(<w:settings\b[^>]*>)", r'\1<w:updateFields w:val="true"/>', s, count=1)
            data = s.encode("utf-8")
        zout.writestr(item, data)
os.replace(tmp, PATH)
print("Da sua %d bang" % n)
