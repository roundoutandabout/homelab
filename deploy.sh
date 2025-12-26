#!/bin/bash
set -euo pipefail

# Load configuration from external file
CONFIG_FILE="./deploy.conf"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Configuration file '$CONFIG_FILE' not found. Please create it with SERVER_USER, SERVER_HOST, etc."
    exit 1
fi
source "$CONFIG_FILE"

# Mapping: local file path → remote file path on server
declare -A MAP=(
#    ["caddy/"]="/home/$SERVER_USER/caddy/"
#    ["homer/"]="/home/$SERVER_USER/homer/"
#    ["nextcloud-aio/"]="/home/$SERVER_USER/nextcloud-aio/"
    ["borgmatic/config.yaml"]="/etc/borgmatic/config.yaml"
    ["borgmatic/borgmatic.service"]="/etc/systemd/system/borgmatic.service"
	["borgmatic/borgmatic.timer"]="/etc/systemd/system/borgmatic.timer"
#	["borgmatic/credentials.txt"]="/etc/borgmatic/credentials.txt"
    # Add more as needed
)

# Sync each file
for local_file in "${!MAP[@]}"; do
    remote_file="${MAP[$local_file]}"
    echo "Syncing $local_file → $remote_file"
    rsync -avz \
        -e "ssh -A -i $SSH_KEY -p $SERVER_PORT" \
        --rsync-path="sudo rsync" \
		"$local_file" \
        "$SERVER_USER@$SERVER_HOST:$remote_file"
done

# Optional: Restart services after sync (uncomment/adjust as needed)
# ssh -i "$SSH_KEY" -p $SERVER_PORT "$SERVER_USER@$SERVER_HOST" <<'EOF'
#     sudo systemctl daemon-reload
#     sudo systemctl enable --now borgmatic.timer
#     # Add Docker restarts: sudo docker-compose -f /opt/nextcloud-aio/docker-compose.yml up -d
# EOF

echo "Deployment complete!"