<#
Sets up a Vana'diel 2003 lab: a private MariaDB instance (its own data folder and port, bound to
127.0.0.1), the LandSandBoat database with the era2003 module, the launcher and its config, and a
desktop shortcut. Nothing outside -Lab is changed except the shortcut; an existing MariaDB service
and its databases are left alone.

  setup.ps1 -Server <LandSandBoat checkout> [-Lab C:\Vanadiel2003] [-Port 33062]
            [-MariaDB "C:\Program Files\MariaDB 12.3\bin"]
            [-Game "<FINAL FANTASY XI 2003 folder>"] [-NoShortcut]

The checkout must have modules/era2003 and list it in modules/init.txt (with era/lua and era/data),
and settings/main.lua copied from modules/era2003/settings/main.lua.example.
#>
param(
    [Parameter(Mandatory = $true)][string]$Server,
    [string]$Lab = 'C:\Vanadiel2003',
    [int]$Port = 33062,
    [string]$MariaDB = 'C:\Program Files\MariaDB 12.3\bin',
    [string]$Game = 'C:\Program Files (x86)\PlayOnline\SquareEnix\FINAL FANTASY XI',
    [switch]$NoShortcut
)
$ErrorActionPreference = 'Stop'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Database = 'xidb2003'

function Say($text, $color = 'Gray') { Write-Host $text -ForegroundColor $color }
function NewPassword { -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 24 | ForEach-Object { [char]$_ }) }
function Sql($user, $pw, $text, $db = '') {
    $a = @('--host=127.0.0.1', "--port=$Port", "--user=$user", "--password=$pw")
    if ($db) { $a += $db }
    $a += "--execute=$text"
    & (Join-Path $MariaDB 'mysql.exe') @a
    if ($LASTEXITCODE) { throw "SQL failed: $text" }
}

if (-not (Test-Path (Join-Path $Server 'modules\era2003'))) { throw "$Server has no modules\era2003" }
if (-not (Test-Path (Join-Path $Server 'settings\main.lua'))) {
    throw "$Server\settings\main.lua missing: copy modules\era2003\settings\main.lua.example there"
}
if (Test-Path (Join-Path $Lab 'db')) { throw "$Lab\db already exists: this lab is set up (delete it to start over)" }

New-Item -ItemType Directory -Force (Join-Path $Lab 'logs') | Out-Null
$root = NewPassword
$xi = NewPassword

Say "database: initialising $Lab\db (port $Port)"
& (Join-Path $MariaDB 'mariadb-install-db.exe') "--datadir=$Lab\db" "--port=$Port" "--password=$root" | Out-Null
$labFwd = $Lab -replace '\\', '/'
$mariaFwd = ($MariaDB -replace '\\', '/') -replace '/bin$', ''
@"
[mysqld]
datadir=$labFwd/db
port=$Port
bind-address=127.0.0.1
log-error=$labFwd/logs/mariadb.err
[client]
port=$Port
plugin-dir=$mariaFwd/lib/plugin
"@ | Set-Content -Encoding ascii (Join-Path $Lab 'db\my.ini')

[pscustomobject]@{ sql_host = '127.0.0.1'; sql_port = $Port; sql_database = $Database; sql_root_password = $root
    sql_login = 'xiadmin'; sql_password = $xi } | ConvertTo-Json | Set-Content -Encoding utf8 (Join-Path $Lab 'lab-credentials.json')
[pscustomobject]@{ server_root = $Server; mariadb_bin = $MariaDB; game_folder = $Game } |
    ConvertTo-Json | Set-Content -Encoding utf8 (Join-Path $Lab 'lab.json')
Copy-Item (Join-Path $Here 'Vanadiel2003.ps1') $Lab -Force

$db = Start-Process -PassThru -WindowStyle Hidden (Join-Path $MariaDB 'mariadbd.exe') -ArgumentList "--defaults-file=`"$Lab\db\my.ini`""
try {
    for ($i = 0; $i -lt 40 -and -not (Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue); $i++) {
        Start-Sleep -Milliseconds 250
    }
    foreach ($h in '127.0.0.1', 'localhost') {
        Sql root $root "CREATE USER 'xiadmin'@'$h' IDENTIFIED BY '$xi'; GRANT ALL PRIVILEGES ON $Database.* TO 'xiadmin'@'$h'; GRANT CREATE ON *.* TO 'xiadmin'@'$h';"
    }

    Say "database: importing LandSandBoat with era2003 (a few minutes)"
    $env:XI_NETWORK_SQL_HOST = '127.0.0.1'
    $env:XI_NETWORK_SQL_PORT = "$Port"
    $env:XI_NETWORK_SQL_DATABASE = $Database
    $env:XI_NETWORK_SQL_LOGIN = 'xiadmin'
    $env:XI_NETWORK_SQL_PASSWORD = $xi
    Push-Location $Server
    try { python tools\dbtool.py setup $Database | Select-String -NotMatch '^Importing' } finally { Pop-Location }

    # LandSandBoat's era SQL, statement by statement: some of it writes columns this LandSandBoat no
    # longer has, and dbtool stops at the first failure. What does not fit is logged, not fatal.
    Say "database: applying LandSandBoat's era SQL"
    $log = Join-Path $Lab 'logs\era-sql.log'
    Remove-Item -ErrorAction SilentlyContinue $log
    $failed = 0
    $ErrorActionPreference = 'Continue'  # mysql's stderr is expected here (Windows PowerShell 5.1 would stop on it)
    Get-ChildItem (Join-Path $Server 'modules\era\sql') -Recurse -Filter *.sql | Sort-Object FullName | ForEach-Object {
        $out = Get-Content -Raw $_.FullName | & (Join-Path $MariaDB 'mysql.exe') --host=127.0.0.1 "--port=$Port" --user=root "--password=$root" --force $Database 2>&1
        $errs = @($out | Where-Object { "$_" -match '^ERROR' })
        if ($errs.Count) { $failed += $errs.Count; Add-Content $log ("== " + $_.FullName); $errs | Add-Content $log }
    }
    Say ("database: era SQL applied; {0} statements no longer fit (see logs\era-sql.log)" -f $failed)
    Say ("database: {0} zones" -f ((& (Join-Path $MariaDB 'mysql.exe') --host=127.0.0.1 "--port=$Port" --user=root "--password=$root" --skip-column-names $Database '--execute=SELECT COUNT(*) FROM zone_settings')))
} finally {
    Stop-Process -Id $db.Id -Force
}

if (-not $NoShortcut) {
    $sh = New-Object -ComObject WScript.Shell
    $ps = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $icon = Join-Path $Game 'ToolsUS\FINAL FANTASY XI Config.exe'
    foreach ($s in @(@{ path = Join-Path ([Environment]::GetFolderPath('Desktop')) "Vana'diel 2003.lnk"; args = '' },
                     @{ path = Join-Path $Lab 'Stop the lab.lnk'; args = ' -Stop' })) {
        $l = $sh.CreateShortcut($s.path)
        $l.TargetPath = $ps
        $l.Arguments = "-NoLogo -ExecutionPolicy Bypass -File `"$Lab\Vanadiel2003.ps1`"$($s.args)"
        $l.WorkingDirectory = $Lab
        if (Test-Path $icon) { $l.IconLocation = "$icon,0" }
        $l.Save()
    }
    Say "shortcut: Vana'diel 2003 on the desktop"
}
Say "lab ready: $Lab" Green
