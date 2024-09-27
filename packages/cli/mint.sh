#!/bin/bash

# Color definitions
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Version Information and Credits
echo -e
cat << "EOF"
                                          
 ,-----.  ,---. ,--------. ,---.   ,--.   
'  .--./ /  O  \'--.  .--''.-.  \ /    \  
|  |    |  .-.  |  |  |    .-' .'|  ()  | 
'  '--'\|  | |  |  |  |   /   '-. \    /  
 `-----'`--' `--'  `--'   '-----'  `--'   
                                          
EOF
echo -e "Compatible with CAT20 cli - CAT20 minter 🐈,💻"
echo -e "Made by NodeCattel & All the credits to CAT_PROTOCOL"

# Configuration
CONFIG_DIR="$HOME/.cat-token-box"
CONFIG_FILE="$CONFIG_DIR/cat.conf"

# Ensure the configuration directory exists
mkdir -p "$CONFIG_DIR"

# Function to load configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        # Convert legacy config format if necessary
        if [ -z "$DISCORD_WEBHOOK_URL" ] && [ -n "$discord_webhook_url" ]; then
            DISCORD_WEBHOOK_URL="$discord_webhook_url"
        fi
    fi
}

# Function to save configuration
save_config() {
    echo "token_id=$token_id" > "$CONFIG_FILE"
    echo "tracker_url=$tracker_url" >> "$CONFIG_FILE"
    echo "DISCORD_WEBHOOK_URL=$DISCORD_WEBHOOK_URL" >> "$CONFIG_FILE"
}

# Function to prompt for configuration if not set
prompt_for_config() {
    [ -z "$token_id" ] && read -p $'\e[34mEnter Token ID: \e[0m' token_id
    [ -z "$tracker_url" ] && read -p $'\e[34mEnter Tracker URL (e.g., http://localhost:3000): \e[0m' tracker_url
    save_config
}

# Function to ensure tracker URL is correctly formatted
format_tracker_url() {
    tracker_url="${tracker_url%/}"
    tracker_url="${tracker_url%/api}"
}

# Function to display token information
display_token_info() {
    local token_id=$1
    echo -e "${BLUE}Fetching token information...${NC}"
    python3 ./cat20.py "$token_id"
}

# Function to get current timestamp
get_timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

# Function to format time
format_time() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(( (seconds % 3600) / 60 ))
    seconds=$((seconds % 60))
    printf "%02d:%02d:%02d" $hours $minutes $seconds
}

# Function to send Discord notification
send_discord_notification() {
    local title="$1"
    local content="$2"
    if ! python3 discord_notifier.py "$title" "$content"; then
        echo -e "${YELLOW}Failed to send Discord notification. Continuing without notification.${NC}"
    fi
}

# Fetch the wallet address after configuration is complete
fetch_wallet_address() {
    echo -e "${BLUE}Fetching wallet address...${NC}"
    wallet_address=$(sudo yarn cli wallet address -t "$tracker_url" 2>&1 | grep -oE 'bc1[a-zA-Z0-9]{25,}' | head -n 1)
    
    if [[ "$wallet_address" =~ ^bc1 ]]; then
        echo -e "${BLUE}Wallet Address: $wallet_address${NC}"
        send_discord_notification "Wallet Address" "Address: $wallet_address\n=======================\n"
    else
        echo -e "${RED}Error: Invalid wallet address format.${NC}"
        send_discord_notification "Error Fetching Wallet Address" "Invalid wallet address format: $wallet_address\n=======================\n"
        exit 1
    fi
}

