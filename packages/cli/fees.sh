#!/bin/bash

get_precise_fee_rate() {
    # Fetch the fee data from the Fractal Bitcoin mempool API
    response=$(curl -sSL "https://mempool.fractalbitcoin.io/api/v1/fees/mempool-blocks")

    # Extract the median fee from the fastest confirming block (first block in the response)
    median_fee=$(echo "$response" | jq '.[0].medianFee')

    # Check if the median fee was successfully retrieved
    if [ -z "$median_fee" ] || [ "$median_fee" = "null" ]; then
        echo "Error: Could not fetch fee rate."
        exit 1
    fi

    # Add a fixed buffer of 50 to the median fee
    buffered_fee=$(echo "$median_fee + 50" | bc)

    # Return the buffered fee, rounded to the nearest integer
    echo $(printf "%.0f" "$buffered_fee")
}

# Call the function to get the precise fee rate
get_precise_fee_rate
