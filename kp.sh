#!/bin/bash

set -euo pipefail

# === GITHUB RUNNER PRE-REQUISITES CHECK & INSTALL ===
# Ensure necessary tools (uuidgen and jq) are installed for a clean run.
if ! command -v uuidgen &> /dev/null || ! command -v jq &> /dev/null; then
    echo -e "\033[0;34m[INFO]\033[0m Installing prerequisite packages (uuid-runtime, jq)..."
    sudo apt-get update > /dev/null 2>&1 || true
    sudo apt-get install -y uuid-runtime jq
    echo -e "\033[0;32m[INFO]\033[0m Prerequisites installed."
fi
# ===================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Global Variables
PROTOCOL=""
TROJAN_PASS="KP-CHANNEL" # Hardcoded as requested
VLESS_PATH="" # Will be set by get_user_input
TIMEOUT="" # Will be set by select_timeout
IMAGE="" # Docker Image URL

# --- Logging Functions ---
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# --- Validation Functions ---
validate_uuid() {
    local uuid_pattern='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    if [[ ! $1 =~ $uuid_pattern ]]; then
        error "Invalid UUID format: $1"
        return 1
    fi
    return 0
}

validate_path() {
    local path_pattern='^\/[a-zA-Z0-9_-]{4,20}$'
    if [[ ! $1 =~ $path_pattern ]]; then
        error "Invalid Path format. Must start with '/' and contain 4-20 alphanumeric characters/hyphens/underscores."
        return 1
    fi
    return 0
}

validate_bot_token() {
    local token_pattern='^[0-9]{8,10}:[a-zA-Z0-9_-]{35}$'
    if [[ ! $1 =~ $token_pattern ]]; then
        error "Invalid Telegram Bot Token format"
        return 1
    fi
    return 0
}

validate_chat_id() {
    if [[ ! $1 =~ ^-?[0-9]+$ ]]; then
        error "Invalid Chat ID format"
        return 1
    fi
    return 0
}

# --- Configuration/Selection Functions ---

# Protocol selection function (NEW FEATURE 1)
select_protocol() {
    echo
    info "=== Protocol Selection ==="
    echo "1. VLESS / WebSockets (Recommended Default) -> Image: kpchannel/vl:latest" 
    echo "2. Trojan / WebSockets -> Image: kpchannel/tr:latest" 
    echo "3. VMess / WebSockets -> Image: kpchannel/vmess:latest" 
    echo
    
    while true; do
        read -p "Select Protocol (1-3, or Enter for Default 1): " proto_choice
        proto_choice=${proto_choice:-"1"}
        
        case $proto_choice in
            1) PROTO="vless-ws"; IMAGE="docker.io/kpchannel/vl:latest"; break ;;
            2) PROTO="trojan-ws"; IMAGE="docker.io/kpchannel/tr:latest"; break ;;
            3) PROTO="vmess-ws"; IMAGE="docker.io/kpchannel/vmess:latest"; break ;;
            *) echo "Invalid selection. Please enter a number between 1-3." ;;
        esac
    done
    
    info "Selected Protocol: ${PROTOCOL^^}"
}

# Service Timeout selection function (NEW FEATURE 3)
select_timeout() {
    echo
    info "=== Service Timeout Configuration ==="
    echo "1. 300 seconds (5 minutes)"
    echo "2. 900 seconds (15 minutes)"
    echo "3. 3600 seconds (1 hour) (Maximum Default)" 
    echo
    
    while true; do
        read -p "Select Timeout (1-3, or Enter for Default 3): " timeout_choice
        timeout_choice=${timeout_choice:-"3"}
        
        case $timeout_choice in
            1) TIMEOUT="300"; break ;;
            2) TIMEOUT="900"; break ;;
            3) TIMEOUT="3600"; break ;;
            *) echo "Invalid selection. Please enter a number between 1-3." ;;
        esac
    done
    
    info "Selected Timeout: $TIMEOUT seconds"
}

# CPU selection function (Original)
select_cpu() {
    echo
    info "=== CPU Configuration ==="
    echo "1. 1 CPU Core"
    echo "2. 2 CPU Cores"
    echo "3. 4 CPU Cores (Default)" 
    echo "4. 8 CPU Cores"
    echo
    
    while true; do
        read -p "Select CPU cores (1-4, or Enter for Default 3): " cpu_choice
        cpu_choice=${cpu_choice:-"3"}
        
        case $cpu_choice in
            1) CPU="1"; break ;;
            2) CPU="2"; break ;;
            3) CPU="4"; break ;;
            4) CPU="8"; break ;;
            *) echo "Invalid selection. Please enter a number between 1-4." ;;
        esac
    done
    
    info "Selected CPU: $CPU core(s)"
}

