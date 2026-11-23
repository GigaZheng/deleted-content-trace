param(
    [int[]]$Ports = @(7890, 7891, 12000, 10809, 10808, 7897, 1080, 20171, 33210),
    [string]$ProbeUrl = 'http://ip-api.com/json?fields=status,country,city,query'
)

# Wayback, YouTube and Dailymotion are unreachable from mainland networks.
# Several helpers in this skill accept a -Proxy argument; feed them a verified one.

$found = @()
foreach ($p in $Ports) {
    $open = Test-NetConnection -ComputerName 127.0.0.1 -Port $p -InformationLevel Quiet -WarningAction SilentlyContinue
    if (-not $open) { continue }

    $px = "http://127.0.0.1:$p"
    $raw = (& curl.exe -s -x $px --max-time 10 $ProbeUrl 2>$null) -join ''
    $j = $null
    try { $j = $raw | ConvertFrom-Json } catch { }

    if ($j -and $j.status -eq 'success') {
        Write-Host ("port {0} OPEN   exit={1} ({2})" -f $p, $j.query, $j.country)
        $found += [PSCustomObject]@{ Port = $p; Proxy = $px; Country = $j.country; Exit = $j.query }
    }
    else {
        Write-Host ("port {0} OPEN   probe failed (dead node or auth required)" -f $p)
    }
}

if ($found.Count -eq 0) {
    Write-Host 'no usable proxy found; overseas sources will be unreachable'
}
else {
    Write-Host ''
    Write-Host 'use one of:'
    $found | ForEach-Object { Write-Host ("  -Proxy " + $_.Proxy) }
}
