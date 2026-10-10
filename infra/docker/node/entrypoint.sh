#!/bin/bash
# Entrypoint chung cho ca 4 may. Vai tro duoc quyet dinh boi bien NODE_ROLE.
set -e

: "${NODE_ROLE:=worker}"

# --- Don trang thai sot lai tu lan chay truoc ------------------------------
#  Khi may tat, cac tien trinh Hadoop/HBase bi dung dot ngot nen con sot file
#  .pid va hsperfdata cua Java trong /tmp. Luc bat lai, so pid dem lai tu dau
#  nen rat de trung voi so cu -> daemon tuong "dang chay" va bo qua khong khoi
#  dong. Luc container vua bat chua co daemon nao chay, nen xoa het cho sach.
rm -f /tmp/*.pid
rm -rf /tmp/hsperfdata_*

# Volume moi tao co the thuoc root -> tra lai cho user hadoop
chown -R hadoop:hadoop /home/hadoop/hdfs 2>/dev/null || true

# --- Khoa SSH: gan tu ./ssh-key cua may that vao /ssh-key (chi doc) ----------
#  Anh khong chua khoa nao. Ca 4 may phai dung CHUNG mot cap khoa thi
#  start-dfs.sh / start-hbase.sh moi ssh sang nhau duoc -> khong tu sinh rieng.
K=/ssh-key
for f in id_ed25519 id_ed25519.pub ssh_host_ed25519_key ssh_host_ed25519_key.pub; do
  if [ ! -s "$K/$f" ]; then
    echo "!!! [$(hostname)] Thieu $K/$f - hay chay scripts/setup.ps1 (Windows) hoac scripts/setup.sh truoc khi 'docker compose up'." >&2
    exit 1
  fi
done
# File gan tu Windows co the mang CRLF va quyen 777 -> sshd tu choi; cai lai cho dung
tr -d '\r' < $K/ssh_host_ed25519_key     > /etc/ssh/ssh_host_ed25519_key
tr -d '\r' < $K/ssh_host_ed25519_key.pub > /etc/ssh/ssh_host_ed25519_key.pub
chmod 600 /etc/ssh/ssh_host_ed25519_key; chmod 644 /etc/ssh/ssh_host_ed25519_key.pub
H=/home/hadoop/.ssh
tr -d '\r' < $K/id_ed25519     > $H/id_ed25519
tr -d '\r' < $K/id_ed25519.pub > $H/id_ed25519.pub
cp $H/id_ed25519.pub $H/authorized_keys
chown hadoop:hadoop $H/id_ed25519 $H/id_ed25519.pub $H/authorized_keys
chmod 600 $H/id_ed25519 $H/authorized_keys; chmod 644 $H/id_ed25519.pub

# --- sshd (Hadoop/HBase dung ssh de khoi dong tien trinh tren may khac) -----
mkdir -p /var/run/sshd
/usr/sbin/sshd

echo "==> [$(hostname)] role=${NODE_ROLE} - sshd da khoi dong"

# --- Tat gon gang khi container bi dung --------------------------------------
#  "docker compose stop" / tat Docker Desktop gui SIGTERM. Neu de Docker giet
#  thang, HBase de bi hong procedure store (HMaster ket "Master is initializing").
#  -> masternode tat ca cum (HBase -> Yarn -> HDFS) truoc khi thoat; datanode
#  tat cac daemon cuc bo (khong lam gi neu masternode da tat roi).
tat_gon() {
  echo "==> [$(hostname)] nhan SIGTERM - tat cac dich vu..."
  if [ "$NODE_ROLE" = master ]; then
    su - hadoop -c /home/hadoop/scripts/stop-cluster.sh || true
  else
    su - hadoop -c '
      . /etc/profile.d/btl-env.sh
      jps | grep -qw HRegionServer && hbase-daemon.sh stop regionserver
      jps | grep -qw NodeManager   && yarn --daemon stop nodemanager
      jps | grep -qw DataNode      && hdfs --daemon stop datanode
      true' || true
  fi
  kill "$CHILD" 2>/dev/null
  exit 0
}
trap tat_gon TERM INT

"$@" &
CHILD=$!
wait "$CHILD"
