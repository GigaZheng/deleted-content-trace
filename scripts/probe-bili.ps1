param(
    [string]$Name = '',
    [string]$Aid = '',
    [string]$Bvid = '',
    [string]$Mid = '',
    [string[]]$Keywords = @('舞', 'cos', '漫展', '宅舞', '2020', '2021', '2022')
)

# Probe a Bilibili creator or a specific submission.
#   -Name  free-text nick  -> resolve candidate mids via the user index
#   -Mid   numeric mid     -> card + keyword-swept upload list
#   -Aid   numeric aid     -> status code + pagelist + comment probe
#   -Bvid  BV id           -> same as -Aid

$ErrorActionPreference = 'Stop'
$UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120 Safari/537.36'
$H = @{ 'User-Agent' = $UA; 'Referer' = 'https://www.bilibili.com/' }

$CodeMeaning = @{
    '0'     = 'ONLINE'
    '-404'  = 'GONE (deleted or never existed)'
    '62002' = 'INVISIBLE (private / locked / under review) - uploader can restore'
    '62012' = 'OWNER-ONLY'
    '-352'  = 'RISK CONTROL (needs cookies)'
    '12002' = 'COMMENTS CLOSED (page torn down)'
}

function Explain($code, $message) {
    $m = $CodeMeaning["$code"]
    if (-not $m) { $m = 'unknown' }
    return ("code={0} ({1}) msg={2}" -f $code, $m, $message)
}

function Get-Card($mid) {
    try {
        $j = Invoke-RestMethod -Uri "https://api.bilibili.com/x/web-interface/card?mid=$mid" -Headers $H -TimeoutSec 10
        if ($j.code -ne 0) { return $null }
        return [PSCustomObject]@{
            Mid      = $mid
            Name     = $j.data.card.name
            Followers = $j.data.follower
            Following = $j.data.following
            Level    = $j.data.card.level
            Sign     = $j.data.card.sign
            Face     = $j.data.card.face
        }
    }
    catch { return $null }
}

function Resolve-Name($text) {
    $q = [uri]::EscapeDataString($text)
    $tmp = Join-Path $env:TEMP ('dt_upuser_' + [Math]::Abs($text.GetHashCode()) + '.html')
    & curl.exe -s -A $UA --max-time 20 "https://search.bilibili.com/upuser?keyword=$q" -o $tmp
    $html = Get-Content $tmp -Raw -Encoding UTF8
    $ids = [regex]::Matches($html, 'space\.bilibili\.com/(\d{3,})') |
        ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
    return $ids
}

function Get-Uploads($mid) {
    $seen = @{}
    $out = @()
    foreach ($k in ($Keywords | Select-Object -Unique)) {
        $enc = [uri]::EscapeDataString($k)
        if ([string]::IsNullOrWhiteSpace($enc)) { continue }
        try {
            $j = Invoke-RestMethod -Uri "https://api.bilibili.com/x/series/recArchivesByKeywords?mid=$mid&keywords=$enc&ps=30&pn=1&orderby=pubdate" -Headers $H -TimeoutSec 12
            if ($j.code -eq 0 -and $j.data.archives) {
                foreach ($a in $j.data.archives) {
                    if (-not $seen.ContainsKey($a.bvid)) {
                        $seen[$a.bvid] = 1
                        $out += $a
                    }
                }
            }
        }
        catch { }
        Start-Sleep -Milliseconds 700
    }
    return @($out | Sort-Object pubdate -Descending)
}

function Show-Uploads($mid) {
    Write-Host '-- uploads (keyword sweep) --'
    $rows = Get-Uploads $mid
    Write-Host ("   found {0}" -f $rows.Count)
    foreach ($r in $rows) {
        $d = [DateTimeOffset]::FromUnixTimeSeconds($r.pubdate).ToString('yyyy-MM-dd')
        Write-Host ("   {0}  {1}  {2,5}s  {3}" -f $r.bvid, $d, $r.duration, $r.title)
    }
    if ($rows.Count -eq 0) {
        Write-Host '   note: the keyword bypass only sees titles matching the keywords.'
        Write-Host '         empty result means every surviving title is unrelated to those words,'
        Write-Host '         not necessarily that the creator has no uploads.'
    }
}

