$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Get-RequiredEnv {
    param([string]$Name)
    $value = [Environment]::GetEnvironmentVariable($Name, 'Process')
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Missing required environment value: $Name"
    }
    return $value
}

function Get-RequiredEnvText {
    param([string]$Name)
    return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String((Get-RequiredEnv $Name)))
}

$Task = Get-RequiredEnvText 'POSTDEPLOY_TASK_B64'
$AppHost = Get-RequiredEnvText 'POSTDEPLOY_APP_HOST_B64'
$AdminHost = Get-RequiredEnvText 'POSTDEPLOY_ADMIN_HOST_B64'
$AppDatabase = Get-RequiredEnvText 'POSTDEPLOY_APP_DATABASE_B64'
$AdminDatabase = Get-RequiredEnvText 'POSTDEPLOY_ADMIN_DATABASE_B64'
$MysqlUser = Get-RequiredEnvText 'POSTDEPLOY_MYSQL_USER_B64'
$MysqlPassword = Get-RequiredEnvText 'POSTDEPLOY_MYSQL_PASSWORD_B64'
$AdminSchemaB64 = Get-RequiredEnv 'POSTDEPLOY_ADMIN_SCHEMA_B64'
$CatalogSchemaB64 = Get-RequiredEnv 'POSTDEPLOY_CATALOG_SCHEMA_B64'
$AdminSeedB64 = Get-RequiredEnv 'POSTDEPLOY_ADMIN_SEED_B64'
$CatalogSeedB64 = Get-RequiredEnv 'POSTDEPLOY_CATALOG_SEED_B64'

if ($Task -notin @('schema', 'seed', 'verify', 'all', 'reset-demo')) {
    throw "Unsupported task: $Task"
}

function Get-MySqlClientPath {
    $command = Get-Command mysql.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) {
        return [string]$command.Source
    }

    $candidatePaths = @(
        'C:\Program Files\MariaDB*\bin\mysql.exe',
        'C:\Program Files\MySQL\MySQL Server *\bin\mysql.exe',
        'C:\tools\mariadb*\bin\mysql.exe'
    )

    foreach ($candidate in $candidatePaths) {
        $match = Get-ChildItem -Path $candidate -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($match) {
            return [string]$match.FullName
        }
    }

    if (-not (Get-Command choco.exe -ErrorAction SilentlyContinue)) {
        Write-Host 'Installing Chocolatey package manager...'
        Set-ExecutionPolicy Bypass -Scope Process -Force
        $chocoInstallOutput = Invoke-Expression ((New-Object Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        $chocoInstallOutput | ForEach-Object { Write-Host $_ }
        $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
    }

    Write-Host 'Installing MariaDB client...'
    $mariadbInstallOutput = & choco install mariadb -y --no-progress
    $mariadbInstallOutput | ForEach-Object { Write-Host $_ }
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')

    $command = Get-Command mysql.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) {
        return [string]$command.Source
    }

    foreach ($candidate in $candidatePaths) {
        $match = Get-ChildItem -Path $candidate -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($match) {
            return [string]$match.FullName
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
        '--ssl',
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

    $stdoutContent = if (Test-Path $stdoutPath) { Get-Content -Raw -Path $stdoutPath } else { $null }
    $stderrContent = if (Test-Path $stderrPath) { Get-Content -Raw -Path $stderrPath } else { $null }
    $stdout = if ($null -eq $stdoutContent) { '' } else { [string]$stdoutContent }
    $stderr = if ($null -eq $stderrContent) { '' } else { [string]$stderrContent }

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
    Invoke-MySqlScript -HostName $AppHost -DatabaseName $AppDatabase -Sql 'DELETE FROM sales_history;' -Label 'catalog-sales-reset-demo'
    Invoke-MySqlScript -HostName $AdminHost -DatabaseName $AdminDatabase -Sql 'SET FOREIGN_KEY_CHECKS=0; DELETE FROM employees; ALTER TABLE employees AUTO_INCREMENT = 1; SET FOREIGN_KEY_CHECKS=1;' -Label 'admin-reset-demo'
    Invoke-MySqlScript -HostName $AppHost -DatabaseName $AppDatabase -Sql 'DELETE FROM products; ALTER TABLE products AUTO_INCREMENT = 1; ALTER TABLE sales_history AUTO_INCREMENT = 1;' -Label 'catalog-reset-demo'
}

if ($Task -in @('seed', 'all', 'reset-demo')) {
    Invoke-MySqlScript -HostName $AdminHost -DatabaseName $AdminDatabase -Sql $adminSeed -Label 'admin-seed'
    Invoke-MySqlScript -HostName $AppHost -DatabaseName $AppDatabase -Sql $catalogSeed -Label 'catalog-seed'
}

if ($Task -in @('verify', 'all', 'reset-demo')) {
    Invoke-MySqlScript -HostName $AdminHost -DatabaseName $AdminDatabase -Sql "SELECT 'employees' AS table_name, COUNT(*) AS rows_count FROM employees;" -Label 'admin-verify'
    Invoke-MySqlScript -HostName $AppHost -DatabaseName $AppDatabase -Sql "SELECT 'products' AS table_name, COUNT(*) AS rows_count FROM products UNION ALL SELECT 'sales_history', COUNT(*) FROM sales_history;" -Label 'catalog-verify'
}

Write-Host "Post-deploy database task '$Task' completed."