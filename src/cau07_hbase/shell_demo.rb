# Cau 7 - lenh hbase shell tren bang that btl:customer_orders (da nap bang CustomerOrders load).
#   hbase shell -n cau07_hbase/shell_demo.rb
# hbase shell la JRuby nen tinh rowkey customer_id#reverse_timestamp ngay trong script.

ZONE = java.time.ZoneId.of('Asia/Ho_Chi_Minh')
def ms(iso)
  java.time.LocalDateTime.parse(iso).atZone(ZONE).toInstant.toEpochMilli
end

def rk(cust, iso)
  format('%s#%019d', cust, java.lang.Long::MAX_VALUE - ms(iso))
end

def title(s)
  puts
  puts '==== ' + s
end

T = 'btl:customer_orders'.freeze
K1 = rk('C00941', '2026-01-07T20:15:28') # ORD0000001
KR = rk('C00941', '2025-09-29T03:02:19') # ORD0013507, don bi tra

title '1. describe: 3 column family, VERSIONS, TTL, COMPRESSION, BLOOMFILTER'
describe T

title '2. get mot don (rowkey ' + K1 + ')'
get T, K1

title '3. scan tien to C00941#: 5 don moi nhat truoc (reverse timestamp)'
scan T, { ROWPREFIXFILTER => 'C00941#', COLUMNS => ['o:order_id', 'o:ts', 'm:net_revenue', 'd:status'], LIMIT => 5 }

title '4. get nhieu phien ban d:status cua don bi tra ' + KR
get T, KR, { COLUMN => 'd:status', VERSIONS => 5 }

title '5. put them phien ban REFUNDED (timestamp tuong minh 2025-10-05) roi doc lai'
TS_REFUND = ms('2025-10-05T09:00:00')
put T, KR, 'd:status', 'REFUNDED', TS_REFUND
get T, KR, { COLUMN => 'd:status', VERSIONS => 5 }

title '6. get mac dinh chi tra phien ban moi nhat; TIMERANGE lay trang thai tai mot thoi diem'
get T, KR, { COLUMN => 'd:status' }
get T, KR, { COLUMN => 'd:status', TIMERANGE => [ms('2025-09-29T00:00:00'), ms('2025-10-01T00:00:00')], VERSIONS => 5 }

title '7. delete dung phien ban REFUNDED (theo timestamp) -> con 3 phien ban'
delete T, KR, 'd:status', TS_REFUND
get T, KR, { COLUMN => 'd:status', VERSIONS => 5 }

title '8. put / get / deleteall mot dong demo (khach C01200)'
KD = rk('C01200', '2026-07-31T23:59:59')
put T, KD, 'o:order_id', 'ORDDEMO0001'
put T, KD, 'm:net_revenue', '1234.50'
get T, KD
deleteall T, KD
get T, KD

title '9. count toan bang'
count T, INTERVAL => 5000, CACHE => 1000

title '10. TTL tinh theo timestamp cua cell: bang tam TTL 1 nam'
TT = 'btl:customer_orders_ttl_demo'.freeze
if list.include?(TT)
  disable TT
  drop TT
end
create TT, { NAME => 'd', TTL => 31_536_000 }
put TT, 'C00941#ts-2025-01', 'd:status', 'PLACED', ms('2025-01-10T10:00:00')
put TT, 'C00941#ts-hien-tai', 'd:status', 'PLACED'
scan TT
disable TT
drop TT

title '11. sao luu: snapshot + clone_snapshot (khoi phuc sang bang moi)'
SNAP = 'customer_orders_snap'.freeze
delete_snapshot SNAP if list_snapshots(SNAP).size > 0
snapshot T, SNAP
list_snapshots SNAP
RESTORE = 'btl:customer_orders_restore'.freeze
if list.include?(RESTORE)
  disable RESTORE
  drop RESTORE
end
clone_snapshot SNAP, RESTORE
count RESTORE, INTERVAL => 5000, CACHE => 1000
disable RESTORE
drop RESTORE

title '12. quyen: cap quyen chi doc (R) cho user analyst'
grant 'analyst', 'R', T
user_permission T