# Memory selection function (Original)
select_memory() {
    echo
    info "=== Memory Configuration ==="
    
    echo "Memory Options:"
    echo "1. 512Mi"
    echo "2. 1Gi"
    echo "3. 2Gi (Recommended Default for 4 CPU)"
    echo "4. 4Gi"
    echo "5. 8Gi"
    echo "6. 16Gi" 
    echo
    
    while true; do
        read -p "Select memory (1-6, or Enter for Default 3): " memory_choice
        memory_choice=${memory_choice:-"3"}
        
        case $memory_choice in
            1) MEMORY="512Mi"; break ;;
            2) MEMORY="1Gi"; break ;;
            3) MEMORY="2Gi"; break ;;
            4) MEMORY="4Gi"; break ;;
            5) MEMORY="8Gi"; break ;;
            6) MEMORY="16Gi"; break ;;
            *) echo "Invalid selection. Please enter a number between 1-6." ;;
        esac
    done
    
    validate_memory_config
    info "Selected Memory: $MEMORY"
}

# Validate memory configuration based on CPU (Original)
validate_memory_config() {
    local cpu_num=$CPU
    local memory_num=$(echo $MEMORY | sed 's/[^0-9]*//g')
    local memory_unit=$(echo $MEMORY | sed 's/[0-9]*//g')
    
    if [[ "$memory_unit" == "Gi" ]]; then
        memory_num=$((memory_num * 1024))
    fi
    
    local min_memory=0
    
    case $cpu_num in
        1) min_memory=512 ;;
        2) min_memory=1024 ;;
        4) min_memory=2048 ;;
        8) min_memory=4096 ;;
    esac
    
    if [[ $memory_num -lt $min_memory ]]; then
        warn "Memory configuration ($MEMORY) might be too low for $CPU CPU core(s)."
        warn "Recommended minimum: $((min_memory / 1024))Gi"
        read -p "Do you want to continue with this configuration? (y/n): " confirm
        if [[ ! $confirm =~ [Yy] ]]; then
            select_memory
        fi
    fi
}

# Region selection function (Original)
select_region() {
    echo
    info "=== Region Selection ==="
    echo "1. us-central1 (Iowa, USA) (Default)" 
    echo "2. us-west1 (Oregon, USA)" 
    echo "3. asia-southeast1 (Singapore)"
    echo "4. asia-northeast1 (Tokyo, Japan)"
    echo
    
    while true; do
        read -p "Select region (1-4, or Enter for Default 1): " region_choice
        region_choice=${region_choice:-"1"}
        
        case $region_choice in
            1) REGION="us-central1"; break ;;
            2) REGION="us-west1"; break ;;
            3) REGION="asia-southeast1"; break ;;
            4) REGION="asia-northeast1"; break ;;
            *) echo "Invalid selection. Please enter a number between 1-4." ;;
        esac
    done
    
    info "Selected region: $REGION"
}

# Telegram destination selection (Original)
select_telegram_destination() {
    echo
    info "=== Telegram Destination ==="
    echo "1. Send to Channel only"
    echo "2. Send to Bot private message only (Default)" 
    echo "3. Send to both Channel and Bot"
    echo "4. Don't send to Telegram"
    echo
    
    local DEFAULT_CHAT_ID="7070690379"
    
    while true; do
        read -p "Select destination (1-4, or Enter for Default 2): " telegram_choice
        telegram_choice=${telegram_choice:-"2"}

        case $telegram_choice in
            1) 
                TELEGRAM_DESTINATION="channel"
                while true; do
                    read -p "Enter Telegram Channel ID: " TELEGRAM_CHANNEL_ID
                    if validate_chat_id "$TELEGRAM_CHANNEL_ID"; then
                        break
                    fi
                done
                break 
                ;;
            2) 
                TELEGRAM_DESTINATION="bot"
                while true; do
                    read -p "Enter your Chat ID (for bot private message) [default: ${DEFAULT_CHAT_ID}]: " CHAT_ID_INPUT
                    TELEGRAM_CHAT_ID=${CHAT_ID_INPUT:-"$DEFAULT_CHAT_ID"}
                    
                    if validate_chat_id "$TELEGRAM_CHAT_ID"; then
                        break
                    fi
                done
                break 
                ;;
            3) 
                TELEGRAM_DESTINATION="both"
                while true; do
                    read -p "Enter Telegram Channel ID: " TELEGRAM_CHANNEL_ID
                    if validate_chat_id "$TELEGRAM_CHANNEL_ID"; then
                        break
                    fi
                done
                while true; do
                    read -p "Enter your Chat ID (for bot private message) [default: ${DEFAULT_CHAT_ID}]: " CHAT_ID_INPUT
                    TELEGRAM_CHAT_ID=${CHAT_ID_INPUT:-"$DEFAULT_CHAT_ID"}
                    
                    if validate_chat_id "$TELEGRAM_CHAT_ID"; then
                        break
                    fi
                done
                break 
                ;;
            4) 
                TELEGRAM_DESTINATION="none"
                break 
                ;;
            *) echo "Invalid selection. Please enter a number between 1-4." ;;
        esac
    done
}

