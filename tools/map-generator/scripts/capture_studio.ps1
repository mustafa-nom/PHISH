param(
    [string]$OutPath = $env:TEMP + "\studio_shot.png",
    [string]$WindowTitle = "Roblox Studio",
    [switch]$FullScreen
)

# captures roblox studio's main window (or the full primary screen with
# -FullScreen). designed to be invoked from WSL via:
#   powershell.exe -ExecutionPolicy Bypass -File <wsl-path>\capture_studio.ps1 -OutPath C:\Temp\out.png

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

# allowing reuse: only define types once
if (-not ('WinApi' -as [type])) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinApi {
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")]
    public static extern bool GetClientRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")]
    public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder lpString, int nMaxCount);
    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern bool IsIconic(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    // PrintWindow draws the window's contents into the given device context
    // even when the window is occluded by another window. flag 2 == PW_RENDERFULLCONTENT
    // which works for hardware-accelerated windows like Studio.
    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr hwnd, IntPtr hDC, uint nFlags);
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }
}
public class WinEnum {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
}
"@
}

function Capture-Bounds([int]$left, [int]$top, [int]$width, [int]$height, [string]$out) {
    $bmp = New-Object System.Drawing.Bitmap $width, $height
    $gfx = [System.Drawing.Graphics]::FromImage($bmp)
    $gfx.CopyFromScreen($left, $top, 0, 0, [System.Drawing.Size]::new($width, $height))
    $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
    $gfx.Dispose()
    $bmp.Dispose()
}

function Capture-Window([IntPtr]$hwnd, [int]$width, [int]$height, [string]$out) {
    # render the window's contents directly into a bitmap via PrintWindow.
    # works even when the window is behind other windows.
    $bmp = New-Object System.Drawing.Bitmap $width, $height
    $gfx = [System.Drawing.Graphics]::FromImage($bmp)
    $hdc = $gfx.GetHdc()
    # 2 = PW_RENDERFULLCONTENT: forces the window to draw using its full
    # composition, which is required for windows that use hardware
    # acceleration like roblox studio.
    $ok = [WinApi]::PrintWindow($hwnd, $hdc, 2)
    $gfx.ReleaseHdc($hdc)
    if (-not $ok) {
        # fallback to flag 0 if PW_RENDERFULLCONTENT failed
        $hdc = $gfx.GetHdc()
        [void][WinApi]::PrintWindow($hwnd, $hdc, 0)
        $gfx.ReleaseHdc($hdc)
    }
    $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
    $gfx.Dispose()
    $bmp.Dispose()
}

if ($FullScreen) {
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    Capture-Bounds $bounds.Left $bounds.Top $bounds.Width $bounds.Height $OutPath
    Write-Host "captured full primary screen ($($bounds.Width) x $($bounds.Height)) -> $OutPath"
    return
}

# enumerate visible windows, pick the LARGEST match for $WindowTitle so we
# avoid tiny splashes/tooltips that share the title.
$candidates = New-Object System.Collections.Generic.List[Object]
$titleBuf = New-Object System.Text.StringBuilder 512
$enumProc = {
    param($hwnd, $lParam)
    if (-not [WinApi]::IsWindowVisible($hwnd)) { return $true }
    $titleBuf.Clear() | Out-Null
    [void][WinApi]::GetWindowText($hwnd, $titleBuf, 512)
    $title = $titleBuf.ToString()
    if ($title -like "*$WindowTitle*") {
        $r = New-Object WinApi+RECT
        [void][WinApi]::GetWindowRect($hwnd, [ref]$r)
        $w = $r.Right - $r.Left
        $h = $r.Bottom - $r.Top
        if ($w -gt 0 -and $h -gt 0) {
            $script:candidates.Add([PSCustomObject]@{ Title = $title; HWnd = $hwnd; Left = $r.Left; Top = $r.Top; Width = $w; Height = $h; Area = $w * $h })
        }
    }
    return $true
}
[WinEnum]::EnumWindows([WinEnum+EnumWindowsProc]$enumProc, [IntPtr]::Zero) | Out-Null

if ($candidates.Count -eq 0) {
    # fallback to full screen
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    Capture-Bounds $bounds.Left $bounds.Top $bounds.Width $bounds.Height $OutPath
    $w = $bounds.Width
    $h = $bounds.Height
    Write-Host "no '$WindowTitle' window found, captured full primary screen ($w by $h) at $OutPath"
    return
}

# pick the window with the largest area
$best = $candidates | Sort-Object Area -Descending | Select-Object -First 1
Write-Host "matched windows:"
$candidates | ForEach-Object { Write-Host ("  - {0} by {1} '{2}'" -f $_.Width, $_.Height, $_.Title) }

# un-minimize if the window is iconic so PrintWindow has something to draw
if ([WinApi]::IsIconic($best.HWnd)) {
    [void][WinApi]::ShowWindow($best.HWnd, 9)  # SW_RESTORE
    Start-Sleep -Milliseconds 200
}

# PrintWindow uses the client/window dimensions of the window itself, so we
# can capture without needing to bring it to the foreground.
$width = $best.Width
$height = $best.Height

Capture-Window $best.HWnd $width $height $OutPath
$btitle = $best.Title
Write-Host "captured '$btitle' ($width by $height) at $OutPath"
