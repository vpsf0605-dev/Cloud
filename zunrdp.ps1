# ==========================================================
# ZUNRDP CLOUD - FIXED USER & FULL TAILSCALE IP
# ==========================================================
Param([string]$OWNER_NAME)

$API = "https://zunrdp-default-rtdb.asia-southeast1.firebasedatabase.app"
$VM_ID = "ZUN-" + (Get-Random -Minimum 1000 -Maximum 9999)
$USER_FIXED = "ZunRdp"
$PASS_FIXED = "ZunRdp@2026@Cloud" 

Write-Host "[*] Dang thiet lap User mac dinh: $USER_FIXED" -ForegroundColor Cyan

# --- 1. TAO USER (DUNG NET USER DE TRANH LOI PASSWORD) ---
net user $USER_FIXED /delete >$null 2>&1
net user $USER_FIXED $PASS_FIXED /add /y
net localgroup Administrators $USER_FIXED /add
net localgroup "Remote Desktop Users" $USER_FIXED /add
wmic useraccount where "Name='$USER_FIXED'" set PasswordExpires=FALSE

# --- 2. LAY FULL IP TAILSCALE (DAI 100.X.X.X) ---
Write-Host "[*] Dang doi Tailscale khoi tao IP..." -ForegroundColor Yellow
Start-Sleep -Seconds 12 # Cho Tailscale thoi gian nhan IP tu server
$IP = "0.0.0.0"

# Lay IP tu interface co ten Tailscale
$TS_IP = Get-NetIPAddress | Where-Object { $_.InterfaceAlias -like "*Tailscale*" -and $_.AddressFamily -eq "IPv4" } | Select-Object -ExpandProperty IPAddress

if ($TS_IP) {
    $IP = $TS_IP[0]
    Write-Host "[+] Da lay duoc IP Tailscale: $IP" -ForegroundColor Green
} else {
    # Neu lenh tren khong ra, dung lenh truc tiep cua Tailscale exe
    try {
        $IP = (& "C:\Program Files\Tailscale\tailscale.exe" ip -4).Trim()
    } catch {
        $IP = "Check_Tailscale_Login"
    }
}

# --- 3. CAI ANH NEN ZUNRDP ---
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

