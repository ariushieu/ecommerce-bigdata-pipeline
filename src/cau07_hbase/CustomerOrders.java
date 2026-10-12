// Cau 7 - Bang HBase btl:customer_orders bang Java Client API (HBase 2.5).
//
// RowKey  : customer_id#reverse_timestamp  (reverse_ts = Long.MAX_VALUE - epoch_ms, 19 chu so)
//           -> cac don cua mot khach nam lien nhau, don MOI NHAT dung DAU khi scan theo tien to.
// CF  o   : thong tin don (order_id, ts, san pham, danh muc, kenh, tinh giao, nguon, quality_flag)
// CF  m   : tien (quantity, unit_price, discount_rate, shipping_fee, net_revenue)
// CF  d   : giao hang + phan hoi (delivery_days, returned_flag, review_score, status nhieu phien ban)
// Timestamp cua cell = thoi diem nghiep vu (event time), KHONG phai thoi diem nap -> TTL tinh theo
// tuoi that cua don hang.
//
// Bien dich : javac -cp "$(hbase classpath)" -d build CustomerOrders.java
// Chay      : java [-Dtable=ns:ten] -cp "build:$(hbase classpath)" CustomerOrders <lenh> [tham so]
//   create  [--recreate]              tao namespace + bang (neu chua co)
//   load    <csv tren HDFS>           nap don sach (quy uoc muc 2) bang BufferedMutator
//   count                             dem dong theo tung region (kiem tra pre-split)
//   latest  <customer_id> <n>         n don moi nhat cua khach (prefix scan)
//   get     <rowkey>                  doc mot dong (moi cell kem timestamp)
//   history <rowkey>                  cac phien ban cua d:status
//   status  <rowkey> <GIA_TRI> [ts]   ghi them mot phien ban d:status (mac dinh ts = hien tai)
//   delete  <rowkey> [cf:q [ts]]      xoa ca dong | moi phien ban cua cot | dung mot phien ban
//   flush                             flush memstore xuong HFile (do dung luong)
//   drop                              disable + delete bang
//   selftest                          kiem thu nhanh tren bang tam (test.sh dung)

import java.io.BufferedReader;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.hbase.Cell;
import org.apache.hadoop.hbase.CellUtil;
import org.apache.hadoop.hbase.HBaseConfiguration;
import org.apache.hadoop.hbase.HRegionLocation;
import org.apache.hadoop.hbase.NamespaceDescriptor;
import org.apache.hadoop.hbase.NamespaceNotFoundException;
import org.apache.hadoop.hbase.TableExistsException;
import org.apache.hadoop.hbase.TableName;
import org.apache.hadoop.hbase.client.Admin;
import org.apache.hadoop.hbase.client.BufferedMutator;
import org.apache.hadoop.hbase.client.BufferedMutatorParams;
import org.apache.hadoop.hbase.client.ColumnFamilyDescriptor;
import org.apache.hadoop.hbase.client.ColumnFamilyDescriptorBuilder;
import org.apache.hadoop.hbase.client.Connection;
import org.apache.hadoop.hbase.client.ConnectionFactory;
import org.apache.hadoop.hbase.client.Delete;
import org.apache.hadoop.hbase.client.Get;
import org.apache.hadoop.hbase.client.Put;
import org.apache.hadoop.hbase.client.RegionLocator;
import org.apache.hadoop.hbase.client.Result;
import org.apache.hadoop.hbase.client.ResultScanner;
import org.apache.hadoop.hbase.client.Scan;
import org.apache.hadoop.hbase.client.Table;
import org.apache.hadoop.hbase.client.TableDescriptor;
import org.apache.hadoop.hbase.client.TableDescriptorBuilder;
import org.apache.hadoop.hbase.filter.FirstKeyOnlyFilter;
import org.apache.hadoop.hbase.io.compress.Compression;
import org.apache.hadoop.hbase.io.encoding.DataBlockEncoding;
import org.apache.hadoop.hbase.regionserver.BloomType;
import org.apache.hadoop.hbase.util.Bytes;

public class CustomerOrders {

