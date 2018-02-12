#!/bin/bash

cd .kitchen/kitchen-terraform/$KITCHEN_SUITE-$KITCHEN_PLATFORM
hostname=$(terraform output app_endpoint)

output=$(curl "http://$hostname")

if [[ $output == *"Hello, World1"* ]]; then
    echo "***Integration test passed!!!***"
    exit 0
else
    echo "***Integration test failed!!!***"
    exit 1
fi