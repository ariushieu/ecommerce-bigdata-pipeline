package btl.cau05;

import java.io.DataInput;
import java.io.DataOutput;
import java.io.IOException;

import org.apache.hadoop.io.Writable;

/**
 * Gia tri trung gian (value) cua Mapper va Combiner: 3 tong cong duoc.
 * - orders       : so don
 * - revenueCents : tong net_revenue tinh bang XU (x100, so nguyen) -> cong chinh xac,
 *                  khong sai so dau phay dong, ket qua khong phu thuoc thu tu cong
 * - returned     : so don bi tra (returned_flag = 1)
 * Ca 3 deu la phep cong (giao hoan + ket hop) nen Combiner cong tung phan duoc.
 * Ty le tra hang KHONG luu o day: chi Reducer moi chia, tranh "trung binh cua trung binh".
 */
public class OrderStats implements Writable {
    private long orders;
    private long revenueCents;
    private long returned;

    public OrderStats() { }

    public OrderStats(long orders, long revenueCents, long returned) {
        set(orders, revenueCents, returned);
    }

    public void set(long o, long cents, long r) {
        this.orders = o;
        this.revenueCents = cents;
        this.returned = r;
    }

    public void add(OrderStats other) {
        this.orders += other.orders;
        this.revenueCents += other.revenueCents;
        this.returned += other.returned;
    }

    public long getOrders() { return orders; }
    public long getRevenueCents() { return revenueCents; }
    public long getReturned() { return returned; }

    @Override
    public void write(DataOutput out) throws IOException {
        // 3 x 8 byte co dinh; VLong se nho hon nhung giu don gian, de doc
        out.writeLong(orders);
        out.writeLong(revenueCents);
        out.writeLong(returned);
    }

    @Override
    public void readFields(DataInput in) throws IOException {
        orders = in.readLong();
        revenueCents = in.readLong();
        returned = in.readLong();
    }

    @Override
    public String toString() {
        return orders + "\t" + revenueCents + "\t" + returned;
    }
}
