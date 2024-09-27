#!/usr/bin/env python3
import argparse
import requests

def get_token_data(token_id):
    url = f"https://cat20-indexer.ordinalswallet.com/api/tokens/{token_id}"
    try:
        response = requests.get(url)
        response.raise_for_status()
        return response.json()["data"]
    except requests.exceptions.RequestException as e:
        print(f"Request failed: {e}")
        return None

def calculate_minting_progress(current_supply, max_supply):
    if max_supply <= 0:
        return 0
    return (current_supply / max_supply) * 100

def format_with_commas(number):
    return f"{number:,}"

def main():
    parser = argparse.ArgumentParser(description="Token Info Script")
    parser.add_argument("id", help="The token ID to query")
    args = parser.parse_args()

    token_data = get_token_data(args.id)
    
    if token_data:
        try:
            max_supply = int(token_data['info']['max'])
            mint_limit = int(token_data['info']['limit'])
            premine = int(token_data['info']['premine'])
            decimals = int(token_data['decimals'])
            
            supply_url = f"https://cat20-indexer.ordinalswallet.com/api/tokens/{args.id}/supply"
            supply_response = requests.get(supply_url)
            supply_response.raise_for_status()
            current_supply = int(supply_response.json()['data']['supply'])
            
            adjusted_current_supply = current_supply / (10 ** decimals)
            
            minting_progress = calculate_minting_progress(adjusted_current_supply, max_supply)

            print(f"Token Details:\n{'='*30}")
            print(f"Name: {token_data['name']}")
            print(f"Symbol: {token_data['symbol']}")
            print(f"Max Supply: {format_with_commas(max_supply)}")
            print(f"Decimals: {decimals}")
            print(f"Premine: {format_with_commas(premine)}")
            print(f"Minting Limit per UTXO: {format_with_commas(mint_limit)}")
            print(f"Current Supply: {adjusted_current_supply:,.2f}")
            print(f"Minting Progress: {minting_progress:.2f}% of max supply minted.")

            if adjusted_current_supply > max_supply:
                excess = adjusted_current_supply - max_supply
                excess_percentage = (excess / max_supply) * 100
                print(f"Note: Current supply exceeds max supply by {excess:,.2f} tokens ({excess_percentage:.2f}% over max supply).")

        except KeyError as e:
            print(f"Error: Missing expected key in token data - {e}")
        except ValueError as e:
            print(f"Error: Invalid data type encountered - {e}")
    else:
        print("Failed to retrieve token data. Please check the token ID or the tracker server.")

if __name__ == "__main__":
    main()
