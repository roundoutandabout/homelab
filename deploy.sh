#!/bin/bash
set -euo pipefail

# Parse simple CLI options (supports --dry-run / -n)
DRY_RUN=false
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            cat <<EOF
Usage: $0 [--dry-run]

Options:
  -n, --dry-run   Show actions that would be taken and run rsync in --dry-run mode
  -h, --help      Show this help message
EOF
            exit 0
            ;;
        *)
            break
            ;;
    esac
done

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

        remote_prep_cmd="mkdir -p '$remote_dir' && chown $SERVER_USER:$SERVER_USER '$remote_dir' 2>/dev/null || true && chmod 0700 '$remote_dir'"

        if [[ "$DRY_RUN" == true ]]; then
            echo "[DRY-RUN] remote command: $remote_prep_cmd"
        else
            ssh -A -i "$SSH_KEY" -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST" \
                "$remote_prep_cmd" || {
                echo "Error: failed to create/prepare remote directory '$remote_dir' as non-root on $SERVER_HOST" >&2
                exit 1
            }
        fi
    else
		if ssh -A -i "$SSH_KEY" -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST" "test -d '$remote_dir'"; then
			echo "Remote directory '$remote_dir' exists — continuing."
		else
			echo "Error: remote directory '$remote_dir' is outside /home and does not exist. Please create it manually on the server (with sudo) and then re-run deploy.sh." >&2
			exit 1
		fi
    fi

    # Build dry-run flag for rsync
    dry_flag=""
    if [[ "$DRY_RUN" == true ]]; then
        dry_flag="--dry-run"
    fi

    if [[ "$DRY_RUN" == true ]]; then
        echo "Running rsync (dry-run) for $local_file -> $remote_file"
    else
        echo "Running rsync for $local_file -> $remote_file"
    fi
    # Prevent rsync from overwriting permissions we set on the remote directory.
    # rsync -a preserves permissions from the source; when we create a 0700
    # directory beforehand, rsync can change it back to the source's 0755.
    # Use --no-perms so rsync won't modify permission bits on the receiver.
    rsync -avz --no-perms $dry_flag \
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