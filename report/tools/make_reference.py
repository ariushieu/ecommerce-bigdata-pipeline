#!/usr/bin/env python3
"""Sua reference.docx mac dinh cua pandoc theo quy dinh trinh bay cua mau CTKU122.

    python3 make_reference.py <vao.docx> <ra.docx>

A4; le trai 3 cm, phai/tren/duoi 2 cm; Times New Roman 13, gian dong 1,3;
ten chuong 16 dam (can giua), muc cap 1 14 dam; bang co ke khung; chu thich nghieng can giua.
"""
import re
import sys
import zipfile

SRC, DST = sys.argv[1], sys.argv[2]
FONT = '<w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:eastAsia="Times New Roman" w:cs="Times New Roman"/>'


def rpr(size_half_pt, bold=False, italic=False):
    return ("<w:rPr>" + FONT + ("<w:b/><w:bCs/>" if bold else "") + ("<w:i/><w:iCs/>" if italic else "")
            + '<w:color w:val="000000"/>'
            + f'<w:sz w:val="{size_half_pt}"/><w:szCs w:val="{size_half_pt}"/></w:rPr>')


DOC_DEFAULTS = ("<w:docDefaults><w:rPrDefault>" + rpr(26).replace('<w:color w:val="000000"/>', "")
                + '</w:rPrDefault><w:pPrDefault><w:pPr><w:spacing w:before="0" w:after="120" '
                'w:line="312" w:lineRule="auto"/><w:jc w:val="both"/></w:pPr></w:pPrDefault></w:docDefaults>')

# styleId -> (rPr, pPr bo sung)
STYLES = {
    "Heading1": (rpr(32, bold=True), '<w:pageBreakBefore/><w:spacing w:before="0" w:after="240"/><w:jc w:val="center"/>'),
    "Heading2": (rpr(28, bold=True), '<w:spacing w:before="200" w:after="120"/><w:jc w:val="left"/>'),
    "Heading3": (rpr(26, bold=True), '<w:spacing w:before="160" w:after="80"/><w:jc w:val="left"/>'),
    "Heading4": (rpr(26, bold=True, italic=True), '<w:jc w:val="left"/>'),
    "Title": (rpr(32, bold=True), '<w:jc w:val="center"/>'),
    "TOCHeading": (rpr(32, bold=True), '<w:jc w:val="center"/>'),
    "ImageCaption": (rpr(26, italic=True), '<w:spacing w:after="200"/><w:jc w:val="center"/>'),
    "TableCaption": (rpr(26, italic=True), '<w:keepNext/><w:jc w:val="center"/>'),
    "Caption": (rpr(26, italic=True), '<w:jc w:val="center"/>'),
    "CaptionedFigure": ("", '<w:jc w:val="center"/>'),
    "Figure": ("", '<w:jc w:val="center"/>'),
    "SourceCode": ("", '<w:spacing w:line="240" w:lineRule="auto"/><w:jc w:val="left"/>'),
}

TABLE_STYLE = (
    '<w:style w:type="table" w:default="1" w:styleId="Table"><w:name w:val="Table"/>'
    '<w:basedOn w:val="TableNormal"/><w:uiPriority w:val="59"/><w:pPr><w:spacing w:after="0" w:line="264" '
    'w:lineRule="auto"/><w:jc w:val="left"/></w:pPr><w:rPr><w:sz w:val="24"/><w:szCs w:val="24"/></w:rPr>'
    '<w:tblPr><w:tblInd w:w="0" w:type="dxa"/><w:tblBorders>'
    + "".join(f'<w:{b} w:val="single" w:sz="4" w:space="0" w:color="000000"/>'
              for b in ("top", "left", "bottom", "right", "insideH", "insideV"))
    + '</w:tblBorders><w:tblCellMar><w:left w:w="80" w:type="dxa"/><w:right w:w="80" w:type="dxa"/>'
    '</w:tblCellMar></w:tblPr>'
    '<w:tblStylePr w:type="firstRow"><w:rPr><w:b/><w:bCs/></w:rPr></w:tblStylePr></w:style>'
)


