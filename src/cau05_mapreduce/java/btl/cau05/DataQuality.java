package btl.cau05;

/** Counter tu dinh nghia: dem ban ghi bi bo / giu lai trong Mapper (bao cao so lieu lam sach). */
public enum DataQuality {
    HEADER_SKIPPED,   // dong tieu de (co BOM)
    EMPTY_LINE,       // dong rong
    MALFORMED,        // sai so cot, sai kieu so, thieu khoa
    DROP_OUTLIER,     // quality_flag = OUTLIER   -> bo
    DROP_DUPLICATE,   // quality_flag = DUPLICATE -> bo
    DROP_LATE,        // quality_flag = LATE      -> bo
    KEPT_OK,          // quality_flag = OK        -> giu
    KEPT_MISSING      // quality_flag = MISSING   -> giu (o trong la NULL, khong thay bang 0)
}
