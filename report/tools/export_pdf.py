#!/usr/bin/env python3
"""Xuat BaoCao.docx ra PDF bang LibreOffice (UNO), thay cho buoc "mo bang Word, cap nhat truong".

    soffice --headless --accept="socket,host=localhost,port=2002;urp;" &
    python3 export_pdf.py <BaoCao.docx> <BaoCao.pdf>

- Cap nhat muc luc, danh muc hinh, danh muc bang (so trang that).
- Ve khung vien doi cho trang bia (LibreOffice bo qua pgBorders display="firstPage" cua Word).
"""
import os
import sys
import time

import uno
from com.sun.star.beans import PropertyValue
from com.sun.star.table import BorderLine2


def prop(name, value):
    p = PropertyValue()
    p.Name, p.Value = name, value
    return p


def connect():
    local = uno.getComponentContext()
    resolver = local.ServiceManager.createInstanceWithContext("com.sun.star.bridge.UnoUrlResolver", local)
    for _ in range(60):
        try:
            return resolver.resolve("uno:socket,host=localhost,port=2002;urp;StarOffice.ComponentContext")
        except Exception:
            time.sleep(1)
    sys.exit("Khong ket noi duoc LibreOffice")


def cover_border(doc):
    """Khung vien doi (2,25 pt) cho kieu trang cua trang bia."""
    cur = doc.getCurrentController().getViewCursor()
    cur.jumpToFirstPage()
    style = doc.getStyleFamilies().getByName("PageStyles").getByName(cur.getPropertyValue("PageStyleName"))
    line = BorderLine2()
    line.LineStyle = 3                     # DOUBLE
    line.LineWidth = 79                    # 1/100 mm
    line.OuterLineWidth, line.InnerLineWidth, line.LineDistance = 26, 26, 27
    for side in ("Top", "Bottom", "Left", "Right"):
        style.setPropertyValue(side + "Border", line)
        style.setPropertyValue(side + "BorderDistance", 200)


def main():
    src, dst = (os.path.abspath(p) for p in sys.argv[1:3])
    ctx = connect()
    desktop = ctx.ServiceManager.createInstanceWithContext("com.sun.star.frame.Desktop", ctx)
    doc = desktop.loadComponentFromURL(uno.systemPathToFileUrl(src), "_blank", 0, (prop("Hidden", True),))
    cover_border(doc)
    indexes = doc.getDocumentIndexes()
    for _ in range(2):                      # 2 vong: so trang on dinh sau khi muc luc dai ra
        for i in range(indexes.getCount()):
            indexes.getByIndex(i).update()
        doc.refresh()
    doc.getTextFields().refresh()
    doc.storeToURL(uno.systemPathToFileUrl(dst), (prop("FilterName", "writer_pdf_Export"),))
    print("Muc luc/danh muc cap nhat: %d; da xuat %s" % (indexes.getCount(), dst))
    doc.close(True)


if __name__ == "__main__":
    main()
