#!/bin/bash
#
# LimeSurvey Health Monitor & Watchdog
# Monitors container health and triggers recovery actions
#
# Actions:
# 1. If containers are unhealthy -> Try to restart them
# 2. If restart fails multiple times -> Reboot Pi (last resort)
#

set -e

# Configuration
COMPOSE_DIR="/home/pi/limesurvey-pi-stack"
LOG_FILE="/var/log/limesurvey-watchdog.log"
STATE_FILE="/var/run/limesurvey-watchdog.state"
MAX_RESTART_ATTEMPTS=3
REBOOT_THRESHOLD=5  # Reboot if critical services fail this many times

# Critical services that must be running
CRITICAL_SERVICES=("limesurvey_app" "limesurvey_db")

# Color codes for logging
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
}

log_info() {
    log "INFO" "$@"
}

log_warn() {
    log "${YELLOW}WARN${NC}" "$@"
}

log_error() {
    log "${RED}ERROR${NC}" "$@"
}

log_success() {
    log "${GREEN}SUCCESS${NC}" "$@"
}

# Initialize state file
init_state() {
    if [ ! -f "$STATE_FILE" ]; then
        echo "restart_count=0" > "$STATE_FILE"
        echo "last_restart_time=0" >> "$STATE_FILE"
        echo "reboot_count=0" >> "$STATE_FILE"
    fi
}

# Read state
get_state_value() {
    local key=$1
    grep "^${key}=" "$STATE_FILE" | cut -d'=' -f2
}

# Update state
set_state_value() {
    local key=$1
    local value=$2
    sed -i "s/^${key}=.*/${key}=${value}/" "$STATE_FILE"
}

# Check if Docker is running
check_docker() {
    if ! systemctl is-active --quiet docker; then
        log_error "Docker service is not running!"
        log_info "Attempting to start Docker..."
        sudo systemctl start docker
        sleep 5
        if systemctl is-active --quiet docker; then
            log_success "Docker started successfully"
            return 0
        else
            log_error "Failed to start Docker"
            return 1
        fi
    fi
    return 0
}

# Get unhealthy containers
get_unhealthy_containers() {
    cd "$COMPOSE_DIR"
    docker compose ps --format json 2>/dev/null | \
        jq -r 'select(.Health == "unhealthy" or (.State == "exited" and .Health != "")) | .Service' | \
        tr '\n' ' '
}

# Get stopped critical containers
get_stopped_critical_containers() {
    cd "$COMPOSE_DIR"
    local stopped=""
    for service in "${CRITICAL_SERVICES[@]}"; do
        local status=$(docker compose ps -q "$service" 2>/dev/null | xargs docker inspect -f '{{.State.Status}}' 2>/dev/null || echo "missing")
        if [ "$status" != "running" ]; then
            stopped="$stopped $service"
        fi
    done
    echo "$stopped" | xargs
}

# Restart unhealthy containers
restart_containers() {
    local containers="$1"
    if [ -z "$containers" ]; then
        return 0
    fi

    log_warn "Unhealthy containers detected: $containers"

    for container in $containers; do
        log_info "Restarting container: $container"
        cd "$COMPOSE_DIR"
        if docker compose restart "$container" 2>&1 | tee -a "$LOG_FILE"; then
            log_success "Container $container restarted"
        else
            log_error "Failed to restart container $container"
            return 1
        fi
    done

    # Increment restart count
    local restart_count=$(get_state_value "restart_count")
    restart_count=$((restart_count + 1))
    set_state_value "restart_count" "$restart_count"
    set_state_value "last_restart_time" "$(date +%s)"

    return 0
}

# Full system restart (docker compose down/up)
full_system_restart() {
    log_warn "Performing full system restart..."
    cd "$COMPOSE_DIR"

    log_info "Stopping all containers..."
    docker compose down 2>&1 | tee -a "$LOG_FILE"

    sleep 10

    log_info "Starting all containers..."
    docker compose up -d 2>&1 | tee -a "$LOG_FILE"

    sleep 30

    # Check if critical services are running
    local stopped=$(get_stopped_critical_containers)
    if [ -z "$stopped" ]; then
        log_success "Full system restart successful"
        return 0
    else
        log_error "Full system restart failed. Still stopped: $stopped"
        return 1
    fi
}

# Reboot the Raspberry Pi (last resort)
reboot_pi() {
    log_error "CRITICAL: Triggering Raspberry Pi reboot as last resort"
    log_error "Multiple recovery attempts have failed"

    # Increment reboot count
    local reboot_count=$(get_state_value "reboot_count")
    reboot_count=$((reboot_count + 1))
    set_state_value "reboot_count" "$reboot_count"

    # Create marker file to track reboots
    echo "$(date '+%Y-%m-%d %H:%M:%S')" >> /var/log/limesurvey-reboots.log

    sync
    log_error "Rebooting in 10 seconds..."
    sleep 10
    sudo reboot
}

# Main watchdog logic
main() {
    log_info "=========================================="
    log_info "LimeSurvey Watchdog Check Started"
    log_info "=========================================="

    # Initialize
    init_state

    # Check Docker
    if ! check_docker; then
        log_error "Docker is not available. Attempting full restart..."
        sleep 10
        if ! check_docker; then
            log_error "Docker still unavailable after restart attempt"
            reboot_pi
            exit 1
        fi
    fi

    # Check for unhealthy containers
    local unhealthy=$(get_unhealthy_containers)
    local stopped=$(get_stopped_critical_containers)

    if [ -z "$unhealthy" ] && [ -z "$stopped" ]; then
        log_success "All services are healthy"
        # Reset restart count on success
        set_state_value "restart_count" "0"
        exit 0
    fi

    # Get current restart count
    local restart_count=$(get_state_value "restart_count")
    local last_restart=$(get_state_value "last_restart_time")
    local current_time=$(date +%s)
    local time_since_restart=$((current_time - last_restart))

    log_warn "Issues detected. Restart count: $restart_count"

    # If restart count is high and recent, consider full restart
    if [ "$restart_count" -ge "$MAX_RESTART_ATTEMPTS" ] && [ "$time_since_restart" -lt 3600 ]; then
        log_warn "Multiple restart attempts in short time. Performing full system restart..."

        if ! full_system_restart; then
            log_error "Full system restart failed"

            # If we've failed too many times, reboot the Pi
            if [ "$restart_count" -ge "$REBOOT_THRESHOLD" ]; then
                reboot_pi
            fi
            exit 1
        fi

        # Reset counters after successful full restart
        set_state_value "restart_count" "0"
        exit 0
    fi

    # Try restarting containers
    local all_containers="$unhealthy $stopped"
    if restart_containers "$all_containers"; then
        log_success "Container restart completed"
        sleep 30

        # Verify health after restart
        unhealthy=$(get_unhealthy_containers)
        stopped=$(get_stopped_critical_containers)

        if [ -z "$unhealthy" ] && [ -z "$stopped" ]; then
            log_success "All services healthy after restart"
            exit 0
        else
            log_warn "Some services still unhealthy after restart"
            exit 1
        fi
    else
        log_error "Container restart failed"
        exit 1
    fi
}

# Run main function
main "$@"
