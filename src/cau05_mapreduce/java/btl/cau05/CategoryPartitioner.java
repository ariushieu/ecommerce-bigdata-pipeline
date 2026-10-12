package btl.cau05;

import java.util.HashMap;
import java.util.Map;

import org.apache.hadoop.conf.Configurable;
import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Partitioner;

/**
 * Partitioner theo category (truong dau cua khoa).
 * - Moi reducer nhan TRON VEN mot so danh muc -> moi tep part-r-0000x la bao cao day du
 *   cua cac danh muc do.
 * - Bang anh xa tuong minh (cau05.partition.map) chia 6 danh muc theo khoang chu cai:
 *   Beauty,Books -> 0 ; Electronics,Fashion -> 1 ; Home,Sports -> 2.
 *   Vi vay noi part-r-00000..00002 lai la duoc thu tu toan cuc (giong TotalOrderPartitioner)
 *   va tai can bang (xem README: so don sach moi reducer 5.172 / 4.340 / 4.896).
 * - Danh muc la (khong co trong bang) hoac so reducer khac -> bam (hash) category nhu
 *   HashPartitioner, van dam bao 1 danh muc chi ve 1 reducer.
 */
public class CategoryPartitioner extends Partitioner<Text, OrderStats> implements Configurable {

    public static final String MAP_KEY = "cau05.partition.map";
    public static final String DEFAULT_MAP =
            "Beauty=0,Books=0,Electronics=1,Fashion=1,Home=2,Sports=2";

    private Configuration conf;
    private final Map<String, Integer> mapping = new HashMap<>();

    @Override
    public void setConf(Configuration c) {
        this.conf = c;
        mapping.clear();
        for (String pair : c.get(MAP_KEY, DEFAULT_MAP).split(",")) {
            String[] kv = pair.trim().split("=");
            if (kv.length == 2) {
                mapping.put(kv[0].trim(), Integer.parseInt(kv[1].trim()));
            }
        }
    }

    @Override
    public Configuration getConf() { return conf; }

    /** Tach category: phan truoc dau TAB dau tien cua khoa. */
    static String categoryOf(Text key) {
        String k = key.toString();
        int tab = k.indexOf('\t');
        return tab < 0 ? k : k.substring(0, tab);
    }

    @Override
    public int getPartition(Text key, OrderStats value, int numPartitions) {
        String category = categoryOf(key);
        Integer p = mapping.get(category);
        if (p != null && p < numPartitions) {
            return p;
        }
        return (category.hashCode() & Integer.MAX_VALUE) % numPartitions;
    }
}
