#!/bin/bash

# Update system
apt update && apt upgrade -y

# Install essentials
apt install -y git curl wget vim nano htop tmux tree unzip

# Install ZSH and Oh-My-ZSH
apt install -y zsh
chsh -s /bin/zsh ubuntu
runuser -l ubuntu -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'

# Install ZSH plugins
runuser -l ubuntu -c 'git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions'
runuser -l ubuntu -c 'git clone https://github.com/zsh-users/zsh-syntax-highlighting ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting'

# Configure ZSH
cat > /home/ubuntu/.zshrc << 'EOL'
export ZSH="/home/ubuntu/.oh-my-zsh"
ZSH_THEME="robbyrussell"
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt SHARE_HISTORY
plugins=(git zsh-autosuggestions zsh-syntax-highlighting history dirhistory docker docker-compose)
source $ZSH/oh-my-zsh.sh
alias ll='ls -alF'
alias la='ls -A'
alias update='sudo apt update && sudo apt upgrade -y'
alias gs='git status'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias dc='docker-compose'
alias dcup='docker-compose up -d'
alias dclog='docker-compose logs -f'
EOL

chown ubuntu:ubuntu /home/ubuntu/.zshrc

# Install Nginx
apt install -y nginx
systemctl enable nginx
systemctl start nginx

# Install Docker and Docker Compose
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker ubuntu
systemctl enable docker
systemctl start docker
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Configure SSH for GitHub
runuser -l ubuntu -c 'mkdir -p /home/ubuntu/.ssh'
runuser -l ubuntu -c 'ssh-keygen -t rsa -b 4096 -f /home/ubuntu/.ssh/github_key -C "ec2-instance" -N ""'
cat > /home/ubuntu/.ssh/config << 'EOL'
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/github_key
EOL

chmod 600 /home/ubuntu/.ssh/config
chown ubuntu:ubuntu /home/ubuntu/.ssh/config

# Set up application directory
mkdir -p /var/www/app
chown -R ubuntu:ubuntu /var/www/app

# Configure basic firewall
apt install -y ufw
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

echo "Setup complete!"
