# Moonbound: run every test, one at a time, and print one PASS/FAIL report.
#   powershell -ExecutionPolicy Bypass -File tests\run_tests.ps1
# Optional: pass a name filter, e.g.  ... run_tests.ps1 crew   (runs test_crew_screen only)
# Set GODOT to your Godot console exe if it is not at the default path.
# Tests open a small window far off screen and never take focus. Do NOT run two at once.
param([string]$Filter = "")

$godot = $env:GODOT
if (-not $godot) { $godot = "C:\Users\sarah\Documents\Godot\Godot_v4.7.2-stable_win64_console.exe" }
if (-not (Test-Path $godot)) { Write-Host "Godot not found at $godot. Set the GODOT environment variable."; exit 2 }

$project = Split-Path -Parent $PSScriptRoot
$out = Join-Path $PSScriptRoot "out"
New-Item -ItemType Directory -Force $out | Out-Null
# New class_name scripts are only known after Godot has scanned the project, so scan first (quick)
& $godot --headless --path $project --import | Out-Null
$tests = Get-ChildItem (Join-Path $PSScriptRoot "test_*.gd") | Where-Object { $_.BaseName -like "*$Filter*" } | Sort-Object Name
$rows = @()
$failed = 0
$count = 0
foreach ($t in $tests) {
	# the layout test runs at several window sizes: small laptop, full HD, ultrawide, tall
	$sizes = @("1280x720")
	if ($t.BaseName -eq "test_layout") { $sizes = @("1280x720", "1920x1080", "2560x1080", "1280x1024") }
	foreach ($size in $sizes) {
		$count++
		$label = if ($sizes.Count -gt 1) { "$($t.BaseName) $size" } else { $t.BaseName }
		$log = Join-Path $out (($label -replace " ", "_") + ".log")
		$sw = [Diagnostics.Stopwatch]::StartNew()
		$p = Start-Process -FilePath $godot -ArgumentList @("--path", $project, "--position", "6000,3000", "--resolution", $size, "--script", "res://tests/$($t.Name)", "--", $size) -RedirectStandardOutput $log -RedirectStandardError ($log + ".err") -PassThru -WindowStyle Hidden
		$null = $p.Handle   # keep the handle so ExitCode is readable after the process ends
		if (-not $p.WaitForExit(240000)) { $p.Kill(); $status = "TIMEOUT" }
		else {
			$p.WaitForExit()
			$text = Get-Content $log -Raw -ErrorAction SilentlyContinue
			$errtext = Get-Content ($log + ".err") -Raw -ErrorAction SilentlyContinue
			$bad = ([regex]::Matches($text, "(?m)^FAIL ")).Count
			$scriptErr = ([regex]::Matches(($text + $errtext), "SCRIPT ERROR|Parse Error")).Count
			$done = $text -match "(?m)^FAILS: 0\s*$"
			if ($done -and $bad -eq 0 -and $scriptErr -eq 0) { $status = "PASS" }
			else { $status = "FAIL ($bad failed checks, $scriptErr script errors, finished: $done)" }
		}
		if ($status -ne "PASS") { $failed++ }
		$rows += ("{0,-30} {1,-6}s  {2}" -f $label, [int]$sw.Elapsed.TotalSeconds, $status)
		Write-Host $rows[-1]
	}
}
$summary = "Moonbound tests: $($count - $failed) of $count passed"
Write-Host $summary
try { ($rows + $summary) | Set-Content (Join-Path $out "report.txt") -ErrorAction Stop } catch { Write-Host "(could not write report.txt)" }
Write-Host "Logs and screenshots: $out"
exit $failed
