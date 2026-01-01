# ==========================================================
# ZUNRDP CLOUD - FIXED AUTH & FULL TAILSCALE IP
# ==========================================================
Param([string]$OWNER_NAME)

$API = "https://zunrdp-default-rtdb.asia-southeast1.firebasedatabase.app"
$VM_ID = "ZUN-" + (Get-Random -Minimum 1000 -Maximum 9999)
$USER_FIXED = "ZunRdp"
$PASS_FIXED = "ZunRdp@2026@Cloud" 

Write-Host "[*] Dang thiet lap User mac dinh: $USER_FIXED" -ForegroundColor Cyan

# --- 1. TAO USER (DUNG NET USER DE FIX LOI DANG NHAP) ---
# Xóa để làm sạch các bản lỗi cũ
net user $USER_FIXED /delete >$null 2>&1
# Tạo mới và ép mật khẩu chuẩn
net user $USER_FIXED $PASS_FIXED /add /y
net localgroup Administrators $USER_FIXED /add
net localgroup "Remote Desktop Users" $USER_FIXED /add
# Chống mật khẩu hết hạn
wmic useraccount where "Name='$USER_FIXED'" set PasswordExpires=FALSE

# --- 2. LAY CHINH XAC IP TAILSCALE (KHONG DE BI HIEN SO 1) ---
Write-Host "[*] Dang doi Tailscale cap IP 100.x..." -ForegroundColor Yellow
$IP = "Connecting..."
$retry = 0
while ($IP -eq "Connecting..." -and $retry -lt 15) {
    # Ưu tiên lấy IP từ lệnh gốc của Tailscale để chuẩn 100%
    try {
        $rawIP = (& "C:\Program Files\Tailscale\tailscale.exe" ip -4).Trim()
        if ($rawIP -match "100\.") { $IP = $rawIP }
    } catch {
        # Nếu app chưa chạy, thử lấy qua Card mạng
        $TS_IP = Get-NetIPAddress | Where-Object { $_.InterfaceAlias -like "*Tailscale*" -and $_.AddressFamily -eq "IPv4" } | Select-Object -ExpandProperty IPAddress
        if ($TS_IP) { $IP = $TS_IP[0] }
    }
    
    if ($IP -eq "Connecting...") {
        $retry++
        Start-Sleep -Seconds 10
    }
}

# --- 3. GUI DU LIEU VE FIREBASE ---
$data = @{ 
    id=$VM_ID; owner=$OWNER_NAME; ip=$IP; 
    user=$USER_FIXED; pass=$PASS_FIXED; 
    startTime=([DateTimeOffset]::Now.ToUnixTimeMilliseconds()); 
    cpu=0; ram=0 
} | ConvertTo-Json
Invoke-RestMethod -Uri "$API/vms/$VM_ID.json" -Method Put -Body $data

# --- 4. CAI ANH NEN ---
$wallUrl = "https://www.mediafire.com/file/zzyg8r3l4ycagr4/vmcloud.png/file"
$wallPath = "C:\Windows\zun_wallpaper.png"
try {
    Invoke-WebRequest -Uri $wallUrl -OutFile $wallPath
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop\' -Name wallpaper -Value $wallPath
    rundll32.exe user32.dll,UpdatePerUserSystemParameters
} catch {}

# --- 5. VONG LAP TREO MAY ---
while($true) {
    try {
        $cmd = Invoke-RestMethod -Uri "$API/commands/$VM_ID.json"
        if ($cmd.action -eq "stop") {
            Invoke-RestMethod -Uri "$API/vms/$VM_ID.json" -Method Delete
            Invoke-RestMethod -Uri "$API/commands/$VM_ID.json" -Method Delete
            Stop-Computer -Force
            break
        }
        $mem = Get-WmiObject Win32_OperatingSystem
        $cpu = (Get-WmiObject Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
        $ram = [Math]::Round((( $mem.TotalVisibleMemorySize - $mem.FreePhysicalMemory ) / $mem.TotalVisibleMemorySize ) * 100)
        Invoke-RestMethod -Uri "$API/vms/$VM_ID.json" -Method Patch -Body (@{cpu=$cpu; ram=$ram} | ConvertTo-Json)
    } catch {}
    Start-Sleep -Seconds 10
}

