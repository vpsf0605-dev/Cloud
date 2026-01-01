Param([string]$Owner, [string]$MachineID)

$API = "https://zunrdp-default-rtdb.asia-southeast1.firebasedatabase.app"
$Username = "ZunRdp"
$Password = Get-Content "pass.txt"
$Uptime = Get-Content "uptime.txt" # Đã sửa lỗi Get-Get-Content

# --- [1] CÀI ĐẶT HÌNH NỀN (WALLPAPER) ---
# Tải hình ảnh từ link Mediafire của bạn
$wallUrl = "https://www.mediafire.com/file/zzyg8r3l4ycagr4/vmcloud.png/file"
$wallPath = "C:\Windows\zun_wallpaper.jpg"

try {
    # Tải file âm thầm
    Invoke-WebRequest -Uri $wallUrl -OutFile $wallPath -ErrorAction SilentlyContinue
    if (Test-Path $wallPath) {
        # Ép hệ thống nhận hình nền mới
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop\' -Name wallpaper -Value $wallPath
        rundll32.exe user32.dll,UpdatePerUserSystemParameters
    }
} catch { }

# --- [2] CẤU HÌNH RDP ---
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 0

# --- [3] LẤY IP TAILSCALE ---
$IP = "Connecting..."
for ($i=0; $i -lt 15; $i++) {
    $tsPath = "C:\Program Files\Tailscale\tailscale.exe"
    if (Test-Path $tsPath) {
        $check = (& $tsPath ip -4).Trim()
        if ($check -match "100\.") { $IP = $check; break }
    }
    Start-Sleep -Seconds 5
}

# --- [4] GỬI DỮ LIỆU BAN ĐẦU (FIX UNDEFINED) ---
$initData = @{ 
    id=$MachineID; owner=$Owner; ip=$IP; user=$Username; pass=$Password; 
    cpu=10; ram=20; startTime=[long]$Uptime 
} | ConvertTo-Json
Invoke-RestMethod -Uri "$API/vms/$MachineID.json" -Method Put -Body $initData

# --- [5] VÒNG LẬP CẬP NHẬT THÔNG SỐ CPU/RAM ---
while($true) {
    try {
        $cpu = [int](Get-WmiObject Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
        $os = Get-WmiObject Win32_OperatingSystem
        $ram = [int][Math]::Round((( $os.TotalVisibleMemorySize - $os.FreePhysicalMemory ) / $os.TotalVisibleMemorySize ) * 100)
        
        # Gửi cập nhật thông số
        Invoke-RestMethod -Uri "$API/vms/$MachineID.json" -Method Patch -Body (@{cpu=$cpu; ram=$ram} | ConvertTo-Json)
        
        # Kiểm tra lệnh stop từ web
        $cmd = Invoke-RestMethod -Uri "$API/commands/$MachineID.json"
        if ($cmd.action -eq "stop") {
            Invoke-RestMethod -Uri "$API/vms/$MachineID.json" -Method Delete
            Stop-Computer -Force; break
        }
    } catch { }
    Start-Sleep -Seconds 12
}

