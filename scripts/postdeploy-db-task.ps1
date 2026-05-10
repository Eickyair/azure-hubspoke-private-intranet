param(
    [ValidateSet('schema', 'seed', 'verify', 'all', 'reset-demo')]
    [string]$Task = 'all',
    [Parameter(Mandatory = $true)] [string]$AppHost,
    [Parameter(Mandatory = $true)] [string]$AdminHost,
    [Parameter(Mandatory = $true)] [string]$AppDatabase,
    [Parameter(Mandatory = $true)] [string]$AdminDatabase,
    [Parameter(Mandatory = $true)] [string]$MysqlUser,
    [Parameter(Mandatory = $true)] [string]$MysqlPassword,
    [Parameter(Mandatory = $true)] [string]$AdminSchemaB64,
    [Parameter(Mandatory = $true)] [string]$CatalogSchemaB64,
    [Parameter(Mandatory = $true)] [string]$AdminSeedB64,
    [Parameter(Mandatory = $true)] [string]$CatalogSeedB64
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Get-MySqlClientPath {
    $command = Get-Command mysql.exe -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $candidatePaths = @(
        'C:\Program Files\MariaDB*\bin\mysql.exe',
        'C:\Program Files\MySQL\MySQL Server *\bin\mysql.exe',
        'C:\tools\mariadb*\bin\mysql.exe'
    )

    foreach ($candidate in $candidatePaths) {
        $match = Get-ChildItem -Path $candidate -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($match) {
            return $match.FullName
        }
    }

    if (-not (Get-Command choco.exe -ErrorAction SilentlyContinue)) {
        Write-Host 'Installing Chocolatey package manager...'
        Set-ExecutionPolicy Bypass -Scope Process -Force
        Invoke-Expression ((New-Object Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
    }

    Write-Host 'Installing MariaDB client...'
    choco install mariadb -y --no-progress | Write-Host
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')

    $command = Get-Command mysql.exe -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    foreach ($candidate in $candidatePaths) {
        $match = Get-ChildItem -Path $candidate -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($match) {
            return $match.FullName
        }
    }

    throw 'mysql.exe was not found after installing MariaDB client.'
}

function ConvertFrom-Base64Sql {
    param([string]$Value)
    return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Value))
}

function Invoke-MySqlScript {
    param(
        [string]$HostName,
        [string]$DatabaseName,
        [string]$Sql,
        [string]$Label
    )

    $mysqlPath = Get-MySqlClientPath
    $workDir = Join-Path $env:TEMP 'postdeploy-db'
    New-Item -ItemType Directory -Force -Path $workDir | Out-Null

    $inputPath = Join-Path $workDir "$($Label).sql"
    $stdoutPath = Join-Path $workDir "$($Label).out.log"
    $stderrPath = Join-Path $workDir "$($Label).err.log"

    [IO.File]::WriteAllText($inputPath, $Sql, [Text.UTF8Encoding]::new($false))

    Write-Host "Running $Label on $HostName/$DatabaseName"
    $arguments = @(
        "--host=$HostName",
        '--port=3306',
        "--user=$MysqlUser",
        "--password=$MysqlPassword",
        '--ssl-mode=REQUIRED',
        '--default-character-set=utf8mb4',
        $DatabaseName
    )

    $process = Start-Process -FilePath $mysqlPath `
        -ArgumentList $arguments `
        -RedirectStandardInput $inputPath `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath `
        -NoNewWindow `
        -Wait `
        -PassThru

    $stdout = if (Test-Path $stdoutPath) { Get-Content -Raw -Path $stdoutPath } else { '' }
    $stderr = if (Test-Path $stderrPath) { Get-Content -Raw -Path $stderrPath } else { '' }

    if ($stdout.Trim()) {
        Write-Host $stdout.Trim()
    }
    if ($stderr.Trim()) {
        Write-Host $stderr.Trim()
    }
    if ($process.ExitCode -ne 0) {
        throw "MySQL task '$Label' failed with exit code $($process.ExitCode)."
    }
}

$adminSchema = ConvertFrom-Base64Sql $AdminSchemaB64
$catalogSchema = ConvertFrom-Base64Sql $CatalogSchemaB64
$adminSeed = ConvertFrom-Base64Sql $AdminSeedB64
$catalogSeed = ConvertFrom-Base64Sql $CatalogSeedB64

if ($Task -in @('schema', 'all')) {
    Invoke-MySqlScript -HostName $AdminHost -DatabaseName $AdminDatabase -Sql $adminSchema -Label 'admin-schema'
    Invoke-MySqlScript -HostName $AppHost -DatabaseName $AppDatabase -Sql $catalogSchema -Label 'catalog-schema'
}

if ($Task -eq 'reset-demo') {
    Invoke-MySqlScript -HostName $AdminHost -DatabaseName $AdminDatabase -Sql 'DELETE FROM employees;' -Label 'admin-reset-demo'
    Invoke-MySqlScript -HostName $AppHost -DatabaseName $AppDatabase -Sql 'DELETE FROM products;' -Label 'catalog-reset-demo'
}

if ($Task -in @('seed', 'all', 'reset-demo')) {
    Invoke-MySqlScript -HostName $AdminHost -DatabaseName $AdminDatabase -Sql $adminSeed -Label 'admin-seed'
    Invoke-MySqlScript -HostName $AppHost -DatabaseName $AppDatabase -Sql $catalogSeed -Label 'catalog-seed'
}

if ($Task -in @('verify', 'all', 'reset-demo')) {
    Invoke-MySqlScript -HostName $AdminHost -DatabaseName $AdminDatabase -Sql "SELECT 'employees' AS table_name, COUNT(*) AS rows_count FROM employees;" -Label 'admin-verify'
    Invoke-MySqlScript -HostName $AppHost -DatabaseName $AppDatabase -Sql "SELECT 'products' AS table_name, COUNT(*) AS rows_count FROM products;" -Label 'catalog-verify'
}

Write-Host "Post-deploy database task '$Task' completed."