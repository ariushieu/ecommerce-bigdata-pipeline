#!/usr/bin/env python3
"""Cau 1 - Profiling bo du lieu De 01 de lam can cu cho phan tich 5V.

Chi dung thu vien chuan cua Python 3.8 (chay duoc tren may1 hoac CI).

    python3 profile_data.py [--data /data] [--out output]

Ket qua:
    <out>/profile.json   so lieu tho (test.sh va bao cao doc tu day)
    <out>/profile.md     bang tom tat de dan vao report/cau01-5v.md
"""
import argparse
import collections
import csv
import json
import os
import sqlite3
import statistics
from datetime import datetime

ORDER_KEY_COLS = ["record_id", "timestamp", "order_id", "customer_id", "product_id"]
NUMERIC_COLS = ["quantity", "unit_price", "discount_rate", "shipping_fee",
                "net_revenue", "delivery_days", "returned_flag", "review_score"]
FLAGS = ["OK", "MISSING", "OUTLIER", "LATE", "DUPLICATE"]
# Quy tac lam sach chung cua nhom: bo OUTLIER/DUPLICATE/LATE, giu MISSING
DROP_FLAGS = {"OUTLIER", "DUPLICATE", "LATE"}


def read_csv(path):
    with open(path, encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def has_bom(path):
    with open(path, "rb") as f:
        return f.read(3) == b"\xef\xbb\xbf"


def to_float(v):
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def infer_type(values):
    """Kieu suy ra tu gia tri khong rong: int, float, datetime, date, string."""
    seen = set()
    for v in values:
        if v in ("", None):
            continue
        if isinstance(v, bool):
            seen.add("bool")
        elif isinstance(v, int):
            seen.add("int")
        elif isinstance(v, float):
            seen.add("float")
        elif isinstance(v, dict):
            seen.add("object")
        else:
            s = str(v)
            try:
                int(s)
                seen.add("int")
                continue
            except ValueError:
                pass
            try:
                float(s)
                seen.add("float")
                continue
            except ValueError:
                pass
            for fmt, name in (("%Y-%m-%dT%H:%M:%S", "datetime"), ("%Y-%m-%d", "date")):
                try:
                    datetime.strptime(s, fmt)
                    seen.add(name)
                    break
                except ValueError:
                    continue
            else:
                seen.add("string")
    if seen == {"int", "float"}:
        return "float"
    return "/".join(sorted(seen)) or "empty"


def column_profile(rows, columns):
    out = []
    for c in columns:
        vals = [r.get(c) for r in rows]
        nulls = sum(1 for v in vals if v in ("", None))
        distinct = len(set(json.dumps(v, sort_keys=True) if isinstance(v, dict) else v
                           for v in vals))
        out.append({"column": c, "type": infer_type(vals), "nulls": nulls,
                    "null_pct": round(100.0 * nulls / len(rows), 2), "distinct": distinct})
    return out


def file_info(path, rows, cols):
    size = os.path.getsize(path)
    return {"file": os.path.basename(path), "bytes": size, "rows": rows, "columns": cols,
            "bytes_per_row": round(size / rows, 1) if rows else None}


def pct(a, b):
    return round(100.0 * a / b, 2) if b else 0.0


def volume(data_dir, orders, customers, products, events, sqlite_counts):
    files = [
        file_info(os.path.join(data_dir, "orders.csv"), len(orders), len(orders[0])),
        file_info(os.path.join(data_dir, "customers.csv"), len(customers), len(customers[0])),
        file_info(os.path.join(data_dir, "products.csv"), len(products), len(products[0])),
        file_info(os.path.join(data_dir, "events_stream.jsonl"), len(events), None),
        file_info(os.path.join(data_dir, "project_data.sqlite"),
                  sum(sqlite_counts.values()), None),
        file_info(os.path.join(data_dir, "data_dictionary.csv"),
                  len(read_csv(os.path.join(data_dir, "data_dictionary.csv"))), 6),
    ]
    total = sum(f["bytes"] for f in files)
    ts = sorted(datetime.fromisoformat(r["timestamp"]) for r in orders)
    days = (ts[-1].date() - ts[0].date()).days + 1
    order_bytes = files[0]["bytes"]
    event_bytes = files[3]["bytes"]
    per_day = len(orders) / days
    return {
        "files": files,
        "total_bytes": total,
        "sqlite_tables": sqlite_counts,
        "span_first": ts[0].isoformat(),
        "span_last": ts[-1].isoformat(),
        "span_days": days,
        "orders_per_day": round(per_day, 2),
        "order_bytes_per_day": round(order_bytes / days, 1),
        "event_bytes_per_record": round(event_bytes / len(events), 1),
        # Dung luong tren HDFS khi replication = 3 (khong tinh metadata NameNode)
        "hdfs_bytes_rep3": total * 3,
    }


def velocity(orders, events):
    ts = [datetime.fromisoformat(r["timestamp"]) for r in orders]
    by_month = collections.Counter(t.strftime("%Y-%m") for t in ts)
    by_day = collections.Counter(t.date().isoformat() for t in ts)
    by_hour = collections.Counter(t.hour for t in ts)
    by_ihour = collections.Counter(t.strftime("%Y-%m-%dT%H") for t in ts)
    peak_day, peak_day_n = by_day.most_common(1)[0]
    peak_hour, peak_hour_n = by_hour.most_common(1)[0]

    ev_ts = [datetime.fromisoformat(e["event_time"]) for e in events]
    inversions = sum(1 for a, b in zip(ev_ts, ev_ts[1:]) if b < a)
    ev_sorted = sorted(ev_ts)
    ev_span_days = (ev_sorted[-1].date() - ev_sorted[0].date()).days + 1
    # Do lech thu tu: vi tri dung (theo thoi gian) cach vi tri den bao nhieu ban ghi
    order_index = {t_i: rank for rank, t_i in enumerate(
        sorted(range(len(ev_ts)), key=lambda i: ev_ts[i]))}
    displacement = [abs(i - order_index[i]) for i in range(len(ev_ts))]

    ingest = collections.Counter(r["ingest_mode"] for r in orders)
    ingest_by_source = collections.Counter((r["source_system"], r["ingest_mode"]) for r in orders)
    return {
        "orders_by_month": dict(sorted(by_month.items())),
        "orders_per_day_mean": round(statistics.mean(by_day.values()), 2),
        "orders_per_day_max": peak_day_n,
        "peak_day": peak_day,
        "active_days": len(by_day),
        "orders_by_hour_of_day": {h: by_hour[h] for h in range(24)},
        "peak_hour_of_day": peak_hour,
        "peak_hour_of_day_n": peak_hour_n,
        "max_orders_in_one_clock_hour": max(by_ihour.values()),
        "ingest_mode": dict(ingest),
        "ingest_mode_by_source": {f"{s}/{m}": n for (s, m), n in sorted(ingest_by_source.items())},
        "events": len(events),
        "events_span_days": ev_span_days,
        "events_out_of_order_pairs": inversions,
        "events_out_of_order_pct": pct(inversions, len(ev_ts) - 1),
        "events_displacement_median": statistics.median(displacement),
        "events_displacement_max": max(displacement),
    }


def variety(orders, customers, products, events, data_dir):
    payload_keys = collections.Counter(k for e in events for k in e["payload"])
    top_keys = collections.Counter(k for e in events for k in e)
    flat_events = [dict({k: v for k, v in e.items() if k != "payload"},
                        **{"payload." + k: v for k, v in e["payload"].items()}) for e in events]
    ev_cols = list(flat_events[0].keys())
    return {
        "encodings": {
            f: ("UTF-8 BOM" if has_bom(os.path.join(data_dir, f)) else "UTF-8")
            for f in ["orders.csv", "customers.csv", "products.csv",
                      "events_stream.jsonl", "data_dictionary.csv"]
        },
        "data_format_label": dict(collections.Counter(r["data_format"] for r in orders)),
        "source_system": dict(collections.Counter(r["source_system"] for r in orders)),
        "ingest_x_format": {f"{m}/{d}": n for (m, d), n in sorted(collections.Counter(
            (r["ingest_mode"], r["data_format"]) for r in orders).items())},
        "event_top_level_keys": dict(top_keys),
        "event_payload_keys": dict(payload_keys),
        "event_types": dict(collections.Counter(e["event_type"] for e in events)),
        "event_sources": dict(collections.Counter(e["source"] for e in events)),
        "columns": {
            "orders.csv": column_profile(orders, list(orders[0].keys())),
            "customers.csv": column_profile(customers, list(customers[0].keys())),
            "products.csv": column_profile(products, list(products[0].keys())),
            "events_stream.jsonl": column_profile(flat_events, ev_cols),
        },
    }


def veracity(orders, customers, products, events, sqlite_path):
    n = len(orders)
    flags = collections.Counter(r["quality_flag"] for r in orders)
    nulls_by_flag = {}
    for col in ("review_score", "campaign_id"):
        nulls_by_flag[col] = {f: sum(1 for r in orders if r["quality_flag"] == f and r[col] == "")
                              for f in FLAGS}

    # net_revenue = quantity * unit_price * (1 - discount_rate) + shipping_fee
    formula_fail = collections.Counter()
    for r in orders:
        q, p, d, s, rev = (to_float(r[c]) for c in
                           ("quantity", "unit_price", "discount_rate", "shipping_fee", "net_revenue"))
        if abs(q * p * (1 - d) + s - rev) > 0.05:
            formula_fail[r["quality_flag"]] += 1

    frac_delivery = collections.Counter(
        r["quality_flag"] for r in orders if not float(r["delivery_days"]).is_integer())
    delivery = [float(r["delivery_days"]) for r in orders]

    # Gia tri am / ngoai mien hop le
    invalid = {
        "quantity<=0": sum(1 for r in orders if to_float(r["quantity"]) <= 0),
        "unit_price<=0": sum(1 for r in orders if to_float(r["unit_price"]) <= 0),
        "discount_rate_not_in_[0,1)": sum(1 for r in orders
                                          if not 0 <= to_float(r["discount_rate"]) < 1),
        "delivery_days<0": sum(1 for d in delivery if d < 0),
        "review_score_not_in_[1,5]": sum(1 for r in orders if r["review_score"] != ""
                                         and not 1 <= to_float(r["review_score"]) <= 5),
        "returned_flag_not_0_1": sum(1 for r in orders if r["returned_flag"] not in ("0", "1")),
    }

    # Ban ghi DUPLICATE co thuc su trung noi dung voi ban ghi khac khong?
    content_cols = [c for c in orders[0] if c not in ("record_id", "order_id", "quality_flag")]
    sig = collections.Counter(tuple(r[c] for c in content_cols) for r in orders)
    dup_content = sum(1 for r in orders if r["quality_flag"] == "DUPLICATE"
                      and sig[tuple(r[c] for c in content_cols)] > 1)

    cust = {c["customer_id"]: c for c in customers}
    prod = {p["product_id"]: p for p in products}
    integrity = {
        "duplicate_record_id": n - len({r["record_id"] for r in orders}),
        "duplicate_order_id": n - len({r["order_id"] for r in orders}),
        "record_id_ne_order_id": sum(1 for r in orders if r["record_id"] != r["order_id"]),
        "orphan_customer_id": sum(1 for r in orders if r["customer_id"] not in cust),
        "orphan_product_id": sum(1 for r in orders if r["product_id"] not in prod),
        "category_ne_product_master": sum(1 for r in orders if r["product_id"] in prod
                                          and r["category"] != prod[r["product_id"]]["category"]),
        "segment_ne_customer_master": sum(1 for r in orders if r["customer_id"] in cust
                                          and r["customer_segment"]
                                          != cust[r["customer_id"]]["customer_segment"]),
        "province_ne_customer_home": sum(1 for r in orders if r["customer_id"] in cust
                                         and r["province"] != cust[r["customer_id"]]["province"]),
        "inactive_product_orders": sum(1 for r in orders if r["product_id"] in prod
                                       and prod[r["product_id"]]["active_flag"] == "0"),
        "duplicate_content_among_DUPLICATE": dup_content,
        "products_list_price_lt_unit_cost": sum(1 for p in products
                                                if float(p["list_price"]) < float(p["unit_cost"])),
    }
    margin = [float(p["list_price"]) / float(p["unit_cost"]) for p in products]
    integrity["products_list_over_cost_min"] = round(min(margin), 3)
    integrity["products_list_over_cost_max"] = round(max(margin), 3)

    # Su kien JSON so voi don hang goc
    by_order = {r["order_id"]: r for r in orders}
    ev_check = collections.Counter()
    for e in events:
        oid = e["event_id"].replace("EVT-", "", 1)
        r = by_order.get(oid)
        if r is None:
            ev_check["no_matching_order"] += 1
            continue
        p = e["payload"]
        if e["event_time"] != r["timestamp"]:
            ev_check["event_time_ne_order"] += 1
        if e["source"] != r["source_system"]:
            ev_check["source_ne_order"] += 1
        if p.get("category") != r["category"]:
            ev_check["category_ne_order"] += 1
        if p.get("customer_segment") != r["customer_segment"]:
            ev_check["segment_ne_order"] += 1
        if abs(float(p.get("net_revenue", 0)) - float(r["net_revenue"])) > 0.005:
            ev_check["net_revenue_ne_order"] += 1
        if int(p.get("returned_flag", -1)) != int(r["returned_flag"]):
            ev_check["returned_flag_ne_order"] += 1
    ev_ids = sorted(e["event_id"].replace("EVT-", "", 1) for e in events)

    # SQLite fact_main co phai ban sao cua orders.csv?
    con = sqlite3.connect("file:%s?mode=ro" % sqlite_path, uri=True)
    try:
        cur = con.execute("SELECT * FROM fact_main")
        cols = [d[0] for d in cur.description]
        sq = {row[cols.index("record_id")]: dict(zip(cols, row)) for row in cur}
    finally:
        con.close()
    sq_diff = 0
    for r in orders:
        s = sq.get(r["record_id"])
        if s is None:
            sq_diff += 1
            continue
        for c in cols:
            a, b = r[c], s[c]
            if b is None:
                b = ""
            fa, fb = to_float(a), to_float(b)
            if (fa is not None and fb is not None and abs(fa - fb) > 1e-6) or \
               ((fa is None or fb is None) and str(a) != str(b)):
                sq_diff += 1
                break

    clean = [r for r in orders if r["quality_flag"] not in DROP_FLAGS]
    return {
        "quality_flag": {f: flags.get(f, 0) for f in FLAGS},
        "quality_flag_pct": {f: pct(flags.get(f, 0), n) for f in FLAGS},
        "nulls_by_flag": nulls_by_flag,
        "net_revenue_formula_fail_by_flag": {f: formula_fail.get(f, 0) for f in FLAGS},
        "fractional_delivery_days_by_flag": {f: frac_delivery.get(f, 0) for f in FLAGS},
        "delivery_days_max_by_flag": {f: max(float(r["delivery_days"]) for r in orders
                                             if r["quality_flag"] == f) for f in FLAGS},
        "invalid_domain": invalid,
        "integrity": integrity,
        "events_vs_orders": dict(ev_check),
        "events_cover_orders": f"{ev_ids[0]}..{ev_ids[-1]}",
        "sqlite_fact_main_rows": len(sq),
        "sqlite_rows_differing_from_csv": sq_diff,
        "rows_after_cleaning_rule": len(clean),
        "rows_dropped_by_cleaning_rule": n - len(clean),
    }


def value(orders):
    clean = [r for r in orders if r["quality_flag"] not in DROP_FLAGS]
    rev = [float(r["net_revenue"]) for r in clean]
    ret = [r for r in clean if r["returned_flag"] == "1"]
    dd = [float(r["delivery_days"]) for r in clean]
    by_cat = collections.defaultdict(lambda: [0.0, 0, 0, 0.0])
    for r in clean:
        a = by_cat[r["category"]]
        a[0] += float(r["net_revenue"])
        a[1] += 1
        a[2] += int(r["returned_flag"])
        a[3] += float(r["delivery_days"])
    # Ty le tra hang theo so ngay giao (de xem giao cham co lam tang tra hang khong)
    ret_by_dd = collections.defaultdict(lambda: [0, 0])
    for r in clean:
        k = min(int(float(r["delivery_days"])), 7)
        ret_by_dd[k][0] += 1
        ret_by_dd[k][1] += int(r["returned_flag"])
    return {
        "clean_orders": len(clean),
        "net_revenue_total": round(sum(rev), 2),
        "net_revenue_mean": round(statistics.mean(rev), 2),
        "returned_orders": len(ret),
        "return_rate_pct": pct(len(ret), len(clean)),
        "revenue_of_returned_orders": round(sum(float(r["net_revenue"]) for r in ret), 2),
        "delivery_days_mean": round(statistics.mean(dd), 2),
        "delivery_days_p90": sorted(dd)[int(0.9 * (len(dd) - 1))],
        "share_delivery_gt_5_days_pct": pct(sum(1 for d in dd if d > 5), len(dd)),
        "by_category": {c: {"orders": a[1], "revenue": round(a[0], 2),
                            "return_rate_pct": pct(a[2], a[1]),
                            "delivery_days_mean": round(a[3] / a[1], 2)}
                        for c, a in sorted(by_cat.items(), key=lambda kv: -kv[1][0])},
        "return_rate_by_delivery_days": {
            ("7+" if k == 7 else str(k)): {"orders": v[0], "return_rate_pct": pct(v[1], v[0])}
            for k, v in sorted(ret_by_dd.items())},
    }


def md_table(headers, rows):
    lines = ["| " + " | ".join(headers) + " |",
             "|" + "|".join("---" for _ in headers) + "|"]
    for r in rows:
        lines.append("| " + " | ".join(vn(x) for x in r) + " |")
    return "\n".join(lines)


def vn(x):
    """So kieu Viet Nam: 78.218.341,22; chuoi giu nguyen."""
    if isinstance(x, bool) or not isinstance(x, (int, float)):
        return str(x)
    s = f"{x:,}" if isinstance(x, int) else f"{x:,.2f}".rstrip("0").rstrip(".")
    return s.replace(",", " ").replace(".", ",").replace(" ", ".")


def to_markdown(p):
    v, ve, va, vr, vl = p["volume"], p["velocity"], p["variety"], p["veracity"], p["value"]
    out = ["# Câu 1 – Số liệu profiling (sinh tự động bởi `profile_data.py`)", ""]

    out += ["## Volume", "", md_table(
        ["Tệp", "Byte", "Bản ghi", "Cột", "Byte/bản ghi"],
        [[f["file"], vn(f["bytes"]), vn(f["rows"]), f["columns"] or "–",
          f["bytes_per_row"]] for f in v["files"]]), ""]
    out += [f"- Tổng: **{vn(v['total_bytes'])} byte**; trên HDFS replication 3: "
            f"**{vn(v['hdfs_bytes_rep3'])} byte**.",
            f"- SQLite: " + ", ".join(f"`{t}` {vn(c)} dòng"
                                       for t, c in v["sqlite_tables"].items()) + ".",
            f"- Khoảng thời gian đơn hàng: {vn(v['span_first'])} → {vn(v['span_last'])} "
            f"({vn(v['span_days'])} ngày), trung bình **{vn(v['orders_per_day'])} đơn/ngày**, "
            f"≈ {vn(int(v['order_bytes_per_day']))} byte CSV/ngày.", ""]

    out += ["## Velocity", "", md_table(["Tháng", "Đơn"], list(ve["orders_by_month"].items())), ""]
    out += [f"- Đơn/ngày: trung bình {vn(ve['orders_per_day_mean'])}, cao nhất "
            f"{vn(ve['orders_per_day_max'])} (ngày {vn(ve['peak_day'])}); "
            f"tối đa {vn(ve['max_orders_in_one_clock_hour'])} đơn trong một giờ.",
            f"- Giờ cao điểm trong ngày: {vn(ve['peak_hour_of_day'])}h "
            f"({vn(ve['peak_hour_of_day_n'])} đơn cộng dồn).",
            f"- `ingest_mode`: " + ", ".join(f"{k} {vn(c)}"
                                            for k, c in ve["ingest_mode"].items()) + ".",
            f"- `events_stream.jsonl`: {vn(ve['events'])} sự kiện trải {vn(ve['events_span_days'])} ngày; "
            f"**{vn(ve['events_out_of_order_pct'])}%** cặp liên tiếp bị ngược thời gian; "
            f"độ lệch vị trí trung vị {vn(ve['events_displacement_median'])}, "
            f"tối đa {vn(ve['events_displacement_max'])} bản ghi.", ""]

    out += ["## Variety", "",
            f"- Mã hóa: " + ", ".join(f"`{k}` {e}" for k, e in va["encodings"].items()) + ".",
            f"- Nhãn `data_format`: " + ", ".join(f"{k} {vn(c)}"
                                                 for k, c in va["data_format_label"].items()) + ".",
            f"- `source_system`: " + ", ".join(f"{k} {vn(c)}"
                                              for k, c in va["source_system"].items()) + ".",
            f"- Khóa JSON cấp 1: {', '.join(va['event_top_level_keys'])}; "
            f"`payload`: {', '.join(va['event_payload_keys'])}.", ""]
    for name, cols in va["columns"].items():
        out += [f"### `{name}`", "", md_table(
            ["Cột", "Kiểu suy ra", "Null", "% null", "Giá trị khác nhau"],
            [[c["column"], c["type"], c["nulls"], c["null_pct"], vn(c["distinct"])]
             for c in cols]), ""]

    out += ["## Veracity", "", md_table(
        ["quality_flag", "Bản ghi", "%", "Sai công thức net_revenue", "delivery_days lẻ",
         "delivery_days max", "review_score null", "campaign_id null"],
        [[f, vr["quality_flag"][f], vr["quality_flag_pct"][f],
          vr["net_revenue_formula_fail_by_flag"][f], vr["fractional_delivery_days_by_flag"][f],
          vr["delivery_days_max_by_flag"][f], vr["nulls_by_flag"]["review_score"][f],
          vr["nulls_by_flag"]["campaign_id"][f]] for f in FLAGS]), ""]
    out += ["- Miền giá trị: " + ", ".join(f"`{k}` {vn(c)}" for k, c in vr["invalid_domain"].items()) + ".",
            "- Toàn vẹn: " + ", ".join(f"`{k}` {vn(c)}" for k, c in vr["integrity"].items()) + ".",
            f"- Sự kiện so với đơn gốc ({vn(vr['events_cover_orders'])}): "
            + (", ".join(f"`{k}` {vn(c)}" for k, c in vr["events_vs_orders"].items()) or "khớp 100%")
            + ".",
            f"- SQLite `fact_main`: {vn(vr['sqlite_fact_main_rows'])} dòng, "
            f"{vn(vr['sqlite_rows_differing_from_csv'])} dòng khác `orders.csv`.",
            f"- Quy tắc làm sạch chung (bỏ OUTLIER/DUPLICATE/LATE): còn "
            f"**{vn(vr['rows_after_cleaning_rule'])}** đơn, bỏ "
            f"{vn(vr['rows_dropped_by_cleaning_rule'])}.", ""]

    out += ["## Value (trên dữ liệu đã làm sạch)", "",
            f"- Doanh thu ròng: **{vn(vl['net_revenue_total'])}**, trung bình "
            f"{vn(vl['net_revenue_mean'])}/đơn.",
            f"- Trả hàng: {vn(vl['returned_orders'])} đơn (**{vn(vl['return_rate_pct'])}%**), "
            f"doanh thu bị trả: {vn(vl['revenue_of_returned_orders'])}.",
            f"- Giao hàng: trung bình {vn(vl['delivery_days_mean'])} ngày, P90 = "
            f"{vn(vl['delivery_days_p90'])} ngày; {vn(vl['share_delivery_gt_5_days_pct'])}% đơn > 5 ngày.",
            "", md_table(["Danh mục", "Đơn", "Doanh thu", "% trả", "Ngày giao TB"],
                         [[c, d["orders"], d["revenue"], d["return_rate_pct"],
                           d["delivery_days_mean"]] for c, d in vl["by_category"].items()]),
            "", md_table(["Ngày giao", "Đơn", "% trả"],
                         [[k, d["orders"], d["return_rate_pct"]]
                          for k, d in vl["return_rate_by_delivery_days"].items()]), ""]
    return "\n".join(out)


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--data", default="/data", help="thu muc du lieu (mac dinh /data)")
    ap.add_argument("--out", default="output", help="thu muc ghi ket qua")
    a = ap.parse_args()

    orders = read_csv(os.path.join(a.data, "orders.csv"))
    customers = read_csv(os.path.join(a.data, "customers.csv"))
    products = read_csv(os.path.join(a.data, "products.csv"))
    with open(os.path.join(a.data, "events_stream.jsonl"), encoding="utf-8") as f:
        events = [json.loads(line) for line in f if line.strip()]
    sqlite_path = os.path.join(a.data, "project_data.sqlite")
    con = sqlite3.connect("file:%s?mode=ro" % sqlite_path, uri=True)
    try:
        tables = [t for (t,) in con.execute(
            "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")]
        sqlite_counts = {t: con.execute(f'SELECT COUNT(*) FROM "{t}"').fetchone()[0]
                         for t in tables}
    finally:
        con.close()

    profile = {
        "volume": volume(a.data, orders, customers, products, events, sqlite_counts),
        "velocity": velocity(orders, events),
        "variety": variety(orders, customers, products, events, a.data),
        "veracity": veracity(orders, customers, products, events, sqlite_path),
        "value": value(orders),
    }

    os.makedirs(a.out, exist_ok=True)
    with open(os.path.join(a.out, "profile.json"), "w", encoding="utf-8") as f:
        json.dump(profile, f, ensure_ascii=False, indent=2)
    with open(os.path.join(a.out, "profile.md"), "w", encoding="utf-8") as f:
        f.write(to_markdown(profile))
    print(f"Da ghi {a.out}/profile.json va {a.out}/profile.md")


if __name__ == "__main__":
    main()