# Function to fetch and display FB wallet balance
fetch_fb_balance() {
    echo -e "${BLUE}Fetching FB wallet balance...${NC}"
    
    local api_url="https://mempool.fractalbitcoin.io/api/address/${wallet_address}"
    local api_response=$(curl -sSL "$api_url")
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error fetching FB wallet information from API:${NC}" >&2
        echo "$api_response" >&2
        send_discord_notification "Error Fetching FB Wallet Info" "Unable to retrieve FB wallet information from API.\n=======================\n"
        return 1
    else
        # Parse JSON response using jq
        local chain_funded=$(echo "$api_response" | jq -r '.chain_stats.funded_txo_sum')
        local chain_spent=$(echo "$api_response" | jq -r '.chain_stats.spent_txo_sum')
        local mempool_funded=$(echo "$api_response" | jq -r '.mempool_stats.funded_txo_sum')
        local mempool_spent=$(echo "$api_response" | jq -r '.mempool_stats.spent_txo_sum')
        local utxo_count=$(echo "$api_response" | jq -r '.chain_stats.funded_txo_count - .chain_stats.spent_txo_count')

        # Calculate confirmed and unconfirmed balances
        local confirmed_balance=$(echo "$chain_funded - $chain_spent" | bc)
        local unconfirmed_balance=$(echo "$mempool_funded - $mempool_spent" | bc)

        # Convert satoshis to FB
        local confirmed_fb=$(echo "scale=8; $confirmed_balance / 100000000" | bc)
        local unconfirmed_fb=$(echo "scale=8; $unconfirmed_balance / 100000000" | bc)

        echo -e "${BLUE}FB Wallet Balance for address $wallet_address:${NC}"
        echo -e "Confirmed Balance: $confirmed_fb FB ($confirmed_balance sats)"
        echo -e "Unconfirmed Balance: $unconfirmed_fb FB ($unconfirmed_balance sats)"
        echo -e "UTXO Count: $utxo_count"

        send_discord_notification "FB Wallet Balance" "Address: $wallet_address\nConfirmed: $confirmed_fb FB ($confirmed_balance sats)\nUnconfirmed: $unconfirmed_fb FB ($unconfirmed_balance sats)\nUTXO Count: $utxo_count\n=======================\n"
    fi
}

# Function to fetch and display CAT20 wallet balances
fetch_cat20_balances() {
    echo -e "${BLUE}Fetching CAT20 wallet balances...${NC}"
    local balances_output
    balances_output=$(sudo yarn cli wallet balances -t "$tracker_url" 2>&1)
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error fetching CAT20 wallet balances:${NC}" >&2
        echo "$balances_output" >&2
        send_discord_notification "Error Fetching Wallet Balances" "Unable to retrieve CAT20 wallet balances.\n=======================\n"
    else
        echo -e "${BLUE}CAT20 Wallet Balances:${NC}"
        echo "$balances_output"
        local formatted_balances=$(echo "$balances_output" | awk '
        BEGIN { FS="[ │]+" }
        NR>4 && $0 !~ /^┴/ {
            gsub(/^[\047]|[\047]$/, "", $2)  # Remove single quotes from tokenId
            gsub(/^[\047]|[\047]$/, "", $3)  # Remove single quotes from symbol
            gsub(/^[\047]|[\047]$/, "", $4)  # Remove single quotes from balance
            if ($2 != "" && $3 != "" && $4 != "") {
                print "Token ID: " $2 "\nSymbol: " $3 "\nBalance: " $4
            }
        }
        ' | sed '/^$/d')
        local execution_time=$(echo "$balances_output" | grep -oP 'Done in \K[0-9.]+s')
        formatted_balances+="\n\nExecution time: $execution_time"
        send_discord_notification "CAT20 Balances" "$formatted_balances\n=======================\n"
    fi
}

# Function to execute the minting process
execute_mint() {
    echo -e "${BLUE}Executing: sudo yarn cli mint -i "$token_id" --fee-rate "$current_fee" -t "$tracker_url"${NC}"
    local mint_output
    mint_output=$(sudo yarn cli mint -i "$token_id" --fee-rate "$current_fee" -t "$tracker_url" 2>&1)
    local exit_code=$?
    echo "$mint_output"
    return $exit_code
}

# Load configuration
load_config

# Parse options
while getopts ":i:n:" option; do
    case $option in
        i) token_id=$OPTARG ;;
        n) total_mints=$OPTARG ;;
        *) echo -e "${RED}Usage: $0 [-i <tokenID>] [-n <number of mints>]${NC}" >&2
           exit 1 ;;
    esac
done

# Prompt for configuration if needed
[ -z "$token_id" ] && prompt_for_config

