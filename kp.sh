#!/bin/bash

set -euo pipefail

# === Global Variables & Constants ===
PROTOCOL="" # VLESS, Trojan, VMess
IMAGE_TAG="" # Repository name for the protocol image
VLESS_PATH="" # New Feature 1: User-defined Path
HOST_DOMAIN="" # New Feature 3: User-defined Host Domain
DEPLOY_DURATION_SECONDS="" # New Feature 4: Deployment duration

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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
    # Path must start with / and contain 4-20 alphanumeric/hyphen/underscore characters
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

validate_channel_id() {
    if [[ ! $1 =~ ^-?[0-9]+$ ]]; then
        error "Invalid Channel ID format"
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

# New Feature 2: Protocol Selection (VLESS / Trojan)
select_protocol() {
    echo
    info "=== Protocol Selection (New Feature 2) ==="
    echo "1. VLESS / WebSockets (Default)"
    echo "2. Trojan / WebSockets"
    echo
    
    while true; do
        read -p "Select Protocol (1-2, or Enter for Default 1): " proto_choice
        proto_choice=${proto_choice:-"1"}
        
        case $proto_choice in
            1) PROTO="vless"; IMAGE_TAG="vless-ws"; break ;;
            2) PROTO="trojan"; IMAGE_TAG="trojan-ws"; break ;;
            *) echo "Invalid selection. Please enter 1 or 2." ;;
        esac
    done
    
    info "Selected Protocol: ${PROTOCOL^^}"
}

# New Feature 4: Deployment Duration (TTL)
select_deployment_duration() {
    echo
    info "=== Deployment Duration (New Feature 4) ==="
    echo "This sets the intended lifespan of the link for the user."
    echo "1. 5 hours (Default)"
    echo "2. 1 day (24 hours)"
    echo "3. 7 days (168 hours)"
    echo
    
    while true; do
        read -p "Select Duration (1-3, or Enter for Default 1): " duration_choice
        duration_choice=${duration_choice:-"1"}
        
        case $duration_choice in
            1) DEPLOY_DURATION_SECONDS="18000"; break ;; # 5 hours
            2) DEPLOY_DURATION_SECONDS="86400"; break ;; # 24 hours
            3) DEPLOY_DURATION_SECONDS="604800"; break ;; # 7 days
            *) echo "Invalid selection. Please enter a number between 1-3." ;;
        esac
    done
    
    info "Selected Duration: $(($DEPLOY_DURATION_SECONDS / 3600)) hours"
}


# CPU selection function
select_cpu() {
    echo
    info "=== CPU Configuration ==="
    echo "1. 1 CPU Core"
    echo "2. 2 CPU Cores"
    echo "3. 4 CPU Cores"
    echo "4. 8 CPU Cores (Default)" 
    echo
    
    while true; do
        read -p "Select CPU cores (1-4, or Enter for Default 4): " cpu_choice
        cpu_choice=${cpu_choice:-"4"}
        
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

# Memory selection function
select_memory() {
    echo
    info "=== Memory Configuration ==="
    
    case $CPU in
        1) echo "Recommended memory: 512Mi - 2Gi" ;;
        2) echo "Recommended memory: 1Gi - 4Gi" ;;
        4) echo "Recommended memory: 2Gi - 8Gi" ;;
        8) echo "Recommended memory: 4Gi - 16Gi" ;;
    esac
    echo
    
    echo "Memory Options:"
    echo "1. 512Mi"
    echo "2. 1Gi"
    echo "3. 2Gi"
    echo "4. 4Gi"
    echo "5. 8Gi"
    echo "6. 16Gi (Default)" 
    echo
    
    while true; do
        read -p "Select memory (1-6, or Enter for Default 6): " memory_choice
        memory_choice=${memory_choice:-"6"}
        
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

