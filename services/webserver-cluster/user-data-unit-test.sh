#!/bin/bash

export db_address=12.34.56.78
export db_port=5555
export server_port=8888

bash user-data.sh
output=$(curl "http://localhost:$server_port")
echo $output
if [[ $output == *"Hello, World"* ]]; then
echo "Success! Got expected text from server."
else
echo "Error. Did not get back expected text 'Hello, World'."
fi
pkill busybox