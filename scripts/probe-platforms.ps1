param(
    [Parameter(Mandatory = $true)][string]$Keyword,
    [string]$Proxy = '',
    [int]$Limit = 10
)

# Keyword sweep across the video platforms that actually answer scripted requests.
# Platforms that need login or request signing are reported as NOT VERIFIABLE,
# never as "no results" - the distinction matters when writing the final report.

$ErrorActionPreference = 'Stop'
$UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120 Safari/537.36'
$enc = [uri]::EscapeDataString($Keyword)
$proxyArgs = @()
if (-not [string]::IsNullOrWhiteSpace($Proxy)) { $proxyArgs = @('-x', $Proxy) }

function Head($name) { Write-Host ''; Write-Host ("== " + $name) }

$total = 0

# ---------- YouTube (needs proxy) ----------
Head 'YouTube'
if (-not $Proxy) {
    Write-Host '   SKIPPED: needs -Proxy (unreachable directly)'
}
else {
    $html = (& curl.exe -s -L @proxyArgs --max-time 30 -A $UA "https://www.youtube.com/results?search_query=$enc") -join "`n"
    $m = [regex]::Matches($html, '"videoRenderer":\{"videoId":"([\w-]{11})".{0,4000}?"title":\{"runs":\[\{"text":"([^"]{2,90})"', 'Singleline')
    Write-Host ("   hits=" + $m.Count)
    $m | Select-Object -First $Limit | ForEach-Object {
        Write-Host ("   https://youtu.be/" + $_.Groups[1].Value + "  |  " + $_.Groups[2].Value)
    }
    $total += $m.Count
}

# ---------- iQiyi ----------
Head 'iQiyi'
try {
    $j = Invoke-RestMethod -Uri "https://mesh.if.iqiyi.com/portal/lw/search/homePageV3?key=$enc&pageNum=1&pageSize=30&source=default" -Headers @{ 'User-Agent' = $UA } -TimeoutSec 25
    $titles = @()
    foreach ($t in $j.data.templates) {
        if ($t.albumInfo -and $t.albumInfo.title) { $titles += $t.albumInfo.title }
    }
    Write-Host ("   results=" + $titles.Count)
    $titles | Select-Object -Unique -First $Limit | ForEach-Object { Write-Host ("   " + $_) }
    $total += $titles.Count
}
catch { Write-Host '   request failed' }

# ---------- Youku ----------
Head 'Youku'
try {
    $raw = (& curl.exe -s -A $UA -H 'Referer: https://www.youku.com/' --max-time 25 "https://search.youku.com/api/search?keyword=$enc&page=1") -join ''
    $hits = [regex]::Matches($raw, '"[^"]{0,40}' + [regex]::Escape($Keyword) + '[^"]{0,60}"') |
        ForEach-Object { $_.Value } | Select-Object -Unique
    Write-Host ("   raw_len=" + $raw.Length + "  keyword_bearing_strings=" + $hits.Count)
    $hits | Select-Object -First $Limit | ForEach-Object { Write-Host ("   " + $_) }
    if ($raw.Length -lt 800) { Write-Host '   note: payload too small - likely no result, only the echo of the search term' }
}
catch { Write-Host '   request failed' }

# ---------- Dailymotion (needs proxy) ----------
Head 'Dailymotion'
if (-not $Proxy) {
    Write-Host '   SKIPPED: needs -Proxy'
}
else {
    try {
        $d = Invoke-RestMethod -Uri "https://api.dailymotion.com/videos?search=$enc&fields=id,title,url&limit=$Limit" -TimeoutSec 25
        Write-Host ("   total=" + $d.total)
        $d.list | ForEach-Object { Write-Host ("   " + $_.title + "  |  " + $_.url) }
        $total += $d.list.Count
    }
    catch { Write-Host '   request failed' }
}

# ---------- AcFun ----------
Head 'AcFun'
Write-Host '   NOT VERIFIABLE: rest/pc-direct/search returns 404 without signing; site is JS-rendered.'
Write-Host '   manual route: open acfun.cn and search the nick, or check known dance-cover channels.'

# ---------- report ----------
Head 'platforms requiring manual login (cannot be swept by script)'
Write-Host '   Douyin, Kuaishou, Xiaohongshu, Weibo, TikTok, Instagram, X'
Write-Host '   These need a signed-in session or request signing. Do not report them as "no results" -'
Write-Host '   report them as "not verifiable from here" and give the user the keyword to try by hand.'

Write-Host ''
Write-Host ("automatable hits total = {0}" -f $total)