# Validate memory configuration based on CPU (unchanged)
validate_memory_config() {
    local cpu_num=$CPU
    local memory_num=$(echo $MEMORY | sed 's/[^0-9]*//g')
    local memory_unit=$(echo $MEMORY | sed 's/[0-9]*//g')
    
    if [[ "$memory_unit" == "Gi" ]]; then
        memory_num=$((memory_num * 1024))
    fi
    
    local min_memory=0
    local max_memory=0
    
    case $cpu_num in
        1) min_memory=512; max_memory=2048 ;;
        2) min_memory=1024; max_memory=4096 ;;
        4) min_memory=2048; max_memory=8192 ;;
        8) min_memory=4096; max_memory=16384 ;;
    esac
    
    if [[ $memory_num -lt $min_memory ]]; then
        warn "Memory configuration ($MEMORY) might be too low for $CPU CPU core(s)."
        warn "Recommended minimum: $((min_memory / 1024))Gi"
        read -p "Do you want to continue with this configuration? (y/n): " confirm
        if [[ ! $confirm =~ [Yy] ]]; then
            select_memory
        fi
    elif [[ $memory_num -gt $max_memory ]]; then
        warn "Memory configuration ($MEMORY) might be too high for $CPU CPU core(s)."
        warn "Recommended maximum: $((max_memory / 1024))Gi"
        read -p "Do you want to continue with this configuration? (y/n): " confirm
        if [[ ! $confirm =~ [Yy] ]]; then
            select_memory
        fi
    fi
}

# Region selection function
select_region() {
    echo
    info "=== Region Selection ==="
    echo "1. us-central1 (Iowa, USA) (Default)" 
    echo "2. us-west1 (Oregon, USA)" 
    echo "3. us-east1 (South Carolina, USA)"
    echo "4. europe-west1 (Belgium)"
    echo "5. asia-southeast1 (Singapore)"
    echo "6. asia-northeast1 (Tokyo, Japan)"
    echo "7. asia-east1 (Taiwan)"
    echo
    
    while true; do
        read -p "Select region (1-7, or Enter for Default 1): " region_choice
        region_choice=${region_choice:-"1"}
        
        case $region_choice in
            1) REGION="us-central1"; break ;;
            2) REGION="us-west1"; break ;;
            3) REGION="us-east1"; break ;;
            4) REGION="europe-west1"; break ;;
            5) REGION="asia-southeast1"; break ;;
            6) REGION="asia-northeast1"; break ;;
            7) REGION="asia-east1"; break ;;
            *) echo "Invalid selection. Please enter a number between 1-7." ;;
        esac
    done
    
    info "Selected region: $REGION"
}

# Telegram destination selection
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
                    if validate_channel_id "$TELEGRAM_CHANNEL_ID"; then
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
                    if validate_channel_id "$TELEGRAM_CHANNEL_ID"; then
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

# User input function (Updated with VLESS Path and Host Domain)
get_user_input() {
    echo
    info "=== Service Configuration ==="
    
    # Service Name
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
    
    # New Feature 1: Path (Secret URL) Selection
    local DEFAULT_PATH="/KP-CHANNEL"
    while true; do
        read -p "Enter Path (Secret URL) [default: ${DEFAULT_PATH}]: " PATH_INPUT
        VLESS_PATH=${PATH_INPUT:-"$DEFAULT_PATH"}
        if validate_path "$VLESS_PATH"; then
            break
        fi
    done

    # UUID
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
    
    # Telegram Bot Token (required for any Telegram option)
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
    
    # New Feature 3: Host Domain (optional)
    read -p "Enter Host Domain (SNI) [default: m.googleapis.com]: " HOST_DOMAIN_INPUT
    HOST_DOMAIN=${HOST_DOMAIN_INPUT:-"m.googleapis.com"}
}

