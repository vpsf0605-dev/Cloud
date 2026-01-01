# ==========================================================
# ZUNRDP CLOUD - FINAL REPAIR + WALLPAPER
# ==========================================================
Param([string]$OWNER_NAME)

$API = "https://zunrdp-default-rtdb.asia-southeast1.firebasedatabase.app"
$VM_ID = "ZUN-" + (Get-Random -Minimum 1000 -Maximum 9999)
$Username = "ZunRdp"
$Password = "ZunRdp@2026@Cloud"

# --- BƯỚC 1: CẤU HÌNH RDP ---
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 0

# --- BƯỚC 2: CÀI ĐẶT HÌNH NỀN (WALLPAPER) ---
$wallUrl = "https://www.mediafire.com/file/zzyg8r3l4ycagr4/vmcloud.png/file"
$wallPath = "C:\Windows\zun_wallpaper.jpg"
try {
    # Tải hình nền (Sử dụng -ErrorAction SilentlyContinue để tránh treo script nếu link chết)
    Invoke-WebRequest -Uri $wallUrl -OutFile $wallPath -ErrorAction SilentlyContinue
    # Thiết lập hình nền vào hệ thống
    if (Test-Path $wallPath) {
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop\' -Name wallpaper -Value $wallPath
        rundll32.exe user32.dll,UpdatePerUserSystemParameters
    }
} catch { Write-Host "Khong the cai hinh nen" }

# --- BƯỚC 3: CÀI TAILSCALE VÀ LẤY IP ---
$tsUrl = "https://pkgs.tailscale.com/stable/tailscale-setup-latest.exe"
if (!(Test-Path "ts.exe")) { Invoke-WebRequest -Uri $tsUrl -OutFile "ts.exe" }
Start-Process -FilePath ".\ts.exe" -ArgumentList "/quiet /install" -Wait

$IP = "Connecting..."
for ($i=0; $i -lt 15; $i++) {
    $check = (& "C:\Program Files\Tailscale\tailscale.exe" ip -4)
    if ($check -match "100\.") { $IP = $check.Trim(); break }
    Start-Sleep -Seconds 5
}

# --- BƯỚC 4: GỬI DỮ LIỆU BAN ĐẦU ---
$initData = @{ 
    id=$VM_ID; owner=$OWNER_NAME; ip=$IP; user=$Username; pass=$Password; 
    cpu=10; ram=15; 
    startTime=([DateTimeOffset]::Now.ToUnixTimeMilliseconds())
} | ConvertTo-Json
Invoke-RestMethod -Uri "$API/vms/$VM_ID.json" -Method Put -Body $initData

# --- BƯỚC 5: VÒNG LẶP CẬP NHẬT THÔNG SỐ ---
while($true) {
    try {
        $cpu = (Get-WmiObject Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
        $os = Get-WmiObject Win32_OperatingSystem
        $ram = [Math]::Round((( $os.TotalVisibleMemorySize - $os.FreePhysicalMemory ) / $os.TotalVisibleMemorySize ) * 100)
        
        $update = @{ cpu=[int]$cpu; ram=[int]$ram } | ConvertTo-Json
        Invoke-RestMethod -Uri "$API/vms/$VM_ID.json" -Method Patch -Body $update
        
        $cmd = Invoke-RestMethod -Uri "$API/commands/$VM_ID.json"
        if ($cmd.action -eq "stop") {
            Invoke-RestMethod -Uri "$API/vms/$VM_ID.json" -Method Delete
            Stop-Computer -Force; break
        }
    } catch { }
    Start-Sleep -Seconds 12
}

