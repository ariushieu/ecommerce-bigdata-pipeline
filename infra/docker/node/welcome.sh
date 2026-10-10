# shellcheck shell=bash
# Loi chao khi dang nhap (ssh may1..may4): biet ngay dang o may nao, chay gi.
# Nap boi /etc/profile cho moi login shell (dau nhac co mau: xem prompt.sh).
[ -n "$PS1" ] || return 0
[ "$(id -un)" = hadoop ] || return 0

case "$(hostname)" in
  masternode) _may=may1; _mau=31; _vaitro="NameNode, ResourceManager, JobHistory, Spark History, ZooKeeper, HMaster" ;;
  datanode1)  _may=may2; _mau=32; _vaitro="DataNode, NodeManager, HRegionServer" ;;
  datanode2)  _may=may3; _mau=33; _vaitro="DataNode, NodeManager, HRegionServer" ;;
  datanode3)  _may=may4; _mau=36; _vaitro="DataNode, NodeManager, HRegionServer" ;;
  *)          _may='?';    _mau=37; _vaitro="" ;;
esac

echo -e "\e[1;${_mau}m==== $(hostname) ($_may) - $(hostname -i) ====\e[0m"
echo "Vai tro  : $_vaitro"
echo "Dang chay: $($JAVA_HOME/bin/jps 2>/dev/null | awk '$2!="Jps"{print $2}' | sort | tr '\n' ' ')"
[ "$(hostname)" = masternode ] && echo "Lenh     : start-cluster.sh | stop-cluster.sh | status.sh | smoke-test.sh | hbase-reset.sh"
echo
unset _may _mau _vaitro
