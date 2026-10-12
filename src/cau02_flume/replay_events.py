#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Cau 2 - Phat lai events_stream.jsonl vao Flume HTTP source (JSONHandler).

Mo phong luong order_event: gui theo lo (batch) voi toc do co dinh (event/giay).
Moi lo la MOT request POST, than la mang JSON:
    [{"headers": {"event_id": "..."}, "body": "<nguyen van 1 dong JSON>"}, ...]
Flume tra 200 khi lo da vao DU cac channel; tra 503 (channel day/loi) thi
script cho roi gui lai CA LO -> at-least-once (co the trung, khong mat).

Chi dung thu vien chuan Python 3.8.

Vi du (trong masternode):
    python3 replay_events.py --rate 250 --batch 50
    python3 replay_events.py --limit 1000 --rate 0          # gui nhanh nhat
    python3 replay_events.py --url http://localhost:41414 --file /data/events_stream.jsonl
Tu Windows (cong 41414 da mo ra may that) cung chay duoc neu co Python 3.
"""
import argparse
import json
import sys
import time
import urllib.error
import urllib.request


def doc_su_kien(path, offset, limit):
    """Doc cac dong JSON (bo dong rong), tra ve list (event_id, dong goc)."""
    out = []
    with open(path, encoding="utf-8") as f:
        for i, line in enumerate(f):
            if i < offset:
                continue
            line = line.rstrip("\r\n")
            if not line.strip():
                continue
            try:
                eid = json.loads(line).get("event_id", "")
            except ValueError:
                eid = ""          # dong hong van gui nguyen van, HDFS raw giu lai
            out.append((eid, line))
            if limit and len(out) >= limit:
                break
    return out


def gui_lo(url, lo, timeout):
    """POST mot lo; tra ve ma HTTP (200 = thanh cong)."""
    data = json.dumps(
        [{"headers": {"event_id": eid}, "body": body} for eid, body in lo],
        ensure_ascii=False,
    ).encode("utf-8")
    req = urllib.request.Request(
        url, data=data, method="POST",
        headers={"Content-Type": "application/json; charset=UTF-8"},
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.status


def main():
    ap = argparse.ArgumentParser(description="Phat lai order_event vao Flume HTTP source")
    ap.add_argument("--url", default="http://localhost:41414")
    ap.add_argument("--file", default="/data/events_stream.jsonl")
    ap.add_argument("--batch", type=int, default=50, help="so event moi POST")
    ap.add_argument("--rate", type=float, default=250.0,
                    help="event/giay muc tieu; 0 = nhanh nhat co the")
    ap.add_argument("--offset", type=int, default=0, help="bo qua N dong dau")
    ap.add_argument("--limit", type=int, default=0, help="chi gui N event (0 = het)")
    ap.add_argument("--retries", type=int, default=10, help="so lan gui lai toi da moi lo")
    ap.add_argument("--timeout", type=float, default=30.0)
    ap.add_argument("--summary", help="ghi tom tat JSON ra tep nay")
    a = ap.parse_args()

    events = doc_su_kien(a.file, a.offset, a.limit)
    if not events:
        print("Khong co event nao de gui", file=sys.stderr)
        return 1

    sent, batches, retries = 0, 0, 0
    t0 = time.monotonic()
    for i in range(0, len(events), a.batch):
        lo = events[i:i + a.batch]
        # giu nhip: lo thu k duoc gui khong som hon t0 + (so event da gui)/rate
        if a.rate > 0:
            cho = t0 + sent / a.rate - time.monotonic()
            if cho > 0:
                time.sleep(cho)
        lan = 0
        while True:
            try:
                code = gui_lo(a.url, lo, a.timeout)
                if code == 200:
                    break
                loi = "HTTP %d" % code
            except urllib.error.HTTPError as e:      # 503: channel day / loi put
                loi = "HTTP %d" % e.code
            except (urllib.error.URLError, OSError) as e:   # agent chua len / mat ket noi
                loi = str(e)
            lan += 1
            retries += 1
            if lan > a.retries:
                print("FAIL: lo %d bi tu choi %d lan (%s)" % (batches, lan, loi), file=sys.stderr)
                return 2
            time.sleep(min(0.2 * 2 ** lan, 5.0))    # backoff luy thua
        sent += len(lo)
        batches += 1

    elapsed = time.monotonic() - t0
    tom_tat = {
        "events": sent,
        "batches": batches,
        "batch_size": a.batch,
        "target_rate": a.rate,
        "retries": retries,
        "elapsed_s": round(elapsed, 3),
        "throughput_eps": round(sent / elapsed, 1) if elapsed > 0 else None,
    }
    print("REPLAY " + " ".join("%s=%s" % kv for kv in tom_tat.items()))
    if a.summary:
        with open(a.summary, "w", encoding="utf-8") as f:
            json.dump(tom_tat, f, indent=2)
            f.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
