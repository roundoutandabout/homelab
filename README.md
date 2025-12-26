# Home-Server Configuration Repository

A collection of Docker‑compose files, service definitions, and other configuration assets that I use to run my personal home server.

## Quick Deployment Guide

1. **Run the deployment script**  
	```bash
	./deploy.sh
	```
	The script reads variables from `deploy.conf`. Create this file (or copy `deploy.conf.example`) and fill in the values that match your server setup.

2. **Enable password‑less `rsync`**  
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