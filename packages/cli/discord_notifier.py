import sys
import requests
import json
import os

# Function to map title to emoticon
def get_emoticon(title):
    emoticon_map = {
        "Minting Process Started": "😎",
        "CAT20 Balances": "😼",
        "Fee above limit": "⚠️",
        "Mint Successful": "✅",
        "Mint Failed": "❌",
        "Updated CAT20 Balances": "😼",
        "Error Fetching Wallet Balances": "🚫",
        "Minting Process Completed": "🏁",
        "FB Wallet Balance": "🤑",
        "Error Fetching FB Wallet Info": "🚫",
        "Error Fetching Wallet Address": "🚫",
        "Wallet Address": "🔑"
    }
    return emoticon_map.get(title, "🚨")

# Function to format content nicely
def format_message(title, content):
    # Remove unnecessary newlines and backticks
    content = content.replace("\\n", "\n").replace("`", "")
    
    # Special formatting for CAT20 balances
    if title == "CAT20 Balances":
        lines = content.split('\n')
        formatted_lines = []
        for line in lines:
            if line.startswith("Token ID:") or line.startswith("Symbol:") or line.startswith("Balance:"):
                formatted_lines.append(line.strip())
            elif line == "=======================":
                formatted_lines.append(line)
        content = "\n".join(formatted_lines)
    
    # Ensure there's only one separator at the end
    content = content.rstrip("=\n") + "\n=======================\n"
    
    return content

# Function to send Discord message
def send_discord_message(webhook_url, title, content):
    emoticon = get_emoticon(title)
    formatted_content = format_message(title, content)
    message = f"{emoticon} **{title}**\n{formatted_content}"
    
    payload = {"content": message}
    response = requests.post(webhook_url, data=json.dumps(payload), headers={"Content-Type": "application/json"})
    
    if response.status_code != 204:
        print(f"Failed to send Discord message. Status code: {response.status_code}")
        print(f"Response: {response.text}")
    else:
        print(f"Discord message sent successfully: {title}")

# Main function to send messages
if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 discord_notifier.py '<title>' '<content>'")
        sys.exit(1)
    
    webhook_url = os.getenv('DISCORD_WEBHOOK_URL')
    
    if not webhook_url:
        print("Error: DISCORD_WEBHOOK_URL environment variable not set.")
        sys.exit(1)
    
    title, content = sys.argv[1], sys.argv[2]
    send_discord_message(webhook_url, title, content)