# Confirm Token ID and Tracker URL
while true; do
    echo -e "${BLUE}Token ID: $token_id${NC}"
    read -p $'\e[34mIs this the correct Token ID? (y/N or enter new Token ID): \e[0m' confirm_token_id
    if [[ "$confirm_token_id" =~ ^[Yy]$ ]]; then
        display_token_info "$token_id"
        break
    elif [[ -n "$confirm_token_id" && "$confirm_token_id" != "n" ]]; then
        token_id="$confirm_token_id"
        display_token_info "$token_id"
        save_config
    else
        read -p $'\e[34mEnter new Token ID: \e[0m' token_id
        display_token_info "$token_id"
        save_config
    fi
done

while true; do
    format_tracker_url
    echo -e "${BLUE}Tracker URL: $tracker_url${NC}"
    read -p $'\e[34mIs this the correct Tracker URL? (y/N or enter new URL): \e[0m' confirm_tracker_url
    if [[ "$confirm_tracker_url" =~ ^[Yy]$ ]]; then
        break
    elif [[ -n "$confirm_tracker_url" && "$confirm_tracker_url" != "n" ]]; then
        tracker_url="$confirm_tracker_url"
        format_tracker_url
        save_config
    else
        read -p $'\e[34mEnter new Tracker URL: \e[0m' tracker_url
        format_tracker_url
        save_config
    fi
done

# Prompt for Discord webhook URL
if [ -z "$DISCORD_WEBHOOK_URL" ]; then
    read -p $'\e[34mEnter Discord webhook URL (leave blank to skip Discord notifications): \e[0m' DISCORD_WEBHOOK_URL
    save_config
else
    echo -e "${BLUE}Current Discord webhook URL: $DISCORD_WEBHOOK_URL${NC}"
    read -p $'\e[34mIs this correct? (Y/n or enter new URL): \e[0m' confirm_webhook
    if [[ "$confirm_webhook" =~ ^[Nn]$ ]]; then
        read -p $'\e[34mEnter new Discord webhook URL: \e[0m' DISCORD_WEBHOOK_URL
        save_config
    fi
fi

# Export Discord webhook URL as an environment variable
export DISCORD_WEBHOOK_URL

# Fetch wallet address after configuration is complete
fetch_wallet_address

# Fetch CAT20 wallet balances immediately after fetching the wallet address
fetch_cat20_balances

# Prompt for number of mints if not provided as an option
[ -z "$total_mints" ] && read -p $'\e[34mEnter the number of mints to perform (leave blank for ongoing minting): \e[0m' total_mints

# Prompt for gas fee limit feature
read -p $'\e[34mDo you want to set a gas fee limit? (y/N): \e[0m' use_gas_limit
if [[ "$use_gas_limit" =~ ^[Yy]$ ]]; then
    read -p $'\e[34mEnter the gas fee limit in sat/vB: \e[0m' gas_fee_limit
    read -p $'\e[34mEnter the buffer percentage for the gas fee limit (e.g., 10 for 10%): \e[0m' gas_fee_buffer
    max_fee_limit=$((gas_fee_limit + (gas_fee_limit * gas_fee_buffer / 100)))
    echo -e "${BLUE}Gas fee limit set to $gas_fee_limit sat/vB with $gas_fee_buffer% buffer (max $max_fee_limit sat/vB)${NC}"
    token_details=$(python3 ./cat20.py "$token_id" | sed 's/^/• /')
    send_discord_notification "Minting Process Started" "Token Details:\n$token_details\n\nMinting Configuration:\n• Token ID: $token_id\n• Gas Fee Limit: $gas_fee_limit sat/vB\n• Buffer: $gas_fee_buffer%\n• Max Fee: $max_fee_limit sat/vB\n• Tracker URL: $tracker_url\n=======================\n"
else
    gas_fee_limit=""
    gas_fee_buffer=""
    max_fee_limit=""
    echo -e "${YELLOW}No gas fee limit set. Proceeding with normal operation.${NC}"
    token_details=$(python3 ./cat20.py "$token_id" | sed 's/^/• /')
    send_discord_notification "Minting Process Started" "Token Details:\n$token_details\n\nMinting Configuration:\n• Token ID: $token_id\n• No Gas Fee Limit\n• Tracker URL: $tracker_url\n=======================\n"
fi

# Display initial wallet balances
echo -e "${BLUE}Fetching initial wallet balances...${NC}"
fetch_cat20_balances

# Fetch initial FB wallet balance
fetch_fb_balance

