<#
Vana'diel 2003 lab launcher: the lab's own database, the LandSandBoat server with era2003, then the
2003 client. Everything it starts is recorded so -Stop can end exactly that.

  Vanadiel2003.ps1            start what is not running, then the client (when one is built)
  Vanadiel2003.ps1 -Server    the database and server only
  Vanadiel2003.ps1 -Stop      stop the client, server and database this lab started
  Vanadiel2003.ps1 -Status    what is running
  -NoPause                    do not wait for Enter at the end (scripts)

Configuration: lab.json beside this script (paths), lab-credentials.json (the lab database).
#>
param([switch]$Server, [switch]$Stop, [switch]$Status, [switch]$NoPause)

$ErrorActionPreference = 'Stop'
$Lab = Split-Path -Parent $MyInvocation.MyCommand.Path
$Cfg = Get-Content (Join-Path $Lab 'lab.json') -Raw | ConvertFrom-Json
$Cred = Get-Content (Join-Path $Lab 'lab-credentials.json') -Raw | ConvertFrom-Json
$Logs = Join-Path $Lab 'logs'
$PidFile = Join-Path $Lab 'running.json'
New-Item -ItemType Directory -Force $Logs | Out-Null

function Say($text, $color = 'Gray') { Write-Host $text -ForegroundColor $color }

function Listening($port) {
    [bool](Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue)
}

function Recorded {
    if (Test-Path $PidFile) { Get-Content $PidFile -Raw | ConvertFrom-Json } else { [pscustomobject]@{} }
}

function Remember($name, $proc) {
    $r = Recorded
    $r | Add-Member -Force -NotePropertyName $name -NotePropertyValue $proc.Id
    $r | ConvertTo-Json | Set-Content -Encoding utf8 $PidFile
}

function Alive($name) {
    $id = (Recorded).$name
    if (-not $id) { return $null }
    Get-Process -Id $id -ErrorAction SilentlyContinue
}

function Start-Database {
    if (Listening $Cred.sql_port) { Say "database: already running (port $($Cred.sql_port))"; return }
    $ini = Join-Path $Lab 'db\my.ini'
    $p = Start-Process -PassThru -WindowStyle Hidden (Join-Path $Cfg.mariadb_bin 'mariadbd.exe') -ArgumentList "--defaults-file=`"$ini`""
    Remember 'database' $p
    for ($i = 0; $i -lt 40 -and -not (Listening $Cred.sql_port); $i++) { Start-Sleep -Milliseconds 250 }
    if (-not (Listening $Cred.sql_port)) { throw "the lab database did not start: see $Logs\mariadb.err" }
    Say "database: started (port $($Cred.sql_port))" Green
}

function Start-ServerProcess($name, $exe, $port) {
    if (Alive $name) { Say "${name}: already running"; return }
    $env:XI_NETWORK_SQL_HOST = $Cred.sql_host
    $env:XI_NETWORK_SQL_PORT = "$($Cred.sql_port)"
    $env:XI_NETWORK_SQL_DATABASE = $Cred.sql_database
    $env:XI_NETWORK_SQL_LOGIN = $Cred.sql_login
    $env:XI_NETWORK_SQL_PASSWORD = $Cred.sql_password
    $p = Start-Process -PassThru -WindowStyle Minimized -WorkingDirectory $Cfg.server_root (Join-Path $Cfg.server_root $exe) `
        -RedirectStandardOutput (Join-Path $Logs "$name.log") -RedirectStandardError (Join-Path $Logs "$name.err.log")
    Remember $name $p
    Say "${name}: started" Green
}

function Start-Server {
    Start-Database
    Start-ServerProcess 'connect' 'xi_connect.exe'
    Start-ServerProcess 'world' 'xi_world.exe'
    Start-ServerProcess 'map' 'xi_map.exe'
    Say "server: waiting for the map server to load its zones (about a minute the first time)..."
    for ($i = 0; $i -lt 240; $i++) {
        if (-not (Alive 'map')) { throw "the map server exited: see $Logs\map.log" }
        if (Select-String -Quiet -Path (Join-Path $Logs 'map.log') -Pattern 'server is ready to work') { break }
        Start-Sleep -Milliseconds 500
    }
    Say "server: ready" Green
}

function Start-Client {
    $host64 = Join-Path $Lab 'game\host64.exe'
    if (-not (Test-Path $host64)) {
        Say ""
        Say "The 2003 client is not built into this lab yet (game\host64.exe)." Yellow
        Say "The server is running; see README.md, 'What works', for where the client stands." Yellow
        return
    }
    $module = Join-Path $Lab 'game\xi_game.dll'
    $p = Start-Process -PassThru -WorkingDirectory (Join-Path $Lab 'game') $host64 `
        -ArgumentList '--game', "`"$($Cfg.game_folder)`"", '--module', "`"$module`"", '--images', "`"$(Join-Path $Lab 'game')`"" `
        -RedirectStandardError (Join-Path $Logs 'client.log')
    Remember 'client' $p
    Say "client: started" Green
}

function Stop-All {
    $r = Recorded
    foreach ($name in 'client', 'map', 'world', 'connect', 'database') {
        $p = Alive $name
        if ($p) { Stop-Process -Id $p.Id -Force; Say "${name}: stopped" }
    }
    Remove-Item -ErrorAction SilentlyContinue $PidFile
}

function Show-Status {
    foreach ($name in 'database', 'connect', 'world', 'map', 'client') {
        $p = Alive $name
        if ($p) { Say ("{0,-9} running (pid {1})" -f $name, $p.Id) Green } else { Say ("{0,-9} stopped" -f $name) }
    }
}

try {
    if ($Stop) { Stop-All; return }
    if ($Status) { Show-Status; return }
    Say "Vana'diel 2003 lab" Cyan
    Start-Server
    if (-not $Server) { Start-Client }
} catch {
    Say $_.Exception.Message Red
}
if (-not $Stop -and -not $Status -and -not $NoPause) { Say ""; Read-Host "Press Enter to close this window (the server keeps running; -Stop ends it)" | Out-Null }
