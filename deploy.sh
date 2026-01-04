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
    ["borgmatic/"]="/home/$SERVER_USER/docker/borgmatic/"
#   ["caddy/"]="/home/$SERVER_USER/docker/caddy/"
#   ["homer/"]="/home/$SERVER_USER/docker/homer/"
#   ["nextcloud-aio/"]="/home/$SERVER_USER/docker/nextcloud-aio/"
#   ["borgmatic-package/config.yaml"]="/etc/borgmatic/config.yaml"
#   ["borgmatic-package/borgmatic.service"]="/etc/systemd/system/borgmatic.service"
#	["borgmatic-package/borgmatic.timer"]="/etc/systemd/system/borgmatic.timer"
#	["borgmatic/credentials.txt"]="/etc/borgmatic/credentials.txt"
    # Add more as needed
)

# Sync each file
for local_file in "${!MAP[@]}"; do
    remote_file="${MAP[$local_file]}"
    echo "Syncing $local_file → $remote_file"

    # Warn and skip if local path does not exist
    if [[ ! -e "$local_file" ]]; then
        echo "Warning: local path '$local_file' does not exist — skipping."
        continue
    fi

    # Determine remote directory target.
    # If the mapped remote path ends with '/', or the local path is a directory,
    # treat the remote target itself as a directory. Otherwise use dirname().
    if [[ "${remote_file: -1}" == "/" ]] || [[ -d "$local_file" ]]; then
        remote_dir="${remote_file%/}"
    else
        remote_dir=$(dirname "$remote_file")
    fi

    echo "Ensuring remote directory exists: $remote_dir"

    # Only create remote directories automatically when they are under /home.
    # For safety, require manual creation for paths outside /home.
    if [[ "$remote_dir" == /home/* ]]; then
        echo "Preparing directory under /home on remote host (no sudo): $remote_dir"

        # Attempt to create directory and set permissions as the remote user (no sudo).
        # Try chown but ignore failure (non-root users cannot change ownership).
        ssh -A -i "$SSH_KEY" -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST" \
            "mkdir -p '$remote_dir' && chown $SERVER_USER:$SERVER_USER '$remote_dir' 2>/dev/null || true && chmod 0700 '$remote_dir'" || {
            echo "Error: failed to create/prepare remote directory '$remote_dir' as non-root on $SERVER_HOST" >&2
            exit 1
        }
    else
        echo "Error: remote directory '$remote_dir' is outside /home — please create it manually on the server (with sudo) and then re-run deploy.sh." >&2
        exit 1
    fi

    rsync -avz \
        -e "ssh -A -i $SSH_KEY -p $SERVER_PORT" \
        --rsync-path="sudo rsync" \
        "$local_file" \
        "$SERVER_USER@$SERVER_HOST:$remote_file"
done

# Optional: Restart services after sync (uncomment/adjust as needed)
# ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_HOST" -p $SERVER_PORT <<'EOF'
#     sudo systemctl daemon-reload
#     sudo systemctl enable --now borgmatic.timer
#     # Add Docker restarts: sudo docker-compose -f /opt/nextcloud-aio/docker-compose.yml up -d
# EOF

echo "Deployment complete!"