# VLESS/Trojan URI Generation (NEW)
generate_uri() {
    local DOMAIN="$1"
    local PROTOCOL="$2"
    local PATH_ENCODED=$(printf "%s" "$VLESS_PATH" | jq -sRr @uri)
    local URI=""
    
    local REMARK="${SERVICE_NAME} - ${PROTOCOL^^}"
    
    # VLESS WS
    if [[ "$PROTOCOL" == "vless" ]]; then
        URI="vless://${UUID}@${HOST_DOMAIN}:443?path=${PATH_ENCODED}&security=tls&alpn=h3%2Ch2%2Chttp%2F1.1&encryption=none&host=${DOMAIN}&fp=randomized&type=ws&sni=${DOMAIN}#${REMARK}"
    
    # Trojan WS
    elif [[ "$PROTOCOL" == "trojan" ]]; then
        # Trojan uses password from Environment Variable or a default (You need to set TROJAN_PASS env var)
        local TROJAN_PASS="KP-CHANNEL" # Default or placeholder pass
        URI="trojan://${TROJAN_PASS}@${HOST_DOMAIN}:443?path=${PATH_ENCODED}&security=tls&alpn=h3%2Ch2%2Chttp%2F1.1&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${REMARK}"
    fi
    
    echo "$URI"
}

# Display configuration summary
show_config_summary() {
    echo
    info "=== Configuration Summary ==="
    echo "Project ID:    $(gcloud config get-value project)"
    echo "Protocol:      ${PROTOCOL^^}"
    echo "Region:        $REGION"
    echo "Service Name:  $SERVICE_NAME"
    echo "Host Domain:   $HOST_DOMAIN"
    echo "Path (Secret): $VLESS_PATH"
    echo "UUID:          $UUID"
    echo "CPU:           $CPU core(s)"
    echo "Memory:        $MEMORY"
    echo "Duration:      $(($DEPLOY_DURATION_SECONDS / 3600)) hours"
    
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

# --- Deployment & Notification Functions (Unchanged) ---
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
        log "Installing jq..."
        sudo apt-get update > /dev/null 2>&1 || true
        sudo apt-get install -y jq > /dev/null 2>&1 || true
    fi
    
    local PROJECT_ID=$(gcloud config get-value project)
    if [[ -z "$PROJECT_ID" || "$PROJECT_ID" == "(unset)" ]]; then
        error "No project configured. Run: gcloud config set project PROJECT_ID"
        exit 1
    fi
}

cleanup() {
    log "Cleaning up temporary files..."
    # The repository name must match the one used for cloning/building
    if [[ -d "gcp-vless-2" ]]; then
        rm -rf gcp-vless-2
    fi
}

