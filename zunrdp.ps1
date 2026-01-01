# ==========================================================
# ZUNRDP CLOUD - FIX AUTH & TAILSCALE IP
# ==========================================================
Param([string]$OWNER_NAME)

$API = "https://zunrdp-default-rtdb.asia-southeast1.firebasedatabase.app"
$VM_ID = "ZUN-" + (Get-Random -Minimum 1000 -Maximum 9999)
$USER_FIXED = "ZunRdp"
$PASS_FIXED = "ZunRdp@2026Aa" # Thêm chữ 'Aa' để đảm bảo cực kỳ bảo mật, tránh lỗi hệ thống

Write-Host "[*] Dang tao User: $USER_FIXED" -ForegroundColor Cyan

# --- 1. TAO USER BANG NET USER (ON DINH HON) ---
net user $USER_FIXED $PASS_FIXED /add /passwordchg:no
net localgroup Administrators $USER_FIXED /add
net localgroup "Remote Desktop Users" $USER_FIXED /add

# --- 2. LAY IP TAILSCALE ---
Write-Host "[*] Dang tim IP Tailscale..." -ForegroundColor Yellow
$IP = "0.0.0.0"
# Đợi Tailscale khởi động nếu cần
Start-Sleep -Seconds 5
# Lấy IP của card mạng Tailscale (thường bắt đầu bằng 100.x.x.x)
$TS_IP = (Get-NetIPAddress -InterfaceAlias "Tailscale" -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
if ($TS_IP) {
    $IP = $TS_IP
} else {
    # Nếu không thấy card Tailscale, lấy IP Public làm dự phòng
    $IP = (Invoke-RestMethod -Uri "https://api.ipify.org").Trim()
}

# --- 3. CAI ANH NEN ---
$wallUrl = "https://www.mediafire.com/file/zzyg8r3l4ycagr4/vmcloud.png/file"
$wallPath = "C:\Windows\zun_wallpaper.png"
try {
    Invoke-WebRequest -Uri $wallUrl -OutFile $wallPath
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop\' -Name wallpaper -Value $wallPath
    rundll32.exe user32.dll,UpdatePerUserSystemParameters
} catch {}

# --- 4. GUI DU LIEU VE FIREBASE ---
$data = @{ 
    id=$VM_ID; owner=$OWNER_NAME; ip=$IP; 
    user=$USER_FIXED; pass=$PASS_FIXED; 
    startTime=([DateTimeOffset]::Now.ToUnixTimeMilliseconds()); 
    cpu=0; ram=0 
} | ConvertTo-Json
Invoke-RestMethod -Uri "$API/vms/$VM_ID.json" -Method Put -Body $data

# --- 5. VONG LAP GIU MAY (KEEP-ALIVE) ---
Write-Host "[+] VM $VM_ID IS READY!" -ForegroundColor Green
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

