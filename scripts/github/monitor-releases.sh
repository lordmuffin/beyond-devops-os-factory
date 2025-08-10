#!/bin/bash
#
# GitHub Release Monitor for Kairos Images
# Monitors GitHub releases and triggers automatic downloads of new versions

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_DIR="${CONFIG_DIR:-$PROJECT_ROOT/.github-monitor}"
GITHUB_REPO="${GITHUB_REPO:-your-org/beyond-devops-os-factory}"
CHECK_INTERVAL="${CHECK_INTERVAL:-300}"  # 5 minutes
LOG_FILE="${LOG_FILE:-$CONFIG_DIR/monitor.log}"
STATE_FILE="$CONFIG_DIR/last-release.json"
WEBHOOK_URL="${WEBHOOK_URL:-}"  # Optional webhook for notifications

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS:${NC} $*" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $*" | tee -a "$LOG_FILE"
}

# Help function
show_help() {
    cat << EOF
GitHub Release Monitor for Kairos Images

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -r, --repo REPO          GitHub repository (default: $GITHUB_REPO)
    -i, --interval SECONDS   Check interval in seconds (default: $CHECK_INTERVAL)
    -c, --config-dir DIR     Configuration directory (default: $CONFIG_DIR)
    -w, --webhook URL        Webhook URL for notifications
    -o, --once               Run once and exit (don't monitor continuously)
    -d, --daemon             Run as daemon (background process)
    --setup                  Setup monitoring configuration
    -h, --help               Show this help

EXAMPLES:
    # Start monitoring with default settings
    $0

    # Monitor with custom interval (check every 2 minutes)
    $0 --interval 120

    # Run once and exit
    $0 --once

    # Setup monitoring configuration
    $0 --setup

CONFIGURATION:
    The monitor stores its state in: $CONFIG_DIR/
    - last-release.json: Information about the last seen release
    - monitor.log: Activity log
    - config.json: Monitor configuration

WEBHOOK NOTIFICATIONS:
    Set WEBHOOK_URL environment variable or use --webhook to receive
    notifications when new releases are detected.

EOF
}

# Setup monitoring configuration
setup_monitor() {
    log "Setting up GitHub release monitor..."
    
    # Create config directory
    mkdir -p "$CONFIG_DIR"
    
    # Create initial config file
    cat > "$CONFIG_DIR/config.json" << EOF
{
    "github_repo": "$GITHUB_REPO",
    "check_interval": $CHECK_INTERVAL,
    "webhook_url": "$WEBHOOK_URL",
    "auto_download": true,
    "image_types": ["iso", "raw", "qcow2"],
    "created_at": "$(date -Iseconds)",
    "version": "1.0.0"
}
EOF
    
    # Create systemd service file (optional)
    if command -v systemctl >/dev/null 2>&1; then
        log "Creating systemd service file..."
        
        cat > "$CONFIG_DIR/kairos-release-monitor.service" << EOF
[Unit]
Description=Kairos GitHub Release Monitor
After=network.target

[Service]
Type=simple
User=$USER
Environment=HOME=$HOME
Environment=GITHUB_REPO=$GITHUB_REPO
Environment=CONFIG_DIR=$CONFIG_DIR
ExecStart=$SCRIPT_DIR/monitor-releases.sh --daemon
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF
        
        log "Systemd service file created: $CONFIG_DIR/kairos-release-monitor.service"
        log "To install: sudo cp $CONFIG_DIR/kairos-release-monitor.service /etc/systemd/system/"
        log "To enable: sudo systemctl enable kairos-release-monitor.service"
        log "To start: sudo systemctl start kairos-release-monitor.service"
    fi
    
    # Create sample webhook script
    cat > "$CONFIG_DIR/sample-webhook.sh" << 'EOF'
#!/bin/bash
# Sample webhook handler for release notifications

WEBHOOK_DATA="$1"
RELEASE_TAG=$(echo "$WEBHOOK_DATA" | jq -r '.tag_name')
RELEASE_NAME=$(echo "$WEBHOOK_DATA" | jq -r '.name')
PUBLISHED_AT=$(echo "$WEBHOOK_DATA" | jq -r '.published_at')

echo "New Kairos release detected!"
echo "Tag: $RELEASE_TAG"
echo "Name: $RELEASE_NAME"
echo "Published: $PUBLISHED_AT"

# Example: Send to Slack webhook
# curl -X POST -H 'Content-type: application/json' \
#      --data "{\"text\":\"New Kairos release: $RELEASE_TAG\"}" \
#      "$SLACK_WEBHOOK_URL"

# Example: Send email notification
# echo "New Kairos release $RELEASE_TAG is available" | \
#      mail -s "Kairos Release Notification" admin@example.com
EOF
    
    chmod +x "$CONFIG_DIR/sample-webhook.sh"
    
    # Initialize state file
    echo '{}' > "$STATE_FILE"
    
    log_success "Monitor setup completed!"
    log "Configuration directory: $CONFIG_DIR"
    log "Edit $CONFIG_DIR/config.json to customize settings"
}

# Load configuration
load_config() {
    if [ -f "$CONFIG_DIR/config.json" ]; then
        local config_repo config_interval config_webhook
        config_repo=$(jq -r '.github_repo // empty' "$CONFIG_DIR/config.json")
        config_interval=$(jq -r '.check_interval // empty' "$CONFIG_DIR/config.json")
        config_webhook=$(jq -r '.webhook_url // empty' "$CONFIG_DIR/config.json")
        
        GITHUB_REPO="${config_repo:-$GITHUB_REPO}"
        CHECK_INTERVAL="${config_interval:-$CHECK_INTERVAL}"
        WEBHOOK_URL="${config_webhook:-$WEBHOOK_URL}"
    fi
}

# Get latest release information
get_latest_release() {
    if ! gh release view --repo "$GITHUB_REPO" --json tagName,name,publishedAt,assets,url 2>/dev/null; then
        log_error "Failed to get latest release information"
        return 1
    fi
}

# Load last seen release
load_last_release() {
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE"
    else
        echo '{}'
    fi
}

# Save release state
save_release_state() {
    local release_data="$1"
    echo "$release_data" > "$STATE_FILE"
}

# Send webhook notification
send_webhook_notification() {
    local release_data="$1"
    
    if [ -z "$WEBHOOK_URL" ]; then
        return 0
    fi
    
    log "Sending webhook notification to $WEBHOOK_URL"
    
    local webhook_payload
    webhook_payload=$(cat << EOF
{
    "event": "new_release",
    "repository": "$GITHUB_REPO",
    "release": $release_data,
    "timestamp": "$(date -Iseconds)",
    "monitor": {
        "version": "1.0.0",
        "hostname": "$(hostname)"
    }
}
EOF
)
    
    if curl -s -X POST -H "Content-Type: application/json" -d "$webhook_payload" "$WEBHOOK_URL" >/dev/null; then
        log_success "Webhook notification sent successfully"
    else
        log_error "Failed to send webhook notification"
    fi
}

# Download new release
download_new_release() {
    local tag_name="$1"
    
    log "Triggering download for release $tag_name"
    
    # Call the fetch script
    if "$SCRIPT_DIR/fetch-kairos-releases.sh" --version "$tag_name"; then
        log_success "Successfully downloaded release $tag_name"
        return 0
    else
        log_error "Failed to download release $tag_name"
        return 1
    fi
}

# Check for new releases
check_for_new_release() {
    log "Checking for new releases in $GITHUB_REPO..."
    
    # Get latest release
    local latest_release
    if ! latest_release=$(get_latest_release); then
        return 1
    fi
    
    # Extract release information
    local tag_name published_at
    tag_name=$(echo "$latest_release" | jq -r '.tagName')
    published_at=$(echo "$latest_release" | jq -r '.publishedAt')
    
    log "Latest release: $tag_name (published: $published_at)"
    
    # Load last seen release
    local last_release
    last_release=$(load_last_release)
    
    # Check if this is a new release
    local last_tag_name
    last_tag_name=$(echo "$last_release" | jq -r '.tagName // empty')
    
    if [ "$tag_name" != "$last_tag_name" ]; then
        log_success "New release detected: $tag_name (previous: ${last_tag_name:-none})"
        
        # Save new release state
        save_release_state "$latest_release"
        
        # Send webhook notification
        send_webhook_notification "$latest_release"
        
        # Auto-download if enabled
        if [ "$(jq -r '.auto_download // true' "$CONFIG_DIR/config.json" 2>/dev/null)" = "true" ]; then
            download_new_release "$tag_name"
        else
            log "Auto-download disabled, skipping download"
        fi
        
        return 0
    else
        log "No new releases found"
        return 1
    fi
}

# Monitor loop
monitor_loop() {
    log "Starting release monitoring loop (interval: ${CHECK_INTERVAL}s)"
    log "Monitoring repository: $GITHUB_REPO"
    
    # Initial check
    check_for_new_release || true
    
    while true; do
        sleep "$CHECK_INTERVAL"
        check_for_new_release || true
    done
}

# Daemon mode
run_as_daemon() {
    log "Starting monitor in daemon mode..."
    
    # Create PID file
    local pid_file="$CONFIG_DIR/monitor.pid"
    echo $$ > "$pid_file"
    
    # Setup signal handling
    trap 'log "Received shutdown signal, exiting..."; rm -f "$pid_file"; exit 0' TERM INT
    
    # Run monitor loop
    monitor_loop
}

# Main function
main() {
    local run_once="false"
    local daemon_mode="false"
    local setup_mode="false"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -r|--repo)
                GITHUB_REPO="$2"
                shift 2
                ;;
            -i|--interval)
                CHECK_INTERVAL="$2"
                shift 2
                ;;
            -c|--config-dir)
                CONFIG_DIR="$2"
                STATE_FILE="$CONFIG_DIR/last-release.json"
                LOG_FILE="$CONFIG_DIR/monitor.log"
                shift 2
                ;;
            -w|--webhook)
                WEBHOOK_URL="$2"
                shift 2
                ;;
            -o|--once)
                run_once="true"
                shift
                ;;
            -d|--daemon)
                daemon_mode="true"
                shift
                ;;
            --setup)
                setup_mode="true"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Create config directory
    mkdir -p "$CONFIG_DIR"
    
    # Setup mode
    if [ "$setup_mode" = "true" ]; then
        setup_monitor
        exit 0
    fi
    
    # Load configuration
    load_config
    
    # Initialize log
    log "GitHub Release Monitor starting..."
    log "Repository: $GITHUB_REPO"
    log "Config directory: $CONFIG_DIR"
    log "Check interval: ${CHECK_INTERVAL}s"
    
    # Check dependencies
    if ! command -v gh >/dev/null 2>&1; then
        log_error "GitHub CLI (gh) not found. Please install it first."
        exit 1
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        log_error "jq not found. Please install it first."
        exit 1
    fi
    
    # Check GitHub authentication
    if ! gh auth status >/dev/null 2>&1; then
        log_error "GitHub CLI not authenticated. Please run 'gh auth login' first."
        exit 1
    fi
    
    # Run based on mode
    if [ "$run_once" = "true" ]; then
        log "Running single check..."
        check_for_new_release
    elif [ "$daemon_mode" = "true" ]; then
        run_as_daemon
    else
        monitor_loop
    fi
}

# Run main function with all arguments
main "$@"