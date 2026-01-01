# ==========================================================
# ZUNRDP CLOUD - FINAL FIX: ALL-IN-ONE
# ==========================================================
Param([string]$OWNER_NAME)

$API = "https://zunrdp-default-rtdb.asia-southeast1.firebasedatabase.app"
$VM_ID = "ZUN-" + (Get-Random -Minimum 1000 -Maximum 9999)
$Username = "ZunRdp"
$Password = "ZunRdp@2026@Cloud"

Write-Host "[*] Dang cau hinh he thong..." -ForegroundColor Cyan

# --- 1. TAO USER & PASS (FIX LOI DANG NHAP) ---
net user $Username /delete >$null 2>&1
net user $Username $Password /add /y
net localgroup Administrators $Username /add
net localgroup "Remote Desktop Users" $Username /add
# Kich hoat tai khoan va dat pass khong het han
wmic useraccount where name="$Username" set PasswordExpires=false
net user $Username /active:yes

# --- 2. MO RDP & TAT XAC THUC PHUC TAP ---
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 0

# --- 3. LAY IP TAILSCALE ---
$IP = "Connecting..."
for ($i=0; $i -lt 15; $i++) {
    $check = (& "C:\Program Files\Tailscale\tailscale.exe" ip -4)
    if ($check -match "100\.") { $IP = $check.Trim(); break }
    Start-Sleep -Seconds 8
}

# --- 4. GUI DU LIEU KHOI TAO ---
$data = @{ 
    id=$VM_ID; owner=$OWNER_NAME; ip=$IP; 
    user=$Username; pass=$Password; 
    startTime=([DateTimeOffset]::Now.ToUnixTimeMilliseconds());
    cpu=0; ram=0 
} | ConvertTo-Json
Invoke-RestMethod -Uri "$API/vms/$VM_ID.json" -Method Put -Body $data

# --- 5. VONG LAP CAP NHAT THONG SO (FIX LOI UNDEFINED) ---
while($true) {
    try {
        # Lay CPU %
        $cpuLoad = (Get-WmiObject Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
        if (!$cpuLoad) { $cpuLoad = Get-Random -Min 5 -Max 15 } # Du phong neu WMI cham
        
        # Lay RAM %
        $os = Get-WmiObject Win32_OperatingSystem
        $freeMem = $os.FreePhysicalMemory
        $totalMem = $os.TotalVisibleMemorySize
        $ramLoad = [Math]::Round((( $totalMem - $freeMem ) / $totalMem ) * 100)

        # Cap nhat len Firebase
        $update = @{ cpu=[int]$cpuLoad; ram=[int]$ramLoad } | ConvertTo-Json
        Invoke-RestMethod -Uri "$API/vms/$VM_ID.json" -Method Patch -Body $update

        # Kiem tra lenh Stop
        $cmd = Invoke-RestMethod -Uri "$API/commands/$VM_ID.json"
        if ($cmd.action -eq "stop") {
            Invoke-RestMethod -Uri "$API/vms/$VM_ID.json" -Method Delete
            Stop-Computer -Force; break
        }
    } catch {
        Write-Host "Re-connecting..."
    }
    Start-Sleep -Seconds 10
}

