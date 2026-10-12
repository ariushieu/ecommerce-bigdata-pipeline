package btl.cau05;

import java.io.IOException;

import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Reducer;

/**
 * Reducer: (khoa, [OrderStats...]) -> (khoa, "orders\tnet_revenue\treturned\treturn_rate_pct")
 * Cong cac tong (tu Mapper hoac tu Combiner), roi moi chia de ra ty le tra hang.
 * Lam tron 2 chu so kieu HALF_UP bang so nguyen (khong qua double):
 *   rate x 100 = floor(10000 * returned / orders + 0.5) = (20000*returned + orders) / (2*orders)
 */
public class RateReducer extends Reducer<Text, OrderStats, Text, Text> {
    private final Text outVal = new Text();

    /** 270386 -> "2703.86"; 5 -> "0.05". */
    static String formatHundredths(long x) {
        long a = Math.abs(x);
        return (x < 0 ? "-" : "") + (a / 100) + "." + String.format("%02d", a % 100);
    }

    /** Ty le tra hang (%) x 100, lam tron HALF_UP. */
    static long returnRateX100(long returned, long orders) {
        return (20000L * returned + orders) / (2L * orders);
    }

    @Override
    protected void reduce(Text key, Iterable<OrderStats> values, Context ctx)
            throws IOException, InterruptedException {
        long n = 0, cents = 0, ret = 0;
        for (OrderStats v : values) {
            n += v.getOrders();
            cents += v.getRevenueCents();
            ret += v.getReturned();
        }
        outVal.set(n + "\t" + formatHundredths(cents) + "\t" + ret + "\t"
                + formatHundredths(returnRateX100(ret, n)));
        ctx.write(key, outVal);
    }
}
