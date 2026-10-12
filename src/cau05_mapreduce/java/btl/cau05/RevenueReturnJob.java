package btl.cau05;

import java.util.Map;
import java.util.TreeMap;

import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.conf.Configured;
import org.apache.hadoop.fs.FileSystem;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Counter;
import org.apache.hadoop.mapreduce.CounterGroup;
import org.apache.hadoop.mapreduce.Job;
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
import org.apache.hadoop.mapreduce.lib.input.TextInputFormat;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;
import org.apache.hadoop.mapreduce.lib.output.TextOutputFormat;
import org.apache.hadoop.util.Tool;
import org.apache.hadoop.util.ToolRunner;

/**
 * Driver Cau 5: tong doanh thu va ty le tra hang theo danh muc x tinh x thang.
 *   hadoop jar build/cau05.jar btl.cau05.RevenueReturnJob [-D tuy_chon=...] <input> <output>
 * Tuy chon (-D):
 *   cau05.level    = category_province_month (mac dinh) | category_month (gop len danh muc x thang)
 *   cau05.combiner = true (mac dinh) | false  (de so sanh counter co/khong Combiner)
 *   cau05.reducers = 3 (mac dinh)
 *   cau05.partition.map = Beauty=0,Books=0,... (xem CategoryPartitioner)
 * Sau khi xong in ra stdout: thoi gian chay va TOAN BO counter (dang "COUNTER<TAB>nhom<TAB>ten<TAB>gia tri").
 */
public class RevenueReturnJob extends Configured implements Tool {

    @Override
    public int run(String[] args) throws Exception {
        if (args.length != 2) {
            System.err.println("Cach dung: RevenueReturnJob [-D ...] <input> <output>");
            return 2;
        }
        Configuration conf = getConf();
        String level = conf.get(RevenueMapper.LEVEL, RevenueMapper.LEVEL_CPM);
        boolean useCombiner = conf.getBoolean("cau05.combiner", true);
        int reducers = conf.getInt("cau05.reducers", 3);

        Path in = new Path(args[0]);
        Path out = new Path(args[1]);
        FileSystem fs = out.getFileSystem(conf);
        if (fs.exists(out)) {
            fs.delete(out, true);   // chay lai duoc nhieu lan
        }

        Job job = Job.getInstance(conf, "cau05 " + level + (useCombiner ? "" : " (no combiner)"));
        job.setJarByClass(RevenueReturnJob.class);
        job.setInputFormatClass(TextInputFormat.class);
        job.setMapperClass(RevenueMapper.class);
        job.setMapOutputKeyClass(Text.class);
        job.setMapOutputValueClass(OrderStats.class);
        if (useCombiner) {
            job.setCombinerClass(StatsCombiner.class);
        }
        job.setPartitionerClass(CategoryPartitioner.class);
        job.setNumReduceTasks(reducers);
        job.setReducerClass(RateReducer.class);
        job.setOutputKeyClass(Text.class);
        job.setOutputValueClass(Text.class);
        job.setOutputFormatClass(TextOutputFormat.class);
        FileInputFormat.addInputPath(job, in);
        FileOutputFormat.setOutputPath(job, out);

        long t0 = System.currentTimeMillis();
        boolean ok = job.waitForCompletion(true);
        long ms = System.currentTimeMillis() - t0;

        System.out.println("JOB\t" + job.getJobName() + "\t" + (ok ? "SUCCEEDED" : "FAILED"));
        System.out.println("JOB_ID\t" + job.getJobID());
        System.out.println("ELAPSED_MS\t" + ms);
        System.out.println("REDUCERS\t" + reducers + "\tCOMBINER\t" + useCombiner);
        Map<String, Long> sorted = new TreeMap<>();
        for (CounterGroup g : job.getCounters()) {
            for (Counter c : g) {
                sorted.put(g.getName() + "\t" + c.getName(), c.getValue());
            }
        }
        for (Map.Entry<String, Long> e : sorted.entrySet()) {
            System.out.println("COUNTER\t" + e.getKey() + "\t" + e.getValue());
        }
        return ok ? 0 : 1;
    }

    public static void main(String[] args) throws Exception {
        System.exit(ToolRunner.run(new Configuration(), new RevenueReturnJob(), args));
    }
}
