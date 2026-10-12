package btl.cau05;

import java.io.IOException;

import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Reducer;

/**
 * Combiner: (khoa, [OrderStats...]) -> (khoa, OrderStats tong mot phan)
 * Chay o phia Map (0, 1 hoac nhieu lan tuy so lan spill) nen dau vao/dau ra phai CUNG kieu
 * voi dau ra Mapper. Chi cong (giao hoan, ket hop) -> ket qua cuoi khong doi du Hadoop
 * goi Combiner bao nhieu lan. Khong tinh ty le o day.
 */
public class StatsCombiner extends Reducer<Text, OrderStats, Text, OrderStats> {
    private final OrderStats sum = new OrderStats();

    @Override
    protected void reduce(Text key, Iterable<OrderStats> values, Context ctx)
            throws IOException, InterruptedException {
        sum.set(0, 0, 0);
        for (OrderStats v : values) {
            sum.add(v);
        }
        ctx.write(key, sum);
    }
}
