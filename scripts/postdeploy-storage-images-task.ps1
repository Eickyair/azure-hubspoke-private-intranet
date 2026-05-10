$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Get-PythonPath {
    $command = Get-Command python.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) {
        return [string]$command.Source
    }

    if (-not (Get-Command choco.exe -ErrorAction SilentlyContinue)) {
        Write-Host 'Installing Chocolatey package manager...'
        Set-ExecutionPolicy Bypass -Scope Process -Force
        $chocoInstallOutput = Invoke-Expression ((New-Object Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        $chocoInstallOutput | ForEach-Object { Write-Host $_ }
        $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
    }

    Write-Host 'Installing Python runtime...'
    $pythonInstallOutput = & choco install python -y --no-progress
    $pythonInstallOutput | ForEach-Object { Write-Host $_ }
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')

    $command = Get-Command python.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) {
        return [string]$command.Source
    }

    throw 'python.exe was not found after installing Python.'
}

function Get-RequiredEnv {
    param([string]$Name)
    $value = [Environment]::GetEnvironmentVariable($Name, 'Process')
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Missing required environment value: $Name"
    }
    return $value
}

$pythonPath = Get-PythonPath
$workDir = Join-Path $env:TEMP 'postdeploy-storage-images'
New-Item -ItemType Directory -Force -Path $workDir | Out-Null

$scriptPath = Join-Path $workDir 'postdeploy-storage-images.py'
$stdoutPath = Join-Path $workDir 'postdeploy-storage-images.out.log'
$stderrPath = Join-Path $workDir 'postdeploy-storage-images.err.log'

$pythonScript = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String((Get-RequiredEnv 'POSTDEPLOY_IMAGE_SCRIPT_B64')))
[IO.File]::WriteAllText($scriptPath, $pythonScript, [Text.UTF8Encoding]::new($false))

Write-Host 'Installing Python dependencies...'
& $pythonPath -m pip install --disable-pip-version-check --quiet requests azure-storage-blob pymysql

Write-Host 'Running post-deploy image upload Python script...'
$process = Start-Process -FilePath $pythonPath `
    -ArgumentList @($scriptPath) `
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
    throw "Post-deploy image upload failed with exit code $($process.ExitCode)."
}