# User input function (Updated with Path input)
get_user_input() {
    echo
    info "=== Service Configuration ==="
    
    # Service Name (Original)
    local DEFAULT_SERVICE_NAME="kpchannel"
    while true; do
        read -p "Enter service name [default: ${DEFAULT_SERVICE_NAME}]: " SERVICE_NAME_INPUT
        SERVICE_NAME=${SERVICE_NAME_INPUT:-"$DEFAULT_SERVICE_NAME"}
        
        if [[ -n "$SERVICE_NAME" ]]; then
            break
        else
            error "Service name cannot be empty"
        fi
    done

    # Path (Secret URL) Selection (NEW FEATURE 2)
    local DEFAULT_PATH="/KP-CHANNEL"
    while true; do
        read -p "Enter Path (Secret URL) [default: ${DEFAULT_PATH}]: " PATH_INPUT
        VLESS_PATH=${PATH_INPUT:-"$DEFAULT_PATH"}
        if validate_path "$VLESS_PATH"; then
            break
        fi
    done
    
    # UUID (Original)
    local DEFAULT_UUID
    if command -v uuidgen &> /dev/null; then
        DEFAULT_UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')
    elif [[ -f "/proc/sys/kernel/random/uuid" ]]; then
        DEFAULT_UUID=$(cat /proc/sys/kernel/random/uuid | tr '[:upper:]' '[:lower:]') 
    else
        DEFAULT_UUID="9c910024-714e-4221-81c6-41ca9856e7ab"
        warn "Cannot find 'uuidgen' or access kernel UUID interface. Using the default UUID."
    fi

    while true; do
        read -p "Enter UUID [default: ${DEFAULT_UUID}]: " UUID_INPUT
        UUID=${UUID_INPUT:-"$DEFAULT_UUID"}
        if validate_uuid "$UUID"; then
            break
        fi
    done
    
    # Telegram Bot Token (Original)
    if [[ "$TELEGRAM_DESTINATION" != "none" ]]; then
        local DEFAULT_BOT_TOKEN="8318171802:AAGh49s_ysQ-D84Cbht036QaLR1U4uT68RA"
        while true; do
            read -s -p "Enter Telegram Bot Token [default: ${DEFAULT_BOT_TOKEN:0:10}...]: " BOT_TOKEN_INPUT
            echo 

            TELEGRAM_BOT_TOKEN=${BOT_TOKEN_INPUT:-"$DEFAULT_BOT_TOKEN"}

            if validate_bot_token "$TELEGRAM_BOT_TOKEN"; then
                break
            fi
        done
    fi
    
    # Host Domain (Original)
    read -p "Enter host domain [default: m.googleapis.com]: " HOST_DOMAIN_INPUT
    HOST_DOMAIN=${HOST_DOMAIN_INPUT:-"m.googleapis.com"}
}

