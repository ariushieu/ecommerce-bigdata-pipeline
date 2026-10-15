#!/usr/bin/env python3
"""Sua bang trong BaoCao.docx do pandoc sinh ra.

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


def fix(xml):
    n = xml.count("<w:tbl>")
    xml = re.sub(r'<w:tblLayout w:type="fixed"\s*/>', '<w:tblLayout w:type="autofit" />', xml)
    xml = re.sub(r'<w:tblW w:type="auto" w:w="0"\s*/>', '<w:tblW w:type="pct" w:w="5000" />', xml)
    xml = re.sub(r"<w:tcW [^>]*/>", "", xml)   # bo do rong o co dinh -> Word/LibreOffice tu tinh

    def grid(m):
        cols = [int(w) for w in re.findall(r'w:w="(\d+)"', m.group(0))]
        total = sum(cols) or 1
        return "<w:tblGrid>" + "".join(
            '<w:gridCol w:w="%d" />' % round(c * TEXT_WIDTH / total) for c in cols) + "</w:tblGrid>"

    xml = re.sub(r"<w:tblGrid>.*?</w:tblGrid>", grid, xml, flags=re.S)
    return xml, n


tmp = PATH + ".tmp"
with zipfile.ZipFile(PATH) as zin, zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as zout:
    for item in zin.infolist():
        data = zin.read(item.filename)
        if item.filename == "word/document.xml":
            text, n = fix(data.decode("utf-8"))
            data = text.encode("utf-8")
        zout.writestr(item, data)
os.replace(tmp, PATH)
print("Da sua %d bang" % n)
