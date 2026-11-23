param(
    [string]$Aid = '',
    [string]$Bvid = '',
    [string[]]$Url = @(),
    [string]$Proxy = '',
    [int]$Limit = 10
)

# Wayback CDX lookup. web.archive.org is unreachable from mainland networks,
# so pass a verified -Proxy (see check-proxy.ps1).
# An empty CDX result is meaningful: the page was never archived.

$ErrorActionPreference = 'Stop'

$targets = @()
if (-not [string]::IsNullOrWhiteSpace($Aid)) {
    $targets += "bilibili.com/video/av$Aid"
    $targets += "bilibili.com/video/av$Aid/*"
    $targets += "b23.tv/av$Aid"
}
if (-not [string]::IsNullOrWhiteSpace($Bvid)) {
    $targets += "bilibili.com/video/$Bvid"
    $targets += "bilibili.com/video/$Bvid/*"
    $targets += "b23.tv/$Bvid"
}
$targets += $Url
$targets = @($targets | Where-Object { $_ } | Select-Object -Unique)

if ($targets.Count -eq 0) {
    Write-Host 'nothing to query: pass -Aid, -Bvid or -Url'
    exit 1
}

$proxyArgs = @()
if (-not [string]::IsNullOrWhiteSpace($Proxy)) { $proxyArgs = @('-x', $Proxy) }

$hits = 0
foreach ($t in $targets) {
    $enc = [uri]::EscapeDataString($t)
    $cdx = "http://web.archive.org/cdx/search/cdx?url=$enc&output=text&limit=$Limit&collapse=digest"
    Write-Host ("== " + $t)
    $out = (& curl.exe -s @proxyArgs --max-time 30 $cdx 2>$null) -join "`n"
    if ([string]::IsNullOrWhiteSpace($out)) {
        Write-Host '   no snapshot'
    }
    else {
        $hits++
        $out -split "`n" | Where-Object { $_ } | ForEach-Object {
            $f = $_ -split ' '
            $ts = $f[1]
            if ($ts.Length -ge 14) {
                $when = $ts.Substring(0, 4) + '-' + $ts.Substring(4, 2) + '-' + $ts.Substring(6, 2)
                Write-Host ("   snap {0}  http://web.archive.org/web/{1}/{2}" -f $when, $ts, $f[2])
            }
            else { Write-Host ("   " + $_) }
        }
    }
}

Write-Host ''
if ($hits -eq 0) {
    Write-Host 'verdict: never archived. Wayback cannot help for this item.'
} else {
    Write-Host ("verdict: {0} target(s) have snapshots. HTML only - a snapshot rarely contains the media file." -f $hits)
}