# Display configuration summary (Original)
show_config_summary() {
    echo
    info "=== Configuration Summary ==="
    echo "Project ID:    $(gcloud config get-value project)"
    echo "Protocol:      ${PROTOCOL^^}"
    echo "Region:        $REGION"
    echo "Service Name:  $SERVICE_NAME"
    echo "Image:         ${IMAGE}"
    echo "Host Domain:   $HOST_DOMAIN"
    echo "Path (Secret): $VLESS_PATH"
    if [[ "$PROTOCOL" == "trojan-ws" ]]; then
        echo "Trojan Pass:   ${TROJAN_PASS}"
    fi
    echo "UUID:          $UUID"
    echo "CPU:           $CPU core(s)"
    echo "Memory:        $MEMORY"
    echo "Timeout:       $TIMEOUT seconds"
    
    if [[ "$TELEGRAM_DESTINATION" != "none" ]]; then
        echo "Bot Token:     ${TELEGRAM_BOT_TOKEN:0:8}..."
        echo "Destination:   $TELEGRAM_DESTINATION"
        if [[ "$TELEGRAM_DESTINATION" == "channel" || "$TELEGRAM_DESTINATION" == "both" ]]; then
            echo "Channel ID:    $TELEGRAM_CHANNEL_ID"
        fi
        if [[ "$TELEGRAM_DESTINATION" == "bot" || "$TELEGRAM_DESTINATION" == "both" ]]; then
            echo "Chat ID:       $TELEGRAM_CHAT_ID"
        fi
    else
        echo "Telegram:      Not configured"
    fi
    echo
    
    while true; do
        read -p "Proceed with deployment? (y/n, or Enter for Default y): " confirm
        confirm=${confirm:-"y"}
        case $confirm in
            [Yy]* ) break;;
            [Nn]* ) 
                info "Deployment cancelled by user"
                exit 0
                ;;
            * ) echo "Please answer yes (y) or no (n).";;
        esac
    done
}

# VLESS/Trojan/VMess URI Generation (NEW)
generate_uri() {
    local DOMAIN="$1"
    local PROTOCOL="$2"
    local VLESS_PATH_ENCODED=$(printf "%s" "$VLESS_PATH" | jq -sRr @uri)
    local URI=""
    
    local REMARK="${SERVICE_NAME} - ${PROTOCOL^^} - KP CHANNEL"
    
    # VLESS WS
    if [[ "$PROTOCOL" == "vless-ws" ]]; then
        URI="vless://${UUID}@${HOST_DOMAIN}:443?path=${VLESS_PATH_ENCODED}&security=tls&alpn=h3%2Ch2%2Chttp%2F1.1&encryption=none&host=${DOMAIN}&fp=randomized&type=ws&sni=${DOMAIN}#${REMARK}"
    
    # Trojan WS (Using hardcoded pass)
    elif [[ "$PROTOCOL" == "trojan-ws" ]]; then
        URI="trojan://${TROJAN_PASS}@${HOST_DOMAIN}:443?path=${VLESS_PATH_ENCODED}&security=tls&alpn=h3%2Ch2%2Chttp%2F1.1&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${REMARK}"
    
    # VMess WS
    elif [[ "$PROTOCOL" == "vmess-ws" ]]; then
        local BASE64_JSON=$(cat <<JSON | base64 -w0
{"v":"2","ps":"${REMARK}","add":"${HOST_DOMAIN}","port":"443","id":"${UUID}","aid":"0","scy":"auto","net":"ws","type":"none","host":"${DOMAIN}","path":"${VLESS_PATH}","tls":"tls","sni":"${DOMAIN}","alpn":"h2,http/1.1","fp":"random"}
JSON
)
        URI="vmess://${BASE64_JSON}"
    fi
    
    echo "$URI"
}

# (Other deployment functions unchanged)

validate_prerequisites() {
    log "Validating prerequisites..."
    
    if ! command -v gcloud &> /dev/null; then
        error "gcloud CLI is not installed. Please install Google Cloud SDK."
        exit 1
    fi
    
    if ! command -v git &> /dev/null; then
        error "git is not installed. Please install git."
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        error "jq is not installed. Please install jq (JSON processor)."
        exit 1
    fi
    
    local PROJECT_ID=$(gcloud config get-value project)
    if [[ -z "$PROJECT_ID" || "$PROJECT_ID" == "(unset)" ]]; then
        error "No project configured. Run: gcloud config set project PROJECT_ID"
        exit 1
    fi
}

cleanup() {
    log "Cleaning up temporary files..."
    # The original script cloned a repo, but the new version uses direct docker image deployment,
    # so we only clean up the cloned directory if it exists (for compatibility)
    if [[ -d "gcp-vless-2" ]]; then
        rm -rf gcp-vless-2
    fi
}

