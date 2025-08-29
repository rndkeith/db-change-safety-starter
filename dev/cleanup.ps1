#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Clean shutdown script for the development environment
    
.DESCRIPTION
    Stops and removes all containers, networks, and volumes for the db-change-safety-starter
    development environment, regardless of which profiles were used to start them.
    
.PARAMETER RemoveVolumes
    If specified, also removes persistent volumes (data loss!)
    
.PARAMETER Force
    If specified, forces removal without confirmation prompts
    
.EXAMPLE
    .\cleanup.ps1
    Stop all containers and networks, keep data volumes
    
.EXAMPLE
    .\cleanup.ps1 -RemoveVolumes
    Stop everything and remove data volumes (complete reset)
#>

param(
    [switch]$RemoveVolumes,
    [switch]$Force
)

$ErrorActionPreference = "Continue"  # Don't stop on individual container errors
Set-StrictMode -Version Latest

# Colors for output
$Colors = @{
    Info    = "Cyan"
    Success = "Green"
    Warning = "Yellow"
    Error   = "Red"
}

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "Info")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor $Colors[$Color]
}

function Stop-AllProfiles {
    Write-ColorOutput "Stopping containers for all profiles..." "Info"
    
    # Stop containers for each profile
    $profiles = @("migration", "cache", "monitoring", "gui")
    
    foreach ($profile in $profiles) {
        Write-ColorOutput "Stopping profile: $profile" "Info"
        docker compose --profile $profile down 2>$null
    }
    
    # Stop base containers (no profile)
    Write-ColorOutput "Stopping base containers..." "Info"
    docker compose down 2>$null
}

function Remove-ProjectContainers {
    Write-ColorOutput "Finding and removing project containers..." "Info"
    
    # Get all containers with our project prefix
    $containers = docker ps -a --filter "name=db-dev-" --format "{{.Names}}" 2>$null
    
    if ($containers) {
        Write-ColorOutput "Found containers: $($containers -join ', ')" "Info"
        
        foreach ($container in $containers) {
            Write-ColorOutput "Removing container: $container" "Info"
            docker rm -f $container 2>$null
        }
    } else {
        Write-ColorOutput "No project containers found" "Info"
    }
}

function Remove-ProjectNetworks {
    Write-ColorOutput "Removing project networks..." "Info"
    
    $networks = docker network ls --filter "name=dev_db-dev-network" --format "{{.Name}}" 2>$null
    
    if ($networks) {
        foreach ($network in $networks) {
            Write-ColorOutput "Removing network: $network" "Info"
            docker network rm $network 2>$null
        }
    } else {
        Write-ColorOutput "No project networks found" "Info"
    }
}

function Remove-ProjectVolumes {
    if (-not $RemoveVolumes) {
        Write-ColorOutput "Skipping volume removal (use -RemoveVolumes to remove data)" "Warning"
        return
    }
    
    if (-not $Force) {
        $confirmation = Read-Host "This will remove all data volumes. Are you sure? (y/N)"
        if ($confirmation -notmatch "^[Yy]$") {
            Write-ColorOutput "Volume removal cancelled" "Info"
            return
        }
    }
    
    Write-ColorOutput "Removing project volumes..." "Warning"
    
    $volumes = docker volume ls --filter "name=dev_" --format "{{.Name}}" 2>$null
    
    if ($volumes) {
        foreach ($volume in $volumes) {
            Write-ColorOutput "Removing volume: $volume" "Warning"
            docker volume rm $volume 2>$null
        }
    } else {
        Write-ColorOutput "No project volumes found" "Info"
    }
}

function Show-Status {
    Write-ColorOutput "Current Docker status:" "Info"
    
    Write-ColorOutput "Running containers:" "Info"
    $runningContainers = docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>$null
    if ($runningContainers) {
        Write-Output $runningContainers
    } else {
        Write-ColorOutput "No running containers" "Success"
    }
    
    Write-ColorOutput "`nProject volumes:" "Info"
    $volumes = docker volume ls --filter "name=dev_" --format "table {{.Name}}\t{{.Size}}" 2>$null
    if ($volumes) {
        Write-Output $volumes
    } else {
        Write-ColorOutput "No project volumes" "Success"
    }
}

# Main execution
try {
    Write-ColorOutput "=== DB Development Environment Cleanup ===" "Info"
    
    # Stop all profile-based containers
    Stop-AllProfiles
    
    # Remove any remaining project containers
    Remove-ProjectContainers
    
    # Remove project networks
    Remove-ProjectNetworks
    
    # Remove volumes if requested
    Remove-ProjectVolumes
    
    # Clean up unused Docker resources
    Write-ColorOutput "Cleaning up unused Docker resources..." "Info"
    docker system prune -f 2>$null
    
    Write-ColorOutput "=== Cleanup Complete ===" "Success"
    
    # Show final status
    Show-Status
    
    Write-ColorOutput "`nTo restart the environment:" "Info"
    Write-ColorOutput "  .\init-db.ps1" "Info"
    Write-ColorOutput "`nTo start with monitoring:" "Info"
    Write-ColorOutput "  docker compose --profile monitoring up -d" "Info"
    
} catch {
    Write-ColorOutput "Cleanup failed: $($_.Exception.Message)" "Error"
    exit 1
}