    static final String NS = "btl";
    static final String TABLE = "btl:customer_orders";
    static final byte[] O = Bytes.toBytes("o");
    static final byte[] M = Bytes.toBytes("m");
    static final byte[] D = Bytes.toBytes("d");
    static final int TTL_SECONDS = 3 * 365 * 24 * 3600;      // 3 nam = 94.608.000 giay
    static final int STATUS_VERSIONS = 5;
    // 1.200 khach C00001..C01200, so don moi khach gan deu -> 5 diem chia = 6 region
    static final String[] SPLITS = {"C00201", "C00401", "C00601", "C00801", "C01001"};
    static final ZoneId TZ = ZoneId.of("Asia/Ho_Chi_Minh");   // gio dia phuong cua san (+07:00)
    static final long DAY_MS = 86_400_000L;
    static final Set<String> BAD_FLAGS = new HashSet<>(Arrays.asList("OUTLIER", "DUPLICATE", "LATE"));

    // ------------------------------------------------------------------ rowkey
    static long eventMillis(String iso) {
        return LocalDateTime.parse(iso).atZone(TZ).toInstant().toEpochMilli();
    }

    static String rowKey(String customerId, long tsMillis) {
        return customerId + "#" + String.format("%019d", Long.MAX_VALUE - tsMillis);
    }

    // ------------------------------------------------------------------ create
    // -Dplain=true: bo nen + bo ma hoa khoi (chi de do so sanh dung luong)
    static final boolean PLAIN = Boolean.getBoolean("plain");

    static ColumnFamilyDescriptor family(byte[] name, int versions) {
        return ColumnFamilyDescriptorBuilder.newBuilder(name)
                .setMaxVersions(versions)
                .setTimeToLive(TTL_SECONDS)
                .setCompressionType(PLAIN ? Compression.Algorithm.NONE : Compression.Algorithm.SNAPPY)
                .setBloomFilterType(BloomType.ROW)
                .setDataBlockEncoding(PLAIN ? DataBlockEncoding.NONE : DataBlockEncoding.FAST_DIFF)
                .build();
    }

    static void create(Connection conn, String table, boolean recreate) throws IOException {
        TableName tn = TableName.valueOf(table);
        try (Admin admin = conn.getAdmin()) {
            String ns = tn.getNamespaceAsString();
            try {
                admin.getNamespaceDescriptor(ns);
            } catch (NamespaceNotFoundException e) {
                try {
                    admin.createNamespace(NamespaceDescriptor.create(ns).build());
                    System.out.println("tao namespace " + ns);
                } catch (IOException race) {   // thanh vien khac vua tao cung luc
                    System.out.println("namespace " + ns + " da co (" + race.getClass().getSimpleName() + ")");
                }
            }
            if (admin.tableExists(tn)) {
                if (!recreate) {
                    System.out.println("bang " + table + " da co -> giu nguyen");
                    return;
                }
                if (admin.isTableEnabled(tn)) admin.disableTable(tn);
                admin.deleteTable(tn);
                System.out.println("xoa bang cu " + table);
            }
            TableDescriptor td = TableDescriptorBuilder.newBuilder(tn)
                    .setColumnFamily(family(O, 1))
                    .setColumnFamily(family(M, 1))
                    .setColumnFamily(family(D, STATUS_VERSIONS))
                    .build();
            byte[][] splits = new byte[SPLITS.length][];
            for (int i = 0; i < SPLITS.length; i++) splits[i] = Bytes.toBytes(SPLITS[i]);
            try {
                admin.createTable(td, splits);
            } catch (TableExistsException e) {
                System.out.println("bang " + table + " vua duoc tao boi tien trinh khac");
                return;
            }
            System.out.println("tao bang " + table + " voi " + (SPLITS.length + 1) + " region, "
                    + "TTL=" + TTL_SECONDS + (PLAIN ? "s, KHONG nen, KHONG ma hoa" : "s, SNAPPY, FAST_DIFF") + ", BLOOM ROW, d:VERSIONS=" + STATUS_VERSIONS);
        }
    }

