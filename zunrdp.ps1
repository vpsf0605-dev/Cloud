# ==========================================================
# ZUNRDP CLOUD - TAILSCALE OPTIMIZED (FIX LOGIN)
# ==========================================================
Param([string]$OWNER_NAME)

$API = "https://zunrdp-default-rtdb.asia-southeast1.firebasedatabase.app"
$VM_ID = "ZUN-" + (Get-Random -Minimum 1000 -Maximum 9999)
$Username = "ZunRdp"
$Password = "ZunRdp@2026@Cloud"

Write-Host "[*] Dang thiet lap he thong ZunRdp..." -ForegroundColor Cyan

# --- 1. ÉP TẠO USER (FIX TRIỆT ĐỂ LỖI LOGIN) ---
try {
    $comp = [ADSI]"WinNT://$env:COMPUTERNAME"
    try { $comp.Delete("user", $Username) } catch {} # Xóa cũ nếu có
    $user = $comp.Create("user", $Username)
    $user.SetPassword($Password)
    $user.SetInfo()
    $groups = @("Administrators", "Remote Desktop Users")
    foreach ($g in $groups) {
        $group = [ADSI]"WinNT://$env:COMPUTERNAME/$g,group"
        $group.Add("WinNT://$Username")
    }
    $user.UserFlags = 65536 # Password never expires
    $user.SetInfo()
} catch {
    net user $Username $Password /add /y
    net localgroup Administrators $Username /add
    net localgroup "Remote Desktop Users" $Username /add
}

# --- 2. CẤU HÌNH RDP BỎ QUA XÁC THỰC PHỨC TẠP ---
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 0

# --- 3. LẤY CHÍNH XÁC IP TAILSCALE ---
$IP = "Connecting..."
for ($i=0; $i -lt 20; $i++) {
    $check = (& "C:\Program Files\Tailscale\tailscale.exe" ip -4)
    if ($check -match "100\.") { $IP = $check.Trim(); break }
    Start-Sleep -Seconds 10
}

# --- 4. CẬP NHẬT FIREBASE ---
$data = @{ id=$VM_ID; owner=$OWNER_NAME; ip=$IP; user=$Username; pass=$Password; startTime=([DateTimeOffset]::Now.ToUnixTimeMilliseconds()) } | ConvertTo-Json
Invoke-RestMethod -Uri "$API/vms/$VM_ID.json" -Method Put -Body $data

# --- 5. DUY TRÌ MÁY ẢO ---
while($true) {
    try {
        $cmd = Invoke-RestMethod -Uri "$API/commands/$VM_ID.json"
        if ($cmd.action -eq "stop") {
            Invoke-RestMethod -Uri "$API/vms/$VM_ID.json" -Method Delete
            Stop-Computer -Force; break
        }
    } catch {}
    Start-Sleep -Seconds 15
}

