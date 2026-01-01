# ==========================================================
# ZUNRDP CLOUD - ENGINE V2026 (FULL KEEP-ALIVE)
# ==========================================================
Param(
    [string]$OWNER_NAME,
    [string]$TS_KEY
)

$API = "https://zunrdp-default-rtdb.asia-southeast1.firebasedatabase.app"
$VM_ID = "ZUN-" + (Get-Random -Minimum 1000 -Maximum 9999)

# --- TẢI VÀ ĐẶT HÌNH NỀN ---
$wallUrl = "https://www.mediafire.com/file/zzyg8r3l4ycagr4/vmcloud.png/file?dkey=4crai66gudz&r=1906"
$wallPath = "C:\Windows\zun_wallpaper.png"
try {
    Invoke-WebRequest -Uri $wallUrl -OutFile $wallPath
    $code = @'
    using System.Runtime.InteropServices;
    public class Wallpaper {
        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
    }
'@
    Add-Type -TypeDefinition $code
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop\' -Name wallpaper -Value $wallPath
    [Wallpaper]::SystemParametersInfo(20, 0, $wallPath, 3)
} catch {}

# --- LẤY THÔNG TIN MÁY ---
$IP = (Invoke-RestMethod -Uri "https://api.ipify.org")
$USER = $env:USERNAME
$PASS = "ZunRdp@2026"

# --- GỬI DỮ LIỆU BAN ĐẦU ---
$data = @{ id=$VM_ID; owner=$OWNER_NAME; ip=$IP; user=$USER; pass=$PASS; startTime=([DateTimeOffset]::Now.ToUnixTimeMilliseconds()); cpu=0; ram=0 } | ConvertTo-Json
Invoke-RestMethod -Uri "$API/vms/$VM_ID.json" -Method Put -Body $data

# --- VÒNG LẶP GIỮ MÁY LUÔN CHẠY (KEEP-ALIVE) ---
while($true) {
    try {
        # 1. Kiểm tra lệnh Kill từ Web
        $cmd = Invoke-RestMethod -Uri "$API/commands/$VM_ID.json"
        if ($cmd.action -eq "stop") {
            Invoke-RestMethod -Uri "$API/vms/$VM_ID.json" -Method Delete
            Invoke-RestMethod -Uri "$API/commands/$VM_ID.json" -Method Delete
            Stop-Computer -Force
            break
        }

        # 2. Tính toán CPU & RAM thực tế
        $cpu = (Get-WmiObject Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
        $mem = Get-WmiObject Win32_OperatingSystem
        $ram = [Math]::Round((( $mem.TotalVisibleMemorySize - $mem.FreePhysicalMemory ) / $mem.TotalVisibleMemorySize ) * 100)

        # 3. Cập nhật thông số lên Server
        $upd = @{ cpu=$cpu; ram=$ram } | ConvertTo-Json
        Invoke-RestMethod -Uri "$API/vms/$VM_ID.json" -Method Patch -Body $upd
    } catch {}
    Start-Sleep -Seconds 8 # Gửi dữ liệu mỗi 8 giây
}