# ---------------- name mode ----------------
if (-not [string]::IsNullOrWhiteSpace($Name)) {
    Write-Host ("== resolving name: {0}" -f $Name)
    $ids = Resolve-Name $Name
    if (-not $ids -or $ids.Count -eq 0) {
        Write-Host '   no candidate mid found in the user index'
    }
    foreach ($candId in $ids) {
        $c = Get-Card $candId
        if (-not $c) { continue }
        $flag = ''
        if ($c.Followers -eq 0 -and [string]::IsNullOrWhiteSpace($c.Sign) -and $c.Face -like '*noface*') {
            $flag = '   <-- empty placeholder / squatted id, not the creator'
        }
        Write-Host ("   {0}  {1}  followers={2}  following={3}  level={4}{5}" -f $c.Mid, $c.Name, $c.Followers, $c.Following, $c.Level, $flag)
        if (-not [string]::IsNullOrWhiteSpace($c.Sign)) { Write-Host ("        sign: " + $c.Sign) }
        Start-Sleep -Milliseconds 300
    }
    if ($ids.Count -gt 0) { Write-Host '   tip: pass -Mid <id> to sweep that account''s uploads.' }
}

# ---------------- aid / bvid mode ----------------
if (-not [string]::IsNullOrWhiteSpace($Aid) -or -not [string]::IsNullOrWhiteSpace($Bvid)) {
    $q = if ($Aid) { "aid=$Aid" } else { "bvid=$Bvid" }
    Write-Host ("== view: {0}" -f $q)
    $raw = (& curl.exe -s -A $UA -H "Referer: https://www.bilibili.com/" --max-time 20 "https://api.bilibili.com/x/web-interface/view?$q") -join ''
    $v = $null
    try { $v = $raw | ConvertFrom-Json } catch { }
    if ($v) {
        Write-Host ('   ' + (Explain $v.code $v.message))
        if ($v.code -eq 0 -and $v.data) {
            Write-Host ("   title  : " + $v.data.title)
            Write-Host ("   owner  : " + $v.data.owner.name + " (mid " + $v.data.owner.mid + ")")
            Write-Host ("   pubdate: " + [DateTimeOffset]::FromUnixTimeSeconds($v.data.pubdate).ToString('yyyy-MM-dd'))
            Write-Host ("   stat   : view=" + $v.data.stat.view + " fav=" + $v.data.stat.favorite + " coin=" + $v.data.stat.coin)
        }
    }

    Write-Host ("== pagelist: {0}" -f $q)
    $pr = (& curl.exe -s -A $UA --max-time 20 "https://api.bilibili.com/x/player/pagelist?$q") -join ''
    $p = $null
    try { $p = $pr | ConvertFrom-Json } catch { }
    if ($p) { Write-Host ('   ' + (Explain $p.code $p.message)) }

    if (-not [string]::IsNullOrWhiteSpace($Aid)) {
        Write-Host ("== replies: aid={0}" -f $Aid)
        $rr = (& curl.exe -s -A $UA -H "Referer: https://www.bilibili.com/" --max-time 20 "https://api.bilibili.com/x/v2/reply?oid=$Aid&type=1&pn=1&ps=5") -join ''
        $r = $null
        try { $r = $rr | ConvertFrom-Json } catch { }
        if ($r) { Write-Host ('   ' + (Explain $r.code $r.message)) }
    }

    Write-Host ''
    Write-Host '   next: scripts/probe-archive.ps1 to check Wayback, and probe-platforms.ps1 to sweep mirrors.'
}

# ---------------- mid mode ----------------
if (-not [string]::IsNullOrWhiteSpace($Mid)) {
    Write-Host ("== card: mid={0}" -f $Mid)
    $c = Get-Card $Mid
    if ($c) {
        Write-Host ("   " + $c.Name + "  followers=" + $c.Followers + "  level=" + $c.Level)
        if (-not [string]::IsNullOrWhiteSpace($c.Sign)) { Write-Host ("   sign: " + $c.Sign) }
    }
    else { Write-Host '   card failed' }
    Show-Uploads $Mid
}