    // ------------------------------------------------------------------ put
    static void add(Put p, byte[] cf, String q, long ts, String v) {
        if (v != null && !v.isEmpty()) p.addColumn(cf, Bytes.toBytes(q), ts, Bytes.toBytes(v));
    }

    /** Mot dong CSV orders (23 cot) -> mot Put. Tra ve null neu bi loai theo quy uoc. */
    static Put toPut(String[] f) {
        String flag = f[22].trim().toUpperCase();
        if (BAD_FLAGS.contains(flag)) return null;
        long ts = eventMillis(f[1]);
        Put p = new Put(Bytes.toBytes(rowKey(f[7], ts)));
        add(p, O, "order_id", ts, f[6]);
        add(p, O, "ts", ts, f[1]);
        add(p, O, "province", ts, f[2]);
        add(p, O, "source_system", ts, f[3]);
        add(p, O, "ingest_mode", ts, f[4]);
        add(p, O, "product_id", ts, f[8]);
        add(p, O, "category", ts, f[9]);
        add(p, O, "segment", ts, f[10]);
        add(p, O, "channel", ts, f[11]);
        add(p, O, "payment", ts, f[17]);
        add(p, O, "campaign_id", ts, f[21]);     // rong -> khong ghi cell (NULL)
        add(p, O, "quality_flag", ts, flag);
        add(p, M, "quantity", ts, f[12]);
        add(p, M, "unit_price", ts, f[13]);
        add(p, M, "discount_rate", ts, f[14]);
        add(p, M, "shipping_fee", ts, f[15]);
        add(p, M, "net_revenue", ts, f[16]);
        int days = (int) Double.parseDouble(f[18]);
        add(p, D, "delivery_days", ts, Integer.toString(days));
        add(p, D, "returned_flag", ts, f[19]);
        add(p, D, "review_score", ts, f[20]);    // rong -> khong ghi cell (NULL)
        // lich su trang thai = nhieu phien ban cua d:status, moi phien ban mang thoi diem cua no.
        // Du lieu khong co gio giao/ngay tra -> giao = ts + delivery_days ngay; tra = giao + 1 ms
        // (+1 ms chi de 2 phien ban khong trung timestamp va giu dung thu tu).
        long delivered = ts + days * DAY_MS + (days == 0 ? 1 : 0);
        add(p, D, "status", ts, "PLACED");
        add(p, D, "status", delivered, "DELIVERED");
        if ("1".equals(f[19].trim())) add(p, D, "status", delivered + 1, "RETURNED");
        return p;
    }

    /** csvPath = "-" : doc tu stdin (vd: hdfs dfs -cat .../orders.csv | java CustomerOrders load -). */
    static void load(Connection conn, String csvPath, String table) throws IOException {
        long t0 = System.currentTimeMillis();
        int read = 0, put = 0, skipped = 0;
        BufferedMutatorParams params = new BufferedMutatorParams(TableName.valueOf(table))
                .writeBufferSize(4L * 1024 * 1024);
        InputStream in = "-".equals(csvPath) ? System.in : new FileInputStream(csvPath);
        try (BufferedReader br = new BufferedReader(new InputStreamReader(in, StandardCharsets.UTF_8));
             BufferedMutator mut = conn.getBufferedMutator(params)) {
            String header = br.readLine();               // bo dong tieu de (co BOM o dau)
            if (header != null && header.charAt(0) == (char) 0xFEFF) header = header.substring(1);
            if (header == null || !header.startsWith("record_id,")) throw new IOException("sai tieu de: " + header);
            String line;
            while ((line = br.readLine()) != null) {
                if (line.isEmpty()) continue;
                read++;
                String[] f = line.split(",", -1);         // da kiem tra: khong co dau phay/ngoac kep trong o
                if (f.length != 23) throw new IOException("dong " + read + " co " + f.length + " cot");
                Put p = toPut(f);
                if (p == null) { skipped++; continue; }
                mut.mutate(p);
                put++;
            }
        }
        System.out.printf("nap %s: doc %d dong, ghi %d dong (Put), bo %d (OUTLIER/DUPLICATE/LATE), %.1f s%n",
                table, read, put, skipped, (System.currentTimeMillis() - t0) / 1000.0);
    }

