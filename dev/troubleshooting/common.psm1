# Common troubleshooting helpers for dev SQL Server environment

function Write-Log {
    param(
        [Parameter(Mandatory=$true)][string]$Message,
        [ValidateSet('INFO','WARN','ERROR','SUCCESS','DETAIL')][string]$Level = 'INFO'
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $color = switch ($Level) {
        'ERROR' { 'Red' }
        'WARN' { 'Yellow' }
        'SUCCESS' { 'Green' }
        'DETAIL' { 'Gray' }
        default { 'Cyan' }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-SqlConnection {
    param(
        [string]$ConnectionString = 'Server=localhost,1433;Initial Catalog=master;User Id=sa;Password=DevPassword123!;TrustServerCertificate=True;Connection Timeout=10'
    )
    try {
        $conn = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
        $conn.Open()
        $conn.Close()
        return $true
    } catch {
        Write-Log "Connection failed: $($_.Exception.Message)" 'WARN'
        return $false
    }
}

function Get-ContainerHealth {
    param([string]$Name = 'db-dev-sqlserver')
    $state = docker inspect $Name --format '{{json .State}}' 2>$null | ConvertFrom-Json
    if (-not $state) {
        return @{ Exists = $false; Status = 'not-found'; Health = 'unknown' }
    }
    return @{ Exists = $true; Status = $state.Status; Health = ($state.Health.Status) }
}

function Wait-For-Health {
    param(
        [string]$Name = 'db-dev-sqlserver',
        [int]$TimeoutSeconds = 180,
        [int]$PollSeconds = 5
    )
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $h = Get-ContainerHealth -Name $Name
        $level = 'INFO'
        if ($h.Health -eq 'healthy') {
            $level = 'SUCCESS'
        } elseif ($h.Health -eq 'starting') {
            $level = 'WARN'
        } elseif ($h.Health -eq 'unhealthy') {
            $level = 'ERROR'
        }
        $message = "Container: $($h.Status) | Health: $($h.Health)"
        Write-Log $message $level
        if ($h.Health -eq 'healthy') { return $true }
        Start-Sleep -Seconds $PollSeconds
    }
    return $false
}

Export-ModuleMember -Function Write-Log, Test-SqlConnection, Get-ContainerHealth, Wait-For-Health
