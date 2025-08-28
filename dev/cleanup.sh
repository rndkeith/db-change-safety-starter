#!/bin/bash

# Clean shutdown script for the development environment
# Stops and removes all containers, networks, and volumes for the db-change-safety-starter

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default options
REMOVE_VOLUMES=false
FORCE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--remove-volumes)
            REMOVE_VOLUMES=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  -v, --remove-volumes    Remove persistent data volumes"
            echo "  -f, --force            Skip confirmation prompts"
            echo "  -h, --help             Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "INFO")
            echo -e "[$timestamp] ${BLUE}$message${NC}"
            ;;
        "SUCCESS")
            echo -e "[$timestamp] ${GREEN}$message${NC}"
            ;;
        "WARNING")
            echo -e "[$timestamp] ${YELLOW}$message${NC}"
            ;;
        "ERROR")
            echo -e "[$timestamp] ${RED}$message${NC}"
            ;;
    esac
}

stop_all_profiles() {
    log_message "INFO" "Stopping containers for all profiles..."
    
    # Stop containers for each profile
    local profiles=("migration" "cache" "monitoring" "gui")
    
    for profile in "${profiles[@]}"; do
        log_message "INFO" "Stopping profile: $profile"
        docker compose --profile "$profile" down 2>/dev/null || true
    done
    
    # Stop base containers (no profile)
    log_message "INFO" "Stopping base containers..."
    docker compose down 2>/dev/null || true
}

remove_project_containers() {
    log_message "INFO" "Finding and removing project containers..."
    
    # Get all containers with our project prefix
    local containers
    containers=$(docker ps -a --filter "name=db-dev-" --format "{{.Names}}" 2>/dev/null || true)
    
    if [[ -n "$containers" ]]; then
        log_message "INFO" "Found containers: $containers"
        
        while IFS= read -r container; do
            log_message "INFO" "Removing container: $container"
            docker rm -f "$container" 2>/dev/null || true
        done <<< "$containers"
    else
        log_message "INFO" "No project containers found"
    fi
}

remove_project_networks() {
    log_message "INFO" "Removing project networks..."
    
    local networks
    networks=$(docker network ls --filter "name=dev_db-dev-network" --format "{{.Name}}" 2>/dev/null || true)
    
    if [[ -n "$networks" ]]; then
        while IFS= read -r network; do
            log_message "INFO" "Removing network: $network"
            docker network rm "$network" 2>/dev/null || true
        done <<< "$networks"
    else
        log_message "INFO" "No project networks found"
    fi
}

remove_project_volumes() {
    if [[ "$REMOVE_VOLUMES" != "true" ]]; then
        log_message "WARNING" "Skipping volume removal (use -v to remove data)"
        return
    fi
    
    if [[ "$FORCE" != "true" ]]; then
        echo -n "This will remove all data volumes. Are you sure? (y/N): "
        read -r confirmation
        if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
            log_message "INFO" "Volume removal cancelled"
            return
        fi
    fi
    
    log_message "WARNING" "Removing project volumes..."
    
    local volumes
    volumes=$(docker volume ls --filter "name=dev_" --format "{{.Name}}" 2>/dev/null || true)
    
    if [[ -n "$volumes" ]]; then
        while IFS= read -r volume; do
            log_message "WARNING" "Removing volume: $volume"
            docker volume rm "$volume" 2>/dev/null || true
        done <<< "$volumes"
    else
        log_message "INFO" "No project volumes found"
    fi
}

show_status() {
    log_message "INFO" "Current Docker status:"
    
    echo ""
    log_message "INFO" "Running containers:"
    local running_containers
    running_containers=$(docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || true)
    if [[ -n "$running_containers" ]]; then
        echo "$running_containers"
    else
        log_message "SUCCESS" "No running containers"
    fi
    
    echo ""
    log_message "INFO" "Project volumes:"
    local volumes
    volumes=$(docker volume ls --filter "name=dev_" --format "table {{.Name}}\t{{.Size}}" 2>/dev/null || true)
    if [[ -n "$volumes" ]]; then
        echo "$volumes"
    else
        log_message "SUCCESS" "No project volumes"
    fi
}

main() {
    log_message "INFO" "=== DB Development Environment Cleanup ==="
    
    # Stop all profile-based containers
    stop_all_profiles
    
    # Remove any remaining project containers
    remove_project_containers
    
    # Remove project networks
    remove_project_networks
    
    # Remove volumes if requested
    remove_project_volumes
    
    # Clean up unused Docker resources
    log_message "INFO" "Cleaning up unused Docker resources..."
    docker system prune -f 2>/dev/null || true
    
    log_message "SUCCESS" "=== Cleanup Complete ==="
    
    # Show final status
    show_status
    
    echo ""
    log_message "INFO" "To restart the environment:"
    log_message "INFO" "  ./init-db.ps1  (Windows)"
    log_message "INFO" "  bash init-db.sh  (Linux/Mac - if created)"
    echo ""
    log_message "INFO" "To start with monitoring:"
    log_message "INFO" "  docker compose --profile monitoring up -d"
}

# Run main function
main "$@"