def patch_styles(xml):
    xml = re.sub(r"<w:docDefaults>.*?</w:docDefaults>", DOC_DEFAULTS, xml, flags=re.S)
    for sid, (r, p) in STYLES.items():
        m = re.search(r'<w:style [^>]*w:styleId="%s"[^>]*>.*?</w:style>' % sid, xml, re.S)
        if not m:
            continue
        s = m.group(0)
        old_r = re.search(r"<w:rPr>.*?</w:rPr>", s, re.S)
        if r:
            s = re.sub(r"<w:rPr>.*?</w:rPr>", "", s, flags=re.S)
        if p:
            if "<w:pPr>" in s:
                def merge(mm):
                    body = mm.group(1)
                    for tag in re.findall(r"<w:(\w+)", p):  # chi bo the ma p dat lai
                        body = re.sub(r"<w:%s\b[^>]*/>" % tag, "", body)
                    # giu dung thu tu schema: chen truoc outlineLvl neu co
                    if "<w:outlineLvl" in body:
                        body = body.replace("<w:outlineLvl", p + "<w:outlineLvl", 1)
                    else:
                        body += p
                    return "<w:pPr>" + body + "</w:pPr>"
                s = re.sub(r"<w:pPr>(.*?)</w:pPr>", merge, s, count=1, flags=re.S)
            else:
                rp = "" if (r or not old_r) else old_r.group(0)
                if rp:
                    s = s.replace(rp, "")
                s = s.replace("</w:style>", "<w:pPr>" + p + "</w:pPr>" + rp + "</w:style>")
        if r:
            s = s.replace("</w:style>", r + "</w:style>")
        xml = xml.replace(m.group(0), s)
    m = re.search(r'<w:style [^>]*w:styleId="Table"[^>]*>.*?</w:style>', xml, re.S)
    xml = xml.replace(m.group(0), TABLE_STYLE) if m else xml.replace("</w:styles>", TABLE_STYLE + "</w:styles>")
    return xml


def patch_document(xml):
    sect = ('<w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1134" w:right="1134" w:bottom="1134" '
            'w:left="1701" w:header="567" w:footer="567" w:gutter="0"/>'
            # khung vien doi chi o trang bia, giong mau CTKU122
            '<w:pgBorders w:display="firstPage">'
            '<w:top w:val="thinThickSmallGap" w:sz="24" w:space="1" w:color="auto"/>'
            '<w:left w:val="thinThickSmallGap" w:sz="24" w:space="4" w:color="auto"/>'
            '<w:bottom w:val="thickThinSmallGap" w:sz="24" w:space="1" w:color="auto"/>'
            '<w:right w:val="thickThinSmallGap" w:sz="24" w:space="4" w:color="auto"/>'
            '</w:pgBorders>')
    xml = re.sub(r"<w:pgSz\b[^>]*/>", "", xml)
    xml = re.sub(r"<w:pgMar\b[^>]*/>", "", xml)
    xml = re.sub(r"<w:sectPr\s*/>", "<w:sectPr></w:sectPr>", xml)
    if "<w:sectPr" in xml:
        return re.sub(r"(<w:sectPr\b[^>]*>)", r"\1" + sect, xml, count=1)
    return xml.replace("</w:body>", "<w:sectPr>" + sect + "</w:sectPr></w:body>")


with zipfile.ZipFile(SRC) as zin, zipfile.ZipFile(DST, "w", zipfile.ZIP_DEFLATED) as zout:
    for item in zin.infolist():
        data = zin.read(item.filename)
        if item.filename == "word/styles.xml":
            data = patch_styles(data.decode("utf-8")).encode("utf-8")
        elif item.filename == "word/document.xml":
            data = patch_document(data.decode("utf-8")).encode("utf-8")
        zout.writestr(item, data)
print("Da tao", DST)
