#!/usr/bin/env bash
# Demo Cau 7 - HBase (ssh may1):  bash ~/src/demo/cau07.sh   [nhanh]
# shellcheck source=lib.sh disable=SC1091
. "$(dirname "$0")/lib.sh" "$@"
cd "$SRC/cau07_hbase" || exit 1
T=btl:customer_orders

tieude "Cau 7 - Bang HBase lich su don cua khach (bao cao muc 3.2.2, 3.6)"

buoc "Tao bang, nap 14.408 don, demo Client API, snapshot, phan quyen (CustomerOrders.java)"
chay_lau 2 'bash run.sh > /dev/null 2>&1'

buoc "Rowkey customer_id#reverse_timestamp: 6 region chia theo khach, rai deu 3 RegionServer"
lenh "sed -n '/count\$/,\$p' output/load.txt"

buoc "Thiet ke bang: 3 column family o (don), m (tien), d (giao hang, 5 phien ban)"
lenh "echo \"describe '$T'\" | hbase shell -n 2>/dev/null | grep -E '^\\{NAME' | sed -E \"s/ (INDEX_BLOCK_ENCODING|KEEP_DELETED_CELLS|MIN_VERSIONS|REPLICATION_SCOPE|IN_MEMORY|BLOCKCACHE|BLOCKSIZE) => '[^']*',?//g\""

buoc "Mot lan quet theo tien to C00941# -> 5 don moi nhat cua khach, khong can sap xep"
lenh "echo \"scan '$T', {ROWPREFIXFILTER => 'C00941#', COLUMNS => ['o:order_id', 'o:ts', 'm:net_revenue'], LIMIT => 5}\" | hbase shell -n 2>/dev/null | grep -E 'column=|row'"

buoc "Lich su trang thai cua mot don (VERSIONS): DELIVERED -> RETURNED"
lenh "sed -n '/history/,/status /p' output/client_api_demo.txt | head -8"

buoc "Nen SNAPPY + FAST_DIFF: nho hon 5,79 lan so voi khong nen"
lenh 'cat output/compression.txt'
web "HBase http://localhost:16010 (Tables > btl:customer_orders > 6 region)"
