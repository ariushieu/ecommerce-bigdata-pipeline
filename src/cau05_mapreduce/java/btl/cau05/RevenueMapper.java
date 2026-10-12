package btl.cau05;

import java.io.IOException;
import java.math.BigDecimal;
import java.math.RoundingMode;

import org.apache.hadoop.io.LongWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Mapper;

/**
 * Mapper: (offset, dong CSV) -> (khoa nhom, OrderStats(1, xu, tra))
 *   Vao : LongWritable = vi tri byte cua dong, Text = 1 dong orders.csv
 *   Ra  : Text "category\tprovince\tmonth" (hoac "category\tmonth" khi cau05.level=category_month)
 *         OrderStats(1, net_revenue*100, returned_flag)
 * Khoa noi bang TAB: TAB (0x09) nho hon moi ky tu in duoc nen thu tu sap xep byte cua Text
 * trung voi thu tu theo tung truong (category, roi province, roi month); TextOutputFormat
 * in ra dong TSV dung cot.
 */
public class RevenueMapper extends Mapper<LongWritable, Text, Text, OrderStats> {

    public static final String LEVEL = "cau05.level";
    public static final String LEVEL_CPM = "category_province_month";
    public static final String LEVEL_CM = "category_month";
    static final int NUM_FIELDS = 23;
    static final char BOM = (char) 0xFEFF;   // Byte Order Mark UTF-8 sau khi giai ma
    // vi tri cot trong orders.csv (dem tu 0)
    static final int F_TIMESTAMP = 1, F_PROVINCE = 2, F_CATEGORY = 9,
            F_NET_REVENUE = 16, F_RETURNED = 19, F_FLAG = 22;

    private boolean categoryMonth;
    private final Text outKey = new Text();
    private final OrderStats outVal = new OrderStats();

    @Override
    protected void setup(Context ctx) {
        String level = ctx.getConfiguration().get(LEVEL, LEVEL_CPM);
        if (!LEVEL_CPM.equals(level) && !LEVEL_CM.equals(level)) {
            throw new IllegalArgumentException("cau05.level khong hop le: " + level);
        }
        categoryMonth = LEVEL_CM.equals(level);
    }

    @Override
    protected void map(LongWritable offset, Text value, Context ctx)
            throws IOException, InterruptedException {
        String line = value.toString();
        // BOM chi nam o dau tep (offset 0); LineRecordReader da cat \r\n, cat them \r cho chac
        if (!line.isEmpty() && line.charAt(0) == BOM) {
            line = line.substring(1);
        }
        if (line.endsWith("\r")) {
            line = line.substring(0, line.length() - 1);
        }
        if (line.isEmpty()) {
            ctx.getCounter(DataQuality.EMPTY_LINE).increment(1);
            return;
        }
        if (line.startsWith("record_id,")) {
            ctx.getCounter(DataQuality.HEADER_SKIPPED).increment(1);
            return;
        }
        String[] f = line.split(",", -1);   // -1: giu o trong o cuoi dong
        if (f.length != NUM_FIELDS) {
            ctx.getCounter(DataQuality.MALFORMED).increment(1);
            return;
        }

        // Quy tac lam sach chung (docs/quy-uoc.md muc 2)
        switch (f[F_FLAG]) {
            case "OUTLIER":   ctx.getCounter(DataQuality.DROP_OUTLIER).increment(1);   return;
            case "DUPLICATE": ctx.getCounter(DataQuality.DROP_DUPLICATE).increment(1); return;
            case "LATE":      ctx.getCounter(DataQuality.DROP_LATE).increment(1);      return;
            case "OK":
            case "MISSING":   break;
            default:          ctx.getCounter(DataQuality.MALFORMED).increment(1);      return;
        }

        String ts = f[F_TIMESTAMP], category = f[F_CATEGORY], province = f[F_PROVINCE];
        if (ts.length() < 7 || ts.charAt(4) != '-' || category.isEmpty() || province.isEmpty()) {
            ctx.getCounter(DataQuality.MALFORMED).increment(1);
            return;
        }
        long cents;
        long ret;
        try {
            // BigDecimal: "2703.86" -> 270386 xu, chinh xac tuyet doi
            cents = new BigDecimal(f[F_NET_REVENUE]).setScale(2, RoundingMode.HALF_UP)
                    .unscaledValue().longValueExact();
            ret = Long.parseLong(f[F_RETURNED]);
        } catch (NumberFormatException | ArithmeticException e) {
            ctx.getCounter(DataQuality.MALFORMED).increment(1);
            return;
        }
        if (ret != 0 && ret != 1) {
            ctx.getCounter(DataQuality.MALFORMED).increment(1);
            return;
        }
        ctx.getCounter("MISSING".equals(f[F_FLAG]) ? DataQuality.KEPT_MISSING
                                                   : DataQuality.KEPT_OK).increment(1);

        String month = ts.substring(0, 7);   // "2026-01-07T20:15:28" -> "2026-01"
        outKey.set(categoryMonth ? category + "\t" + month
                                 : category + "\t" + province + "\t" + month);
        outVal.set(1, cents, ret);
        ctx.write(outKey, outVal);
    }
}