send_to_telegram() {
    # ... (function body unchanged)
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
    # ... (function body unchanged)
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
    info "=== GCP Cloud Run V2Ray Deployment with New Features ==="
    
    # Get user input (Order matters for dependency, e.g., CPU before Memory)
    select_protocol # NEW
    select_region
    select_cpu
    select_memory
    select_deployment_duration # NEW
    select_telegram_destination
    get_user_input # Updated for Path and Host Domain
    show_config_summary
    
    PROJECT_ID=$(gcloud config get-value project)
    
    log "Starting Cloud Run deployment..."
    
    validate_prerequisites
    
    # Set trap for cleanup
    trap cleanup EXIT
    
    # Environment Variables for the container
    local TROJAN_PASS="KP-CHANNEL" # Placeholder password for Trojan
    local ENV_VARS="UUID=${UUID},PATH=${VLESS_PATH},TROJAN_PASS=${TROJAN_PASS},PROTOCOL=${PROTOCOL}" # PROTOCOL added

    log "Enabling required APIs..."
    gcloud services enable \
        cloudbuild.googleapis.com \
        run.googleapis.com \
        iam.googleapis.com \
        --quiet
    
    # Clean up any existing directory
    cleanup
    
    # Clone the repository and change to the directory
    # NOTE: Since the user's previous deployment failed due to Image Not Found, 
    # we are reverting to the original build method using the user's repo 'gcp-vless-2' 
    # to build the image locally and push to GCR/AR.
    log "Cloning repository: gcp-vless-2"
    if ! git clone https://github.com/KP-CHANNEL-KP/gcp-vless-2.git; then
        error "Failed to clone repository"
        exit 1
    fi
    
    cd gcp-vless-2
    
    # Build tag uses the selected protocol/image tag for clarity
    local GCR_IMAGE_TAG="gcr.io/${PROJECT_ID}/${IMAGE_TAG}:latest"
    
    log "Building container image: ${GCR_IMAGE_TAG}"
    if ! gcloud builds submit --tag ${GCR_IMAGE_TAG} --quiet; then
        error "Build failed"
        exit 1
    fi
    
    log "Deploying service ${SERVICE_NAME}..."
    if ! gcloud run deploy ${SERVICE_NAME} \
        --image ${GCR_IMAGE_TAG} \
        --platform managed \
        --region ${REGION} \
        --allow-unauthenticated \
        --cpu ${CPU} \
        --memory ${MEMORY} \
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

    # ⏰ End time calculation (New Feature 4)
    END_TIME=$(TZ='Asia/Yangon' date -d "@$(( $(date +%s) + $DEPLOY_DURATION_SECONDS ))" +"%Y-%m-%d %H:%M:%S")

    # URI generation (New)
    VLESS_LINK=$(generate_uri "$DOMAIN" "$PROTOCOL")

    # ✅ Telegram Message creation 
    MESSAGE=" *KP CHANNEL MYTEL BYPASS GCP*
━━━━━━━━━━━━━━━
\`\`\`
Protocol: ${PROTOCOL^^}
Region: ${REGION}
Resources: ${CPU} CPU | ${MEMORY} RAM
Domain: ${DOMAIN}
Path: ${VLESS_PATH}

Start: ${START_TIME}
End: ${END_TIME}
\`\`\`
\`\`\`
လိုင်းရှယ်ကောင်း
Singapore Server 🇸🇬🇸🇬🇸🇬
\`\`\`
━━━━━━━━━━━━━━━
*💛 ထို Key အား အဆင်ပြေတဲ့ Vpn မှာ ထည့်သုံးပါ*
\`\`\`
${VLESS_LINK}
\`\`\`
_အသုံးပြုပုံ: Internet သုံးဆွဲ၍မရသော ဒေသများတွင် Mytel ဖြင့် သုံးဆွဲနိုင်သည်_
\`\`\`Telegram-Channel\`\`\`
https://t.me/addlist/DaVvvOWfdg05NDJl
\`\`\`Telegram-Acc\`\`\`
@KPBYKP
\`\`\`🕔🕔🕔\`\`\`"

    # ✅ Console Output Message
    CONSOLE_MESSAGE="KP CHANNEL MYTEL BYPASS GCP ✅
━━━━━━━━━━━━━━━
 Project: ${PROJECT_ID}
 Protocol: ${PROTOCOL^^}
 Service: ${SERVICE_NAME}
 Region: ${REGION}
 Resources: ${CPU} CPU | ${MEMORY} RAM
 Domain: ${DOMAIN}
 Path: ${VLESS_PATH}
 
 Start Time (MMT): ${START_TIME}
 End Time (MMT):   ${END_TIME}
 လိုင်းရှယ်ကောင်း
 Singapore Server 🇸🇬🇸🇬🇸🇬
 
💛 ထို Key အား အဆင်ပြေတဲ့ Vpn မှာ ထည့်သုံးပါ:
${VLESS_LINK}
━━━━━━━━━━━━━━━
အသုံးပြုပုံ: Internet သုံးဆွဲ၍မရသော ဒေသများတွင် Mytel ဖြင့် သုံးဆွဲနိုင်သည်.
Telegram-Channel
https://t.me/addlist/DaVvvOWfdg05NDJl
Telegram-Acc
@KPBYKP
🕔🕔🕔"
# Save to file
    echo "$CONSOLE_MESSAGE" > deployment-info.txt
    log "Deployment info saved to deployment-info.txt"
    
    # Display locally
    echo
    info "=== Deployment Information ==="
    echo "$CONSOLE_MESSAGE"
    echo
    
    # Send to Telegram based on user selection
    if [[ "$TELEGRAM_DESTINATION" != "none" ]]; then
        log "Sending deployment info to Telegram..."
        send_deployment_notification "$MESSAGE"
    else
        log "Skipping Telegram notification as per user selection"
    fi
    
    log "Deployment completed successfully!"
    log "Service URL: $SERVICE_URL"
    log "Configuration saved to: deployment-info.txt"
}

# Run main function
main "$@"