send_to_telegram() {
    local chat_id="$1"
    local message="$2"
    local response
    
    response=$(curl -s -w "%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d "{
            \"chat_id\": \"${chat_id}\",
            \"text\": \"$message\",
            \"parse_mode\": \"MARKDOWN\",
            \"disable_web_page_preview\": true
        }" \
        https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage)
    
    local http_code="${response: -3}"
    local content="${response%???}"
    
    if [[ "$http_code" == "200" ]]; then
        return 0
    else
        error "Failed to send to Telegram (HTTP $http_code): $content"
        return 1
    fi
}

send_deployment_notification() {
    local message="$1"
    local success_count=0
    
    case $TELEGRAM_DESTINATION in
        "channel")
            log "Sending to Telegram Channel..."
            if send_to_telegram "$TELEGRAM_CHANNEL_ID" "$message"; then
                log "✅ Successfully sent to Telegram Channel"
                success_count=$((success_count + 1))
            else
                error "❌ Failed to send to Telegram Channel"
            fi
            ;;
            
        "bot")
            log "Sending to Bot private message..."
            if send_to_telegram "$TELEGRAM_CHAT_ID" "$message"; then
                log "✅ Successfully sent to Bot private message"
                success_count=$((success_count + 1))
            else
                error "❌ Failed to send to Bot private message"
            fi
            ;;
            
        "both")
            log "Sending to both Channel and Bot..."
            
            # Send to Channel
            if send_to_telegram "$TELEGRAM_CHANNEL_ID" "$message"; then
                log "✅ Successfully sent to Telegram Channel"
                success_count=$((success_count + 1))
            else
                error "❌ Failed to send to Telegram Channel"
            fi
            
            # Send to Bot
            if send_to_telegram "$TELEGRAM_CHAT_ID" "$message"; then
                log "✅ Successfully sent to Bot private message"
                success_count=$((success_count + 1))
            else
                error "❌ Failed to send to Bot private message"
            fi
            ;;
            
        "none")
            log "Skipping Telegram notification as configured"
            return 0
            ;;
    esac
    
    if [[ $success_count -gt 0 ]]; then
        log "Telegram notification completed ($success_count successful)"
        return 0
    else
        warn "All Telegram notifications failed, but deployment was successful"
        return 1
    fi
}

main() {
    info "=== GCP Cloud Run V2Ray Deployment (GitHub Mode) ==="
    
    # Get user input (Interactive selection)
    select_protocol
    select_region
    select_cpu
    select_memory
    select_timeout
    select_telegram_destination
    get_user_input
    show_config_summary
    
    PROJECT_ID=$(gcloud config get-value project)
    
    log "Starting Cloud Run deployment..."
    log "Protocol: ${PROTOCOL^^}"
    
    validate_prerequisites
    
    # Set trap for cleanup (to ensure it runs even if deployment fails)
    trap cleanup EXIT
    
    # Set environment variables for the Docker image
    local ENV_VARS="UUID=${UUID},PATH=${VLESS_PATH},TROJAN_PASS=${TROJAN_PASS}"
    
    log "Enabling required APIs..."
    # The previous script had issues with git clone and build, 
    # so we ensure the deployment is done directly from the public Docker image (kpchannel/*)
    gcloud services enable \
        run.googleapis.com \
        iam.googleapis.com \
        --quiet
    
    log "Deploying to Cloud Run with image: ${IMAGE}..."
    if ! gcloud run deploy ${SERVICE_NAME} \
        --image ${IMAGE} \
        --platform managed \
        --region ${REGION} \
        --allow-unauthenticated \
        --cpu ${CPU} \
        --memory ${MEMORY} \
        --timeout ${TIMEOUT} \
        --set-env-vars ${ENV_VARS} \
        --quiet; then
        error "Deployment failed"
        exit 1
    fi
    
    # Get the service URL
    SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} \
        --region ${REGION} \
        --format 'value(status.url)' \
        --quiet)

    DOMAIN=$(echo $SERVICE_URL | sed 's|https://||')

    # 🕒 Start time (MMT)
    START_TIME=$(TZ='Asia/Yangon' date +"%Y-%m-%d %H:%M:%S")

    # ⏰ End time = 5 hours from now (MMT)
    END_TIME=$(TZ='Asia/Yangon' date -d "+5 hours" +"%Y-%m-%d %H:%M:%S")

    # URI generation
    VLESS_LINK=$(generate_uri "$DOMAIN"