# Main loop
mint_count=0
start_time=$(date +%s)

current_timestamp=$(get_timestamp)
echo -e "${BLUE}$current_timestamp Starting minting process${NC}"
send_discord_notification "Minting Process Started" "$current_timestamp\nStarting minting process\nTarget mints: ${total_mints:-Ongoing}\nMint count: $mint_count\nTime elapsed: 00:00:00\n=======================\n"

while true; do
    current_fee=$(./fees.sh)
    current_timestamp=$(get_timestamp)
    echo -e "${BLUE}$current_timestamp Current fee rate: $current_fee sat/vB${NC}"

    if [ -n "$gas_fee_limit" ] && [ $current_fee -gt $max_fee_limit ]; then
        message="Current fee ($current_fee sat/vB) is above the maximum limit ($max_fee_limit sat/vB). Waiting 30 sec to fetch new fees rate"
        echo -e "${YELLOW}$current_timestamp $message${NC}"
        send_discord_notification "Fee above limit" "$current_timestamp\n$message\nMint count: $mint_count\nTime elapsed: $(format_time $(($(date +%s) - start_time)))\n=======================\n"
        sleep 30
        continue
    fi

    echo -e "${BLUE}$current_timestamp Attempting to mint with fee rate: $current_fee sat/vB (Mint #$((mint_count + 1)))${NC}"
    mint_result=$(execute_mint)
    exit_code=$?

    # Extract important details from mint_result
    token_name=$(echo "$mint_result" | grep -oP 'token \[\K[^\]]+')
    minted_amount=$(echo "$mint_result" | grep -oP 'Minting \K[0-9.]+ [A-Za-z0-9_]+')
    txid=$(echo "$mint_result" | grep -oP 'txid: \K[a-f0-9]+')

    current_timestamp=$(get_timestamp)
    if [ $exit_code -eq 0 ] && [ -n "$txid" ]; then
        ((mint_count++))
        echo -e "${BLUE}$current_timestamp Mint #$mint_count successful:${NC}"
        echo -e "Token: $token_name"
        echo -e "Amount minted: $minted_amount"
        echo -e "Transaction ID: $txid"
        send_discord_notification "Mint Successful" "$current_timestamp\nMint #$mint_count\nToken: $token_name\nAmount minted: $minted_amount\nTransaction ID: $txid\nTime elapsed: $(format_time $(($(date +%s) - start_time)))\n=======================\n"
    else
        echo -e "${RED}$current_timestamp Mint failed:${NC}"
        echo "$mint_result"
        error_message="Mint failed. Exit code: $exit_code"
        if [ -z "$txid" ]; then
            error_message+="\nNo transaction ID available."
        fi
        mint_error_details=$(echo "$mint_result" | grep -i "error")
        if [ -n "$mint_error_details" ]; then
            error_message+="\nError details: $mint_error_details"
        else
            error_message+="\nNo specific error message found in the output."
        fi
        send_discord_notification "Mint Failed" "$current_timestamp\n$error_message\nMint count: $mint_count\nTime elapsed: $(format_time $(($(date +%s) - start_time)))\nFull output:\n$mint_result\n=======================\n"
    fi

    # Check wallet balances every 3 mints
    if ((mint_count % 3 == 0)); then
        current_timestamp=$(get_timestamp)
        echo -e "${BLUE}$current_timestamp Fetching wallet balances after $mint_count mints...${NC}"
        fetch_cat20_balances
        fetch_fb_balance
    fi

    # Check if we've reached the desired number of mints
    if [ -n "$total_mints" ] && [ "$mint_count" -ge "$total_mints" ]; then
        break
    fi

    current_timestamp=$(get_timestamp)
    echo -e "${BLUE}$current_timestamp Completed $mint_count mints. Sleeping for 5 seconds before next mint...${NC}"
    sleep 5
done

# Final completion message (outside the loop)
current_timestamp=$(get_timestamp)
echo -e "${BLUE}$current_timestamp Minting process finished.${NC}"
send_discord_notification "Minting Process Completed" "$current_timestamp\nTotal Mints: $mint_count\nTime elapsed: $(format_time $(($(date +%s) - start_time)))\n=======================\n"

# Fetch final balances
fetch_cat20_balances
fetch_fb_balance
