#!/bin/bash

set -e

echo "================================="
echo "TANTO VPS Bootstrap"
echo "================================="

bash scripts/system.sh
bash scripts/security.sh
bash scripts/docker.sh

echo "Bootstrap complete."
