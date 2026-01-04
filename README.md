# Home-Server Configuration Repository

A collection of Docker‑compose files, service definitions, and other configuration assets that I use to run my personal home server.

## Quick Deployment Guide

1. **Run the deployment script**  
	```bash
	./deploy.sh
	```
	The script reads variables from `deploy.conf`. Create this file (or copy `deploy.conf.template`) and fill in the values that match your server setup.

	Options:

	- `-n, --dry-run` — show the remote commands that would be run for directory preparation and run `rsync` in `--dry-run` mode (no files transferred).

	Examples:

	```bash
	# Show actions and run rsync in dry-run mode
	./deploy.sh --dry-run

	# Regular deployment
	./deploy.sh
	```

2. **Automatic directory handling & safety**

 - `deploy.sh` will automatically create remote directories when the target is under `/home/<user>/...`. Those directories are created as the remote user (no `sudo`), ownership is set to the deploy user when possible, and permissions are set to `0700`.
 - For safety, if a target is outside `/home` (for example `/etc` or `/opt`), `deploy.sh` will abort with an error and ask you to create the directory manually on the server (use `sudo mkdir -p ...` and set ownership/permissions as appropriate). This limits commands that run without an interactive sudo password.
 - The script also warns and skips any local `MAP` entries whose source path does not exist.

### Testing and manual steps

Run `deploy.sh` with tracing to observe what it will do:

```bash
bash -x ./deploy.sh
```

To manually create and verify a home directory on the remote host (no sudo required):

```bash
ssh -A -i "$SSH_KEY" -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST" \
  "mkdir -p '/home/$SERVER_USER/docker/borgmatic' && chmod 0700 '/home/$SERVER_USER/docker/borgmatic' && stat -c '%U %G %a %n' '/home/$SERVER_USER/docker/borgmatic'"
```

If you must create a directory outside `/home`, run this on the server as an administrator:

```bash
# on the server (as root)
sudo mkdir -p /opt/some/dir
sudo chown root:root /opt/some/dir
sudo chmod 0700 /opt/some/dir
```

3. **Enable password‑less `rsync`**  
	To let `rsync` operate without prompting for an SSH passphrase or a sudo password, set up an SSH agent and configure password‑less sudo on the target host.

	### SSH agent on your workstation
	```bash
	# Start and enable the per‑user ssh‑agent service
	systemctl --user start ssh-agent.service
	systemctl --user enable ssh-agent.service
	systemctl --user daemon-reload

	# Load your private key
	ssh-add ~/.ssh/id_rsa

	# Verify the key is loaded
	ssh-add -l
	```
	*Tip:* KeePassXC can also manage the SSH agent – see the [KeePassXC SSH‑agent FAQ](https://keepassxc.org/docs/#faq-ssh-agent-openssh).

	### Password‑less sudo on the server (Debian‑based)
	1. Install the PAM module that allows sudo to use the SSH agent:
		```bash
		sudo apt install libpam-ssh-agent-auth
		```
	2. Edit `/etc/pam.d/sudo` and prepend the following line (replace `<user>` with your actual username):
		```
		auth sufficient pam_ssh_agent_auth.so file=/home/<user>/.ssh/authorized_keys
		```
	3. Create a sudoers snippet to keep the SSH socket environment variable and allow `rsync` without a password:
		```bash
		sudo tee /etc/sudoers.d/ssh-auth > /dev/null <<'EOF'
		Defaults env_keep += "SSH_AUTH_SOCK"
		<user> ALL=(root) NOPASSWD: /usr/bin/rsync
		EOF
		```
		Adjust `<user>` accordingly.

That’s it! With the SSH agent and sudo configuration in place, `deploy.sh` can push updates to your home server automatically via `rsync`. Happy self‑hosting!