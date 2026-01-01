Param([string]$Owner, [string]$MachineID)

# Cấu hình RDP
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 0

$API = "https://zunrdp-default-rtdb.asia-southeast1.firebasedatabase.app"
$Password = (Get-Content "pass.txt" -Raw).Trim()
$Uptime = (Get-Content "uptime.txt" -Raw).Trim()

# Quét IP Tailscale
$IP = "Connecting..."
for ($i=0; $i -lt 10; $i++) {
    $tsPath = "C:\Program Files\Tailscale\tailscale.exe"
    if (Test-Path $tsPath) {
        $check = (& $tsPath ip -4).Trim()
        if ($check -match "100\.") { $IP = $check; break }
    }
    Start-Sleep -Seconds 2
}

# Gửi dữ liệu khởi tạo lên Firebase (Fix lỗi [object Object])
$vmData = @{
    id = $MachineID; owner = $Owner; ip = $IP; user = "ZunRdp";
    pass = "$Password"; cpu = 5; ram = 15; startTime = [long]$Uptime
} | ConvertTo-Json -Compress
Invoke-RestMethod -Uri "$API/vms/$MachineID.json" -Method Put -Body $vmData

# Vòng lặp Realtime
while($true) {
    try {
        $cpu = [int](Get-WmiObject Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
        $os = Get-WmiObject Win32_OperatingSystem
        $ram = [int][Math]::Round((( $os.TotalVisibleMemorySize - $os.FreePhysicalMemory ) / $os.TotalVisibleMemorySize ) * 100)
        
        # Patch thông số CPU/RAM lên Web
        $update = @{ cpu = $cpu; ram = $ram } | ConvertTo-Json -Compress
        Invoke-RestMethod -Uri "$API/vms/$MachineID.json" -Method Patch -Body $update
        
        # Lắng nghe lệnh Kill từ Dashboard
        $cmd = Invoke-RestMethod -Uri "$API/commands/$MachineID.json"
        if ($cmd.action -eq "stop") {
            Invoke-RestMethod -Uri "$API/vms/$MachineID.json" -Method Delete
            Stop-Computer -Force; break
        }
    } catch { }
    Start-Sleep -Seconds 12
}