    // ------------------------------------------------------------------ doc
    static String show(Result r) {
        if (r.isEmpty()) return "(khong co dong nao)";
        StringBuilder sb = new StringBuilder(Bytes.toString(r.getRow()));
        for (Cell c : r.rawCells()) {
            sb.append("\n    ").append(Bytes.toString(CellUtil.cloneFamily(c))).append(':')
              .append(Bytes.toString(CellUtil.cloneQualifier(c))).append(" = ")
              .append(Bytes.toString(CellUtil.cloneValue(c)))
              .append("  @").append(java.time.Instant.ofEpochMilli(c.getTimestamp()).atZone(TZ).toLocalDateTime());
        }
        return sb.toString();
    }

    static String brief(Result r) {
        return String.format("%s  %s  %s  %s  net=%s  status=%s", Bytes.toString(r.getRow()),
                v(r, O, "order_id"), v(r, O, "ts"), v(r, O, "category"), v(r, M, "net_revenue"), v(r, D, "status"));
    }

    static String v(Result r, byte[] cf, String q) {
        byte[] b = r.getValue(cf, Bytes.toBytes(q));
        return b == null ? "null" : Bytes.toString(b);
    }

    /** Prefix scan: n don moi nhat cua mot khach (reverse timestamp -> moi nhat truoc). */
    static List<Result> latest(Table t, String customerId, int n) throws IOException {
        Scan s = new Scan().setStartStopRowForPrefixScan(Bytes.toBytes(customerId + "#")).setLimit(n)
                .addFamily(O).addColumn(M, Bytes.toBytes("net_revenue")).addColumn(D, Bytes.toBytes("status"));
        List<Result> out = new ArrayList<>();
        try (ResultScanner rs = t.getScanner(s)) {
            for (Result r : rs) out.add(r);
        }
        return out;
    }

    static List<String> history(Table t, String row) throws IOException {
        Get g = new Get(Bytes.toBytes(row)).addColumn(D, Bytes.toBytes("status")).readVersions(STATUS_VERSIONS);
        List<String> out = new ArrayList<>();
        for (Cell c : t.get(g).getColumnCells(D, Bytes.toBytes("status"))) {
            out.add(Bytes.toString(CellUtil.cloneValue(c)) + "@"
                    + java.time.Instant.ofEpochMilli(c.getTimestamp()).atZone(TZ).toLocalDateTime());
        }
        return out;   // moi nhat truoc
    }

    static long count(Connection conn, String table) throws IOException {
        TableName tn = TableName.valueOf(table);
        long total = 0;
        try (RegionLocator loc = conn.getRegionLocator(tn); Table t = conn.getTable(tn)) {
            System.out.println("region (start .. end)        RegionServer   so dong   so khach");
            for (HRegionLocation h : loc.getAllRegionLocations()) {
                byte[] start = h.getRegion().getStartKey(), end = h.getRegion().getEndKey();
                Scan s = new Scan().withStartRow(start).withStopRow(end).setFilter(new FirstKeyOnlyFilter())
                        .setCaching(1000);
                long n = 0;
                Set<String> cust = new HashSet<>();
                try (ResultScanner rs = t.getScanner(s)) {
                    for (Result r : rs) {
                        n++;
                        String k = Bytes.toString(r.getRow());
                        cust.add(k.substring(0, k.indexOf('#')));
                    }
                }
                System.out.printf("%-8s .. %-8s  %-14s %8d %10d%n", label(start), label(end),
                        h.getServerName().getHostname(), n, cust.size());
                total += n;
            }
        }
        System.out.println("tong so dong " + table + " = " + total);
        return total;
    }

    static String label(byte[] k) {
        return k.length == 0 ? "(-)" : Bytes.toString(k);
    }

