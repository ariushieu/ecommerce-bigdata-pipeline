# =============================================================================
#  Cai dat MOT LAN cho moi thanh vien (Windows). Chay trong PowerShell:
#      cd <thu muc repo>
#      powershell -ExecutionPolicy Bypass -File .\setup.ps1
#
#  Viec lam (chay lai nhieu lan cung an toan):
#   1. Kiem tra Docker Desktop
#   2. Sinh khoa SSH rieng cua may ban vao ssh-key\ (khong dua len Git)
#   3. Them "ssh may1".."ssh may4" vao %USERPROFILE%\.ssh\config
# =============================================================================
$ErrorActionPreference = 'Stop'
$PSNativeCommandArgumentPassing = 'Legacy'   # PowerShell 7: de -N '""' van la mat khau rong

$root   = $PSScriptRoot
$keyDir = Join-Path $root 'ssh-key'
$userKey = Join-Path $keyDir 'id_ed25519'
$hostKey = Join-Path $keyDir 'ssh_host_ed25519_key'
$sshDir  = Join-Path $env:USERPROFILE '.ssh'
$sshCfg  = Join-Path $sshDir 'config'
$keygen  = Join-Path $env:SystemRoot 'System32\OpenSSH\ssh-keygen.exe'

function Buoc($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }

# --- 1. Docker ---------------------------------------------------------------
Buoc 'Kiem tra Docker'
try { docker version --format '{{.Server.Version}}' | Out-Null; Write-Host '    Docker OK' }
catch { Write-Host '    Chua chay duoc Docker. Cai/bat Docker Desktop roi chay lai.' -ForegroundColor Yellow }

# --- 2. Khoa SSH -------------------------------------------------------------
Buoc 'Khoa SSH (ssh-key)'
if (-not (Test-Path $keygen)) { throw "Khong thay $keygen - bat tinh nang 'OpenSSH Client' cua Windows." }
New-Item -ItemType Directory -Force -Path $keyDir | Out-Null
$sinhMoi = $false
if (-not (Test-Path $userKey)) {
    & $keygen -q -t ed25519 -N '""' -C 'btl-hadoop' -f $userKey; $sinhMoi = $true
    Write-Host '    Da sinh khoa dang nhap id_ed25519'
} else { Write-Host '    Da co id_ed25519 - giu nguyen' }
if (-not (Test-Path $hostKey)) {
    & $keygen -q -t ed25519 -N '""' -C 'btl-host' -f $hostKey; $sinhMoi = $true
    Write-Host '    Da sinh host key ssh_host_ed25519_key'
} else { Write-Host '    Da co ssh_host_ed25519_key - giu nguyen' }

# OpenSSH Windows tu choi khoa rieng neu nguoi khac doc duoc
icacls $userKey /inheritance:r /grant:r "$($env:USERNAME):F" | Out-Null

# Khoa moi -> xoa dau van tay cu trong known_hosts (tranh bao "host key changed")
if ($sinhMoi) { & $keygen -R btl-hadoop-cluster 2>$null | Out-Null }

# --- 3. ~/.ssh/config ---------------------------------------------------------
Buoc 'Them may1..may4 vao ~/.ssh/config'
New-Item -ItemType Directory -Force -Path $sshDir | Out-Null
$batDau = '# >>> btl-cluster (sinh boi btl/setup.ps1 - dung sua tay) >>>'
$ketThuc = '# <<< btl-cluster <<<'
$idPath = ($userKey -replace '\\', '/')
$khoi = @"
$batDau
#   ssh may1 = masternode | may2 = datanode1 | may3 = datanode2 | may4 = datanode3
Host may1
    Port 2201
Host may2
    Port 2202
Host may3
    Port 2203
Host may4
    Port 2204
Host may1 may2 may3 may4
    IgnoreUnknown WarnWeakCrypto
    WarnWeakCrypto no
    HostName 127.0.0.1
    User hadoop
    IdentityFile $idPath
    IdentitiesOnly yes
    HostKeyAlias btl-hadoop-cluster
    StrictHostKeyChecking accept-new
    ServerAliveInterval 60
$ketThuc
"@ -replace "`r`n", "`n"

$cu = ''
if (Test-Path $sshCfg) { $cu = [IO.File]::ReadAllText($sshCfg) -replace "`r`n", "`n" }
$mau = '(?s)\n?' + [regex]::Escape($batDau) + '.*?' + [regex]::Escape($ketThuc) + '\n?'
$moi = ([regex]::Replace($cu, $mau, "`n")).TrimEnd() + "`n`n" + $khoi + "`n"
if ($cu -notmatch [regex]::Escape($batDau) -and $cu -match '(?m)^Host .*\bmay1\b') {
    Write-Host '    CANH BAO: config da co "Host may1" ngoai khoi btl-cluster - hay xoa tay khoi cu.' -ForegroundColor Yellow
}
[IO.File]::WriteAllText($sshCfg, $moi.TrimStart("`n"), (New-Object System.Text.UTF8Encoding($false)))
Write-Host "    Da ghi $sshCfg"

Write-Host ''
Write-Host 'XONG. Buoc tiep theo:' -ForegroundColor Green
Write-Host '  docker compose pull          # tai anh dung san tu GHCR (nhanh)'
Write-Host '  docker compose up -d         # bat 5 container'
Write-Host '  .\mo-terminal.cmd            # mo 4 terminal may1..may4'
Write-Host '  (trong may1) start-cluster.sh && smoke-test.sh'
