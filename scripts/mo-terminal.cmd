@echo off
rem ===========================================================================
rem  Mo 4 terminal rieng cho 4 may cua cum BTL (giong Lab 05):
rem     tab 1: ssh may1 = masternode   tab 2: ssh may2 = datanode1
rem     tab 3: ssh may3 = datanode2    tab 4: ssh may4 = datanode3
rem  Container dang tat thi tu bat len truoc. Nhap dup file nay la chay.
rem ===========================================================================
rem Script nam trong scripts\ -> ve goc repo (noi co docker-compose.yml)
cd /d "%~dp0.."
echo Bat container (neu dang tat)...
docker compose up -d >nul 2>&1 || (echo Loi: Docker Desktop chua chay? & pause & exit /b 1)
rem Cho sshd trong container san sang
ping -n 3 127.0.0.1 >nul
set SSH=%SystemRoot%\System32\OpenSSH\ssh.exe
start "" wt -w btl ^
  new-tab --title "may1 - masternode" --tabColor "#C0392B" %SSH% may1 ; ^
  new-tab --title "may2 - datanode1"  --tabColor "#27AE60" %SSH% may2 ; ^
  new-tab --title "may3 - datanode2"  --tabColor "#D4AC0D" %SSH% may3 ; ^
  new-tab --title "may4 - datanode3"  --tabColor "#17A589" %SSH% may4 ; ^
  focus-tab -t 0