    /** flush memstore xuong HFile (moi store dung 1 HFile sau lan nap dau) de do dung luong. */
    static void flush(Connection conn, String table) throws IOException {
        try (Admin admin = conn.getAdmin()) {
            admin.flush(TableName.valueOf(table));
            System.out.println("flush " + table);
        }
    }

    static void drop(Connection conn, String table) throws IOException {
        TableName tn = TableName.valueOf(table);
        try (Admin admin = conn.getAdmin()) {
            if (admin.tableExists(tn)) {
                if (admin.isTableEnabled(tn)) admin.disableTable(tn);
                admin.deleteTable(tn);
                System.out.println("xoa bang " + table);
            }
        }
    }

    // ------------------------------------------------------------------ selftest
    static int fails = 0;

    static void check(String name, boolean ok) {
        System.out.println((ok ? "PASS: " : "FAIL: ") + name);
        if (!ok) fails++;
    }

    static void selftest(Connection conn, String table) throws IOException {
        drop(conn, table);
        create(conn, table, false);
        try (Admin admin = conn.getAdmin()) {
            TableDescriptor td = admin.getDescriptor(TableName.valueOf(table));
            check("3 column family o/m/d", td.getColumnFamilyCount() == 3);
            check("d:VERSIONS=5, TTL=3 nam, SNAPPY",
                    td.getColumnFamily(D).getMaxVersions() == 5 && td.getColumnFamily(O).getTimeToLive() == TTL_SECONDS
                            && td.getColumnFamily(M).getCompressionType() == Compression.Algorithm.SNAPPY);
            check("pre-split 6 region", admin.getRegions(TableName.valueOf(table)).size() == SPLITS.length + 1);
        }
        // 3 don that cua C00941 (lay tu orders.csv) + 1 don cua khach khac
        String[][] rows = {
            "ORD0000001,2026-01-07T20:15:28,Khanh Hoa,mobile,stream,JSON,ORD0000001,C00941,P0225,Beauty,Regular,mobile,3,939.95,0.05,25.0,2703.86,bank_transfer,4,0,4,CP018,OK".split(",", -1),
            "ORDT000002,2025-03-01T08:00:00,Ha Noi,web,batch,CSV,ORDT000002,C00941,P0001,Beauty,Regular,web,1,100.0,0.0,0.0,100.0,card,2,1,,,MISSING".split(",", -1),
            "ORDT000003,2026-07-30T10:00:00,Ha Noi,web,batch,CSV,ORDT000003,C00941,P0002,Home,Regular,web,2,50.0,0.0,10.0,110.0,COD,0,0,5,CP001,OK".split(",", -1),
            "ORDT000004,2026-07-31T10:00:00,Ha Noi,web,batch,CSV,ORDT000004,C00942,P0002,Home,VIP,web,2,50.0,0.0,10.0,110.0,COD,1,0,5,CP001,OUTLIER".split(",", -1),
        };
        try (Table t = conn.getTable(TableName.valueOf(table))) {
            int n = 0;
            for (String[] f : rows) {
                Put p = toPut(f);
                if (p != null) { t.put(p); n++; }
            }
            check("put: 3 don sach, bo 1 don OUTLIER", n == 3);
            String key1 = rowKey("C00941", eventMillis("2026-01-07T20:15:28"));
            Result r = t.get(new Get(Bytes.toBytes(key1)));
            check("get: net_revenue = 2703.86", "2703.86".equals(v(r, M, "net_revenue")));
            check("cell timestamp = thoi diem dat hang",
                    r.getColumnLatestCell(O, Bytes.toBytes("order_id")).getTimestamp() == eventMillis("2026-01-07T20:15:28"));
            List<Result> l = latest(t, "C00941", 10);
            List<String> ids = new ArrayList<>();
            for (Result x : l) ids.add(v(x, O, "order_id"));
            check("scan prefix C00941#: moi nhat truoc " + ids,
                    ids.equals(Arrays.asList("ORDT000003", "ORD0000001", "ORDT000002")));
            String key2 = rowKey("C00941", eventMillis("2025-03-01T08:00:00"));
            List<String> h = history(t, key2);
            check("phien ban d:status (moi nhat truoc) " + h, h.size() == 3 && h.get(0).startsWith("RETURNED")
                    && h.get(2).startsWith("PLACED"));
            check("o trong -> khong co cell (review_score, campaign_id)",
                    t.get(new Get(Bytes.toBytes(key2))).getValue(D, Bytes.toBytes("review_score")) == null);
            t.delete(new Delete(Bytes.toBytes(key2)).addColumns(D, Bytes.toBytes("status")));
            check("delete cot d:status (moi phien ban)", history(t, key2).isEmpty());
            t.delete(new Delete(Bytes.toBytes(key2)));
            check("delete ca dong", t.get(new Get(Bytes.toBytes(key2))).isEmpty()
                    && latest(t, "C00941", 10).size() == 2);
        }
        drop(conn, table);
        try (Admin admin = conn.getAdmin()) {
            check("drop bang tam", !admin.tableExists(TableName.valueOf(table)));
        }
    }

