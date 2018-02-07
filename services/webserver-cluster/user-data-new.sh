#!/bin/bash
cd /tmp
echo "Hello, World, v2" > index.html
nohup busybox httpd -f -p "${server_port}" &