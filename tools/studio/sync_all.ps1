# Live sync for the three Studio places (match, lobby, art): for each, the
# Lune converter and `rojo serve` in their own worktree, on the place's port.
# Folders, commands and ports are in places.json next to this script
# (folders relative to this repo's root).
#
#   powershell -ExecutionPolicy Bypass -File tools/studio/sync_all.ps1 [match] [lobby] [art]
#
# No names: all three. Opens one Windows Terminal window ("ftgg-sync") with a
# tab per process (plain PowerShell windows without Windows Terminal). A place
# whose port is already listening is skipped (its sync is already running).
# Rojo starts only once the converter has written its output folder: Rojo
# crashes on a watched folder that doesn't exist. Stop a sync with Ctrl+C in
# both of its tabs (Rojo first). Then connect the Rojo plugin in each Studio
# window to its port.

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "../..")
$config = Get-Content (Join-Path $PSScriptRoot "places.json") -Raw | ConvertFrom-Json
$wt = Get-Command wt -ErrorAction SilentlyContinue

$wanted = @($args)
$places = @($config.places | Where-Object { $wanted.Count -eq 0 -or $wanted -contains $_.name })
if ($places.Count -eq 0) {
	Write-Host "No place named $($wanted -join ', '); known: $(($config.places | ForEach-Object { $_.name }) -join ', ')"
	exit 1
}

function Open-Tab([string]$title, [string]$dir, [string]$command) {
	if ($wt) {
		# no ';' in $command: Windows Terminal reads it as a new subcommand
		Start-Process wt -ArgumentList @("-w", "ftgg-sync", "new-tab", "--title", "`"$title`"", "-d", "`"$dir`"", "powershell", "-NoExit", "-Command", $command)
	} else {
		Start-Process powershell -WorkingDirectory $dir -ArgumentList @("-NoExit", "-Command", "`$Host.UI.RawUI.WindowTitle = '$title'", ";", $command)
	}
}

$started = @()
foreach ($p in $places) {
	$dir = [System.IO.Path]::GetFullPath((Join-Path $root $p.folder))
	if (-not (Test-Path (Join-Path $dir $p.project))) {
		Write-Host "[$($p.name)] skipped: no $($p.project) in $dir"
		continue
	}
	if (Get-NetTCPConnection -State Listen -LocalPort $p.port -ErrorAction SilentlyContinue) {
		Write-Host "[$($p.name)] skipped: port $($p.port) is already listening (sync running?)"
		continue
	}
	$branch = (git -C $dir branch --show-current) 2>$null
	Write-Host "[$($p.name)] $dir ($branch): $($p.convert), then rojo serve $($p.project) --port $($p.port)"
	Open-Tab "$($p.name): lune" $dir $p.convert
	$started += [pscustomobject]@{ place = $p; dir = $dir }
}

foreach ($s in $started) {
	$p = $s.place
	$out = Join-Path $s.dir $p.convertOut
	$deadline = (Get-Date).AddSeconds(60)
	while (-not (Test-Path $out) -and (Get-Date) -lt $deadline) {
		Start-Sleep -Milliseconds 500
	}
	if (-not (Test-Path $out)) {
		Write-Host "[$($p.name)] rojo not started: $out still missing after 60 s (see the lune tab)"
		continue
	}
	Open-Tab "$($p.name): rojo $($p.port)" $s.dir "rojo serve $($p.project) --port $($p.port)"
}

Write-Host ""
Write-Host "Connect the Rojo plugin in each Studio window:"
foreach ($s in $started) {
	Write-Host ("  {0,-6} port {1}  ->  {2}" -f $s.place.name, $s.place.port, $s.place.studio)
}
