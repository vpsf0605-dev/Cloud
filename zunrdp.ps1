# ==========================================================
# ZUNRDP CLOUD - FIX ĐĂNG NHẬP & IP TAILSCALE
# ==========================================================
Param([string]$OWNER_NAME)

$API = "https://zunrdp-default-rtdb.asia-southeast1.firebasedatabase.app"
$VM_ID = "ZUN-" + (Get-Random -Minimum 1000 -Maximum 9999)
$USER_FIXED = "ZunRdp"
$PASS_FIXED = "ZunRdp@2026@Cloud" 

Write-Host "[*] Dang thiet lap User: $USER_FIXED" -ForegroundColor Cyan

# --- 1. ÉP TẠO USER (FIX LỖI LOGIN) ---
# Xóa các bản lưu cũ để tránh xung đột
net user $USER_FIXED /delete >$null 2>&1
# Tạo User mới với mật khẩu mạnh để Windows không từ chối
net user $USER_FIXED $PASS_FIXED /add /y
net localgroup Administrators $USER_FIXED /add
net localgroup "Remote Desktop Users" $USER_FIXED /add
# Tắt yêu cầu đổi mật khẩu và cài đặt mật khẩu không bao giờ hết hạn
wmic useraccount where "Name='$USER_FIXED'" set PasswordExpires=FALSE

# --- 2. LẤY FULL IP TAILSCALE (DÃI 100.X) ---
$IP = "Connecting..."
$retry = 0
while ($IP -match "Connecting" -and $retry -lt 15) {
    try {
        # Ưu tiên lấy IP từ file thực thi của Tailscale
        $rawIP = (& "C:\Program Files\Tailscale\tailscale.exe" ip -4).Trim()
        if ($rawIP -match "100\.") { $IP = $rawIP }
    } catch {
        $TS_IP = (Get-NetIPAddress -InterfaceAlias "*Tailscale*" -AddressFamily IPv4).IPAddress
        if ($TS_IP) { $IP = $TS_IP[0] }
    }
    if ($IP -match "Connecting") { $retry++; Start-Sleep -Seconds 10 }
}

# --- 3. GỬI DỮ LIỆU CHUẨN LÊN SERVER ---
$data = @{ 
    id=$VM_ID; owner=$OWNER_NAME; ip=$IP; 
    user=$USER_FIXED; pass=$PASS_FIXED; 
    startTime=([DateTimeOffset]::Now.ToUnixTimeMilliseconds()); 
    cpu=0; ram=0 
} | ConvertTo-Json
Invoke-RestMethod -Uri "$API/vms/$VM_ID.json" -Method Put -Body $data

# --- 4. VÒNG LẶP GIỮ MÁY (KEEP-ALIVE) ---
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