    // ------------------------------------------------------------------ main
    public static void main(String[] a) throws Exception {
        if (a.length == 0) {
            System.err.println("lenh: create|load|count|latest|get|history|status|delete|drop|selftest");
            System.exit(2);
        }
        String table = System.getProperty("table", TABLE);   // doi bang: java -Dtable=ns:ten ...
        Configuration conf = HBaseConfiguration.create();
        try (Connection conn = ConnectionFactory.createConnection(conf)) {
            String cmd = a[0];
            if (cmd.equals("create")) {
                create(conn, table, a.length > 1 && a[1].equals("--recreate"));
                return;
            }
            if (cmd.equals("load")) { load(conn, a[1], table); return; }
            if (cmd.equals("count")) { count(conn, table); return; }
            if (cmd.equals("drop")) { drop(conn, table); return; }
            if (cmd.equals("flush")) { flush(conn, table); return; }
            if (cmd.equals("selftest")) {
                selftest(conn, System.getProperty("table", "btl:customer_orders_selftest"));
                System.out.println(fails == 0 ? "SELFTEST OK" : "SELFTEST FAIL " + fails);
                if (fails > 0) System.exit(1);
                return;
            }
            try (Table t = conn.getTable(TableName.valueOf(table))) {
                switch (cmd) {
                    case "latest":
                        for (Result r : latest(t, a[1], Integer.parseInt(a[2]))) System.out.println(brief(r));
                        break;
                    case "get":
                        System.out.println(show(t.get(new Get(Bytes.toBytes(a[1])))));
                        break;
                    case "history":
                        System.out.println(a[1] + " d:status " + history(t, a[1]));
                        break;
                    case "status": {   // status <rowkey> <GIA_TRI> [ts_ms]: them mot phien ban d:status
                        long ts = a.length > 3 ? Long.parseLong(a[3]) : System.currentTimeMillis();
                        t.put(new Put(Bytes.toBytes(a[1])).addColumn(D, Bytes.toBytes("status"), ts, Bytes.toBytes(a[2])));
                        System.out.println("put " + a[1] + " d:status=" + a[2] + " ts=" + ts);
                        break;
                    }
                    case "delete": {   // delete <rowkey> [cf:q [ts_ms]]: ca dong | moi phien ban | dung 1 phien ban
                        Delete d = new Delete(Bytes.toBytes(a[1]));
                        String what = "ca dong";
                        if (a.length > 2) {
                            String[] cq = a[2].split(":", 2);
                            if (a.length > 3) {
                                d.addColumn(Bytes.toBytes(cq[0]), Bytes.toBytes(cq[1]), Long.parseLong(a[3]));
                                what = a[2] + " phien ban ts=" + a[3];
                            } else {
                                d.addColumns(Bytes.toBytes(cq[0]), Bytes.toBytes(cq[1]));
                                what = a[2] + " moi phien ban";
                            }
                        }
                        t.delete(d);
                        System.out.println("delete " + a[1] + " (" + what + ")");
                        break;
                    }
                    default:
                        System.err.println("lenh khong ro: " + cmd);
                        System.exit(2);
                }
            }
        }
    }
}
