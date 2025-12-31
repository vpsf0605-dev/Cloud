Param ([string]$Owner, [string]$MachineID)
$Owner = "$Owner".ToLower().Trim()
$baseUrl = "https://zunrdp-default-rtdb.asia-southeast1.firebasedatabase.app"
$vmUrl = "$baseUrl/vms/$MachineID.json"
$cmdUrl = "$baseUrl/commands/$MachineID.json"

# Đọc pass ngẫu nhiên từ file
$pass = (Get-Content "pass.txt" -Raw).Trim()

while($true) {
    try {
        # Check lệnh Kill
        $cmd = Invoke-RestMethod -Uri $cmdUrl -Method Get -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.action -eq "stop") {
            Invoke-RestMethod -Uri $cmdUrl -Method Delete
            Invoke-RestMethod -Uri $vmUrl -Method Delete
            Stop-Computer -Force
            exit
        }

        # Lấy thông số
        $cpu = [Math]::Round((Get-WmiObject Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average, 1)
        $os = Get-WmiObject Win32_OperatingSystem
        $ram = [Math]::Round(((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100), 1)
        $ip = (& "C:\Program Files\Tailscale\tailscale.exe" ip -4).Trim()

        $data = @{
            id=$MachineID; ip=$ip; owner=$Owner; user="ZunRDP"; pass=$pass;
            cpu=$cpu; ram=$ram; lastSeen=[DateTimeOffset]::Now.ToUnixTimeMilliseconds()
        } | ConvertTo-Json
        
        Invoke-RestMethod -Uri $vmUrl -Method Put -Body $data
    } catch { }
    Start-Sleep -Seconds 5
}
