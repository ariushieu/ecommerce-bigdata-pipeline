# shellcheck shell=bash
# Dau nhac co mau theo tung may, vd:  hadoop@masternode(may1):~/src$
# Nap tu ~/.bashrc (sau phan PS1 mac dinh cua Ubuntu nen khong bi ghi de).
case "$(hostname)" in
  masternode) _may=may1; _mau=31 ;;
  datanode1)  _may=may2; _mau=32 ;;
  datanode2)  _may=may3; _mau=33 ;;
  datanode3)  _may=may4; _mau=36 ;;
  *)          _may='?';    _mau=37 ;;
esac
PS1="\[\e]0;\h ($_may)\a\]\[\e[1;${_mau}m\]\u@\h($_may)\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ "
unset _may _mau
