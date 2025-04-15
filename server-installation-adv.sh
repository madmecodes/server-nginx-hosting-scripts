#!/bin/bash

# Colors for better readability
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored messages
print_message() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    if [ "$2" = "exit" ]; then
        exit 1
    fi
}

print_step() {
    echo -e "\n${CYAN}[STEP]${NC} $1"
    echo -e "${CYAN}$(printf '=%.0s' {1..50})${NC}"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run this script as root or with sudo" "exit"
fi

# Function to run commands and check for errors
run_command() {
    local cmd="$1"
    local msg="$2"
    
    print_message "$msg"
    eval "$cmd"
    
    if [ $? -ne 0 ]; then
        print_error "Failed to execute: $cmd"
        return 1
    else
        print_success "Command completed successfully"
        return 0
    fi
}

# Banner
echo -e "${GREEN}"
echo "=============================================="
echo "       SERVER SETUP & CONFIGURATION SCRIPT    "
echo "=============================================="
echo -e "${NC}"

# Start timing the script execution
start_time=$(date +%s)

# Ask for custom username (default: ubuntu)
read -p "Enter the system username (default: ubuntu): " USERNAME
USERNAME=${USERNAME:-ubuntu}

print_message "Starting setup for user: $USERNAME"
print_message "Current date and time: $(date)"
print_message "Server hostname: $(hostname)"
print_message "Server IP address: $(hostname -I | awk '{print $1}')"

# Update system
print_step "1. UPDATING SYSTEM PACKAGES"
run_command "apt update" "Updating package lists" || print_error "Failed to update package lists"
run_command "apt upgrade -y" "Upgrading installed packages" || print_warning "Some packages might not have been upgraded"

# Install essentials
print_step "2. INSTALLING ESSENTIAL PACKAGES"
ESSENTIAL_PACKAGES="git curl wget vim nano htop tmux tree unzip jq net-tools dnsutils apt-transport-https ca-certificates gnupg lsb-release software-properties-common"
print_message "Packages to be installed: $ESSENTIAL_PACKAGES"
run_command "apt install -y $ESSENTIAL_PACKAGES" "Installing essential tools"

# Optional tools
print_step "3. OPTIONAL DEVELOPMENT TOOLS"
print_message "Do you want to install additional development tools? (y/n)"
read -p "This includes build-essential, python3, nodejs, etc.: " INSTALL_DEV_TOOLS

if [[ "${INSTALL_DEV_TOOLS,,}" == "y" ]]; then
    print_message "Installing development tools..."
    run_command "apt install -y build-essential python3 python3-pip python3-venv" "Installing Python packages"
    
    # Node.js installation
    print_message "Installing Node.js LTS version..."
    run_command "curl -fsSL https://deb.nodesource.com/setup_18.x | bash -" "Setting up Node.js repository"
    run_command "apt install -y nodejs" "Installing Node.js"
    print_message "Node.js version: $(node -v)"
    print_message "NPM version: $(npm -v)"
    
    # Optional: Install Yarn
    print_message "Do you want to install Yarn package manager? (y/n)"
    read -p "Install Yarn? " INSTALL_YARN
    if [[ "${INSTALL_YARN,,}" == "y" ]]; then
        run_command "curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -" "Adding Yarn GPG key"
        run_command "echo 'deb https://dl.yarnpkg.com/debian/ stable main' | tee /etc/apt/sources.list.d/yarn.list" "Setting up Yarn repository"
        run_command "apt update && apt install -y yarn" "Installing Yarn"
        print_message "Yarn version: $(yarn --version)"
    fi
fi

# Install ZSH and Oh-My-ZSH
print_step "4. SETTING UP ZSH AND OH-MY-ZSH"
run_command "apt install -y zsh" "Installing ZSH"
run_command "chsh -s /bin/zsh $USERNAME" "Setting ZSH as default shell for $USERNAME"

# Check if user exists
if id "$USERNAME" &>/dev/null; then
    run_command "runuser -l $USERNAME -c 'sh -c \"$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" \"\" --unattended'" "Installing Oh-My-ZSH"

    # Install ZSH plugins
    print_message "Installing ZSH plugins..."
    run_command "runuser -l $USERNAME -c 'git clone https://github.com/zsh-users/zsh-autosuggestions \${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions'" "Installing zsh-autosuggestions plugin"
    run_command "runuser -l $USERNAME -c 'git clone https://github.com/zsh-users/zsh-syntax-highlighting \${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting'" "Installing zsh-syntax-highlighting plugin"
    
    # Install powerlevel10k theme
    print_message "Do you want to install the powerlevel10k theme? (y/n)"
    read -p "Install powerlevel10k? " INSTALL_P10K
    if [[ "${INSTALL_P10K,,}" == "y" ]]; then
        run_command "runuser -l $USERNAME -c 'git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k'" "Installing powerlevel10k theme"
        print_message "You'll need to manually configure powerlevel10k by running 'p10k configure' after logging in"
    fi

    # Configure ZSH
    print_message "Configuring ZSH..."
    cat > /home/$USERNAME/.zshrc << 'EOL'
export ZSH="$HOME/.oh-my-zsh"

# Set theme - uncomment one of these
ZSH_THEME="robbyrussell"
# ZSH_THEME="powerlevel10k/powerlevel10k"

# History configuration
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt SHARE_HISTORY

# Plugins
plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
    history
    dirhistory
    docker
    docker-compose
    kubectl
    ssh-agent
    copypath
    extract
)

source $ZSH/oh-my-zsh.sh

# Aliases
# General
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias c='clear'
alias h='history'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# System
alias update='sudo apt update && sudo apt upgrade -y'
alias sysinfo='echo "$(uname -a) | RAM: $(free -h | awk "/^Mem/ {print \$2}") | CPU: $(grep -c processor /proc/cpuinfo) cores"'
alias diskspace='df -h'
alias ports='netstat -tulanp'
alias reload='source ~/.zshrc'
alias myip='curl -s http://checkip.amazonaws.com'
alias meminfo='free -m'
alias cpuinfo='cat /proc/cpuinfo | grep "model name" | head -1'
alias processes='ps aux | sort -nrk 3,3 | head -n 20'
alias listening='netstat -tulpn | grep LISTEN'

# Git
alias gs='git status'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gb='git branch'
alias gco='git checkout'
alias glog='git log --oneline --graph --decorate'
alias git_sudo='sudo -E GIT_SSH_COMMAND="ssh -i ~/.ssh/github_key" git'
alias gitkey='cat ~/.ssh/github_key.pub'

# Docker
alias d='docker'
alias dc='docker-compose'
alias dcup='docker-compose up -d'
alias dcdown='docker-compose down'
alias dclog='docker-compose logs -f'
alias dps='docker ps'
alias dimg='docker images'
alias drm='docker rm'
alias drmi='docker rmi'
alias dprune='docker system prune -a'
alias dlogs='docker logs -f'

# Nginx
alias nginx-test='sudo nginx -t'
alias nginx-reload='sudo systemctl reload nginx'
alias nginx-restart='sudo systemctl restart nginx'
alias nginx-status='sudo systemctl status nginx'
alias nginx-error='sudo tail -f /var/log/nginx/error.log'
alias nginx-access='sudo tail -f /var/log/nginx/access.log'

# SSH
alias ssh-create='ssh-keygen -t rsa -b 4096'
alias ssh-copy='ssh-copy-id -i ~/.ssh/id_rsa.pub'
alias ssh-list='ls -la ~/.ssh'

# System services
alias sysctl-list='systemctl list-units --type=service'
alias sysctl-running='systemctl list-units --type=service --state=running'
alias sysctl-failed='systemctl list-units --type=service --state=failed'

# Custom Functions
# Extract any archive format
extract() {
  if [ -f $1 ] ; then
    case $1 in
      *.tar.bz2)   tar xjf $1     ;;
      *.tar.gz)    tar xzf $1     ;;
      *.bz2)       bunzip2 $1     ;;
      *.rar)       unrar e $1     ;;
      *.gz)        gunzip $1      ;;
      *.tar)       tar xf $1      ;;
      *.tbz2)      tar xjf $1     ;;
      *.tgz)       tar xzf $1     ;;
      *.zip)       unzip $1       ;;
      *.Z)         uncompress $1  ;;
      *.7z)        7z x $1        ;;
      *)           echo "'$1' cannot be extracted via extract()" ;;
    esac
  else
    echo "'$1' is not a valid file"
  fi
}

# Create directory and navigate into it
mkcd() {
  mkdir -p "$1" && cd "$1"
}

# Print directory tree with gitignore aware
gittree() {
  find . -type f | grep -v ".git" | sort
}

# Find large files
findlarge() {
  find . -type f -size +${1:-20}M -exec ls -lh {} \; | sort -k5 -rh
}

# Create a new directory and enter it
md() {
  mkdir -p "$@" && cd "$1"
}

# Find process by name
findproc() {
  ps aux | grep -i "$1" | grep -v grep
}

# Get HTTP status code for a URL
httpstatus() {
  curl -s -o /dev/null -w "%{http_code}" "$1"
}

# Set up simple Python HTTP server
pyserver() {
  local port=${1:-8000}
  python3 -m http.server $port
}

# Find files by name
ff() {
  find . -type f -name "*$1*"
}

# Generate random password
genpass() {
  local length=${1:-16}
  tr -dc 'A-Za-z0-9!@#$%^&*()_+' < /dev/urandom | head -c $length; echo
}
EOL

    # Set permissions
    chown $USERNAME:$USERNAME /home/$USERNAME/.zshrc
    print_success "ZSH configured successfully"
else
    print_error "User $USERNAME does not exist. ZSH configuration skipped."
fi

# Install Docker and Docker Compose
print_step "5. INSTALLING DOCKER AND DOCKER COMPOSE"
run_command "curl -fsSL https://get.docker.com -o get-docker.sh" "Downloading Docker installation script"
run_command "sh get-docker.sh" "Installing Docker"
run_command "usermod -aG docker $USERNAME" "Adding $USERNAME to Docker group"
run_command "systemctl enable docker" "Enabling Docker service"
run_command "systemctl start docker" "Starting Docker service"

# Verify Docker installation
docker_version=$(docker --version)
if [ $? -eq 0 ]; then
    print_success "Docker installed successfully: $docker_version"
else
    print_error "Docker installation verification failed"
fi

# Install Docker Compose based on latest version
print_message "Installing Docker Compose..."
COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
if [ -z "$COMPOSE_VERSION" ]; then
    print_warning "Failed to get latest Docker Compose version. Using default installation method."
    run_command "curl -L \"https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)\" -o /usr/local/bin/docker-compose" "Downloading Docker Compose"
else
    print_message "Installing Docker Compose version: $COMPOSE_VERSION"
    run_command "curl -L \"https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)\" -o /usr/local/bin/docker-compose" "Downloading Docker Compose $COMPOSE_VERSION"
fi
run_command "chmod +x /usr/local/bin/docker-compose" "Making Docker Compose executable"

# Verify Docker Compose installation
compose_version=$(docker-compose --version)
if [ $? -eq 0 ]; then
    print_success "Docker Compose installed successfully: $compose_version"
else
    print_error "Docker Compose installation verification failed"
fi

# Configure SSH for GitHub
print_step "6. CONFIGURING SSH FOR GITHUB"
run_command "runuser -l $USERNAME -c 'mkdir -p /home/$USERNAME/.ssh'" "Creating SSH directory"

# Let user choose what type of SSH key to create
print_message "What type of SSH key would you like to generate?"
print_message "1) RSA (Compatible with older systems)"
print_message "2) Ed25519 (More secure, recommended for newer systems)"
read -p "Choose key type (1 or 2, default: 2): " KEY_TYPE
KEY_TYPE=${KEY_TYPE:-2}

if [ "$KEY_TYPE" = "1" ]; then
    run_command "runuser -l $USERNAME -c 'ssh-keygen -t rsa -b 4096 -f /home/$USERNAME/.ssh/github_key -C \"$USERNAME-$(hostname)-$(date +%Y%m%d)\" -N \"\"'" "Generating GitHub RSA SSH key"
else
    run_command "runuser -l $USERNAME -c 'ssh-keygen -t ed25519 -f /home/$USERNAME/.ssh/github_key -C \"$USERNAME-$(hostname)-$(date +%Y%m%d)\" -N \"\"'" "Generating GitHub Ed25519 SSH key"
fi

# Create more extensive SSH config
cat > /home/$USERNAME/.ssh/config << EOL
# GitHub Configuration
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/github_key
    IdentitiesOnly yes
    AddKeysToAgent yes

# GitLab Configuration
Host gitlab.com
    HostName gitlab.com
    User git
    IdentityFile ~/.ssh/github_key
    IdentitiesOnly yes
    AddKeysToAgent yes

# Bitbucket Configuration
Host bitbucket.org
    HostName bitbucket.org
    User git
    IdentityFile ~/.ssh/github_key
    IdentitiesOnly yes
    AddKeysToAgent yes

# Global SSH Options
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 30
    TCPKeepAlive yes
    ControlMaster auto
    ControlPath ~/.ssh/control/%r@%h:%p
    ControlPersist 10m
    StrictHostKeyChecking accept-new
EOL

# Create SSH control directory
run_command "runuser -l $USERNAME -c 'mkdir -p /home/$USERNAME/.ssh/control'" "Creating SSH control directory"

# Set up Git configuration
print_message "Setting up Git configuration..."
print_message "Enter your Git user name (e.g., John Doe):"
read -p "Git user name: " GIT_NAME
print_message "Enter your Git email:"
read -p "Git email: " GIT_EMAIL

if [ -n "$GIT_NAME" ] && [ -n "$GIT_EMAIL" ]; then
    run_command "runuser -l $USERNAME -c 'git config --global user.name \"$GIT_NAME\"'" "Setting Git user name"
    run_command "runuser -l $USERNAME -c 'git config --global user.email \"$GIT_EMAIL\"'" "Setting Git email"
    run_command "runuser -l $USERNAME -c 'git config --global init.defaultBranch main'" "Setting default branch to main"
    run_command "runuser -l $USERNAME -c 'git config --global pull.rebase false'" "Setting pull strategy"
    run_command "runuser -l $USERNAME -c 'git config --global core.editor \"nano\"'" "Setting default editor"
    run_command "runuser -l $USERNAME -c 'git config --global alias.st status'" "Setting Git aliases"
    run_command "runuser -l $USERNAME -c 'git config --global alias.co checkout'" "Setting Git aliases"
    run_command "runuser -l $USERNAME -c 'git config --global alias.br branch'" "Setting Git aliases"
    run_command "runuser -l $USERNAME -c 'git config --global alias.l \"log --oneline --graph --decorate\"'" "Setting Git aliases"
fi

chmod 600 /home/$USERNAME/.ssh/config
chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
print_success "SSH configured for Git repositories"

# Display the public key
print_message "GitHub Deploy Key (add this to your GitHub repository deploy keys):"
echo -e "${YELLOW}---------------------------- BEGIN KEY ----------------------------${NC}"
cat /home/$USERNAME/.ssh/github_key.pub
echo -e "${YELLOW}---------------------------- END KEY ----------------------------${NC}"

# Set up Git globally with the deploy key
cat > /home/$USERNAME/.gitconfig_deploy << 'EOL'
# Include this in your git config when you want to use the deploy key
# Use: git config --local include.path "/home/username/.gitconfig_deploy"
[core]
    sshCommand = "ssh -i ~/.ssh/github_key -F /dev/null"
EOL
chown $USERNAME:$USERNAME /home/$USERNAME/.gitconfig_deploy

# Create git_sudo alias globally
print_message "Creating git_sudo alias globally..."
cat > /etc/profile.d/git_sudo.sh << 'EOL'
alias git_sudo='sudo -E GIT_SSH_COMMAND="ssh -i ~/.ssh/github_key" git'
EOL
chmod +x /etc/profile.d/git_sudo.sh

# Set up application directory structure
print_step "7. SETTING UP APPLICATION DIRECTORIES"
print_message "Do you want to set up a custom application directory? (y/n)"
read -p "Custom directory? (default: /var/www/app): " CUSTOM_APP_DIR

if [[ "${CUSTOM_APP_DIR,,}" == "y" ]]; then
    print_message "Enter your application directory path:"
    read -p "App directory path: " APP_DIR
    
    if [ -z "$APP_DIR" ]; then
        APP_DIR="/var/www/app"
    fi
else
    APP_DIR="/var/www/app"
fi

run_command "mkdir -p $APP_DIR" "Creating application directory at $APP_DIR"
run_command "mkdir -p $APP_DIR/data" "Creating data directory"
run_command "mkdir -p $APP_DIR/logs" "Creating logs directory"
run_command "mkdir -p $APP_DIR/config" "Creating config directory"
run_command "mkdir -p $APP_DIR/backups" "Creating backups directory"
run_command "chown -R $USERNAME:$USERNAME $APP_DIR" "Setting permissions for application directory"

# Configure basic firewall
print_step "8. CONFIGURING FIREWALL"
run_command "apt install -y ufw" "Installing UFW firewall"
run_command "ufw allow 22/tcp" "Allowing SSH connections"
run_command "ufw allow 80/tcp" "Allowing HTTP connections"
run_command "ufw allow 443/tcp" "Allowing HTTPS connections"

# Ask for additional ports
print_message "Do you want to open additional ports? (y/n)"
read -p "Open additional ports? " OPEN_PORTS

if [[ "${OPEN_PORTS,,}" == "y" ]]; then
    while true; do
        read -p "Enter port number or range (e.g., 8080 or 8000:8999) or press Enter to finish: " PORT
        
        if [ -z "$PORT" ]; then
            break
        fi
        
        read -p "Protocol (tcp/udp/both) [tcp]: " PROTOCOL
        PROTOCOL=${PROTOCOL:-tcp}
        
        if [[ "$PROTOCOL" == "both" ]]; then
            run_command "ufw allow $PORT/tcp" "Allowing TCP traffic on port $PORT"
            run_command "ufw allow $PORT/udp" "Allowing UDP traffic on port $PORT"
        else
            run_command "ufw allow $PORT/$PROTOCOL" "Allowing $PROTOCOL traffic on port $PORT"
        fi
    done
fi

# Ask before enabling firewall
print_message "Do you want to enable the firewall now? This might disconnect your SSH session if not configured properly. (y/n)"
read -p "Enable firewall now? " ENABLE_FIREWALL

if [[ "${ENABLE_FIREWALL,,}" == "y" ]]; then
    run_command "ufw --force enable" "Enabling firewall"
    print_success "Firewall enabled and configured"
else
    print_warning "Firewall not enabled. Enable it manually using 'sudo ufw enable' when ready."
fi

# Set up SWAP if needed
print_step "9. CONFIGURING SWAP SPACE"
total_memory=$(free -m | awk '/^Mem:/{print $2}')
print_message "System has $total_memory MB of RAM"

print_message "Do you want to set up swap space? (y/n)"
read -p "Set up swap? " SETUP_SWAP

if [[ "${SETUP_SWAP,,}" == "y" ]]; then
    # Check if swap already exists
    if free | grep -q "Swap:" && [ "$(free | grep 'Swap:' | awk '{print $2}')" != "0" ]; then
        print_warning "Swap already exists. Current swap size: $(free -h | grep 'Swap:' | awk '{print $2}')"
        read -p "Do you want to modify the existing swap? (y/n) " MODIFY_SWAP
        
        if [[ "${MODIFY_SWAP,,}" == "y" ]]; then
            # Turn off existing swap
            run_command "swapoff -a" "Turning off existing swap"
            
            # Find and remove existing swap entries in fstab
            awk '!/swap/' /etc/fstab > /tmp/fstab.new
            mv /tmp/fstab.new /etc/fstab
        else
            print_message "Keeping existing swap configuration"
        fi
    fi
    
    if [[ "${MODIFY_SWAP,,}" == "y" ]] || ! free | grep -q "Swap:" || [ "$(free | grep 'Swap:' | awk '{print $2}')" == "0" ]; then
        read -p "Enter swap size in GB (default: 2): " SWAP_SIZE
        SWAP_SIZE=${SWAP_SIZE:-2}
        
        run_command "fallocate -l ${SWAP_SIZE}G /swapfile" "Creating ${SWAP_SIZE}GB swap file"
        run_command "chmod 600 /swapfile" "Setting secure permissions on swap file"
        run_command "mkswap /swapfile" "Setting up swap area"
        run_command "swapon /swapfile" "Enabling swap file"
        
        # Make swap permanent
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
        print_success "Swap file created and enabled (${SWAP_SIZE}GB)"
        
        # Optimize swap settings
        print_message "Optimizing swap settings..."
        cat > /etc/sysctl.d/99-swappiness.conf << EOL
# Decrease swappiness value (default is 60)
vm.swappiness = 10

# Increase cache pressure, less inode/dentry cache
vm.vfs_cache_pressure = 50
EOL
        run_command "sysctl -p /etc/sysctl.d/99-swappiness.conf" "Applying swap optimizations"
    fi
fi

# Set up automatic security updates
print_step "10. CONFIGURING AUTOMATIC UPDATES"
run_command "apt install -y unattended-upgrades apt-listchanges" "Installing unattended-upgrades"

# Configure unattended-upgrades with custom settings
cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOL
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}";
    "\${distro_id}:\${distro_codename}-security";
    "\${distro_id}ESMApps:\${distro_codename}-apps-security";
    "\${distro_id}ESM:\${distro_codename}-infra-security";
    "\${distro_id}:\${distro_codename}-updates";
};

Unattended-Upgrade::Package-Blacklist {
};

Unattended-Upgrade::DevRelease "false";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
EOL

cat > /etc/apt/apt.conf.d/20auto-upgrades << EOL
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOL

print_success "Automatic security updates configured"

# Set up logrotate for application logs
print_message "Setting up logrotate for application logs..."
cat > /etc/logrotate.d/application << EOL
$APP_DIR/logs/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 $USERNAME $USERNAME
    sharedscripts
    postrotate
        find $APP_DIR/logs -name "*.gz" -mtime +14 -delete
    endscript
}
EOL

print_success "Log rotation configured for application logs"

# Add system monitoring tools (optional)
print_step "11. INSTALLING MONITORING TOOLS"
print_message "Do you want to install system monitoring tools? (y/n)"
read -p "Install monitoring tools? " INSTALL_MONITORING

if [[ "${INSTALL_MONITORING,,}" == "y" ]]; then
    print_message "Which monitoring tools would you like to install?"
    print_message "1) htop, iotop, nmon (Basic tools)"
    print_message "2) Glances (Advanced monitoring in one tool)"
    print_message "3) Both options"
    read -p "Choose option (1/2/3): " MONITORING_OPTION
    
    case $MONITORING_OPTION in
        1|3)
            run_command "apt install -y htop iotop nmon" "Installing basic monitoring tools"
            ;;
        2|3)
            run_command "apt install -y python3-pip" "Installing pip3"
            run_command "pip3 install glances" "Installing Glances"
            ;;
        *)
            print_warning "Invalid option, skipping monitoring tools installation"
            ;;
    esac
fi

# Create useful scripts directory
print_step "12. CREATING UTILITY SCRIPTS"
run_command "mkdir -p /usr/local/bin/scripts" "Creating utility scripts directory"

# Create backup script
cat > /usr/local/bin/scripts/backup-app.sh << EOL
#!/bin/bash
# Application backup script

TIMESTAMP=\$(date +"%Y%m%d-%H%M%S")
BACKUP_DIR="$APP_DIR/backups"
BACKUP_FILE="\$BACKUP_DIR/app-backup-\$TIMESTAMP.tar.gz"

# Create backup directory if it doesn't exist
mkdir -p \$BACKUP_DIR

# Create backup
tar -czf \$BACKUP_FILE -C $APP_DIR data config

# Output result
echo "Backup created: \$BACKUP_FILE"

# Clean up old backups (keep last 5)
ls -t \$BACKUP_DIR/app-backup-*.tar.gz | tail -n +6 | xargs rm -f

# Output cleanup result
echo "Cleaned up old backups, keeping the 5 most recent"
EOL
chmod +x /usr/local/bin/scripts/backup-app.sh

# Create Docker cleanup script
cat > /usr/local/bin/scripts/docker-cleanup.sh << EOL
#!/bin/bash
# Docker cleanup script

echo "Stopping all containers..."
docker stop \$(docker ps -a -q)

echo "Removing stopped containers..."
docker container prune -f

echo "Removing unused images..."
docker image prune -a -f

echo "Removing unused volumes..."
docker volume prune -f

echo "Removing unused networks..."
docker network prune -f

echo "Docker system status:"
docker system df
EOL
chmod +x /usr/local/bin/scripts/docker-cleanup.sh

# Create system info script
cat > /usr/local/bin/scripts/sysinfo.sh << EOL
#!/bin/bash
# System information script

echo "=== System Information ==="
echo "Hostname: \$(hostname)"
echo "Operating System: \$(lsb_release -ds)"
echo "Kernel: \$(uname -r)"
echo "CPU: \$(grep -m 1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ *//')"
echo "CPU Cores: \$(grep -c processor /proc/cpuinfo)"
echo "Memory: \$(free -h | awk '/^Mem/{print \$2}') total, \$(free -h | awk '/^Mem/{print \$3}') used"
echo "Swap: \$(free -h | awk '/^Swap/{print \$2}') total, \$(free -h | awk '/^Swap/{print \$3}') used"
echo "Disk Usage: \$(df -h / | awk '/\// {print \$5 " used, " \$4 " free"}')"
echo "IP Address: \$(hostname -I | awk '{print \$1}')"
echo "Uptime: \$(uptime -p)"
echo "Load Average: \$(uptime | awk -F'[a-z]:' '{print \$2}')"

echo -e "\n=== Docker Information ==="
if command -v docker &> /dev/null; then
    echo "Docker version: \$(docker --version)"
    echo "Number of containers: \$(docker ps -q | wc -l) running, \$(docker ps -a -q | wc -l) total"
    echo "Number of images: \$(docker images -q | wc -l)"
else
    echo "Docker not installed"
fi

echo -e "\n=== Service Status ==="
services=("nginx" "docker" "ssh")
for service in "\${services[@]}"; do
    status=\$(systemctl is-active \$service 2>/dev/null)
    if [ "\$status" == "active" ]; then
        echo "\$service: Running"
    else
        echo "\$service: Not running"
    fi
done

echo -e "\n=== Last Login Information ==="
last | head -5
EOL
chmod +x /usr/local/bin/scripts/sysinfo.sh

# Create SSL certificate renewal script
cat > /usr/local/bin/scripts/renew-certs.sh << EOL
#!/bin/bash
# SSL certificate renewal script

echo "Renewing SSL certificates..."
certbot renew --quiet

if [ \$? -eq 0 ]; then
    echo "Certificates renewed successfully!"
    echo "Reloading Nginx..."
    systemctl reload nginx
else
    echo "Certificate renewal failed. Please check certbot logs."
fi
EOL
chmod +x /usr/local/bin/scripts/renew-certs.sh

# Make scripts accessible to the user
chown -R $USERNAME:$USERNAME /usr/local/bin/scripts
ln -sf /usr/local/bin/scripts/* /usr/local/bin/

print_success "Utility scripts created and linked"

# Install Certbot for SSL certificates
print_step "13. INSTALLING CERTBOT FOR SSL CERTIFICATES"
print_message "Installing Certbot for SSL certificates..."
run_command "apt install -y certbot python3-certbot-nginx" "Installing Certbot with Nginx plugin"

# Check which web server is installed and install the appropriate plugin
if command -v apache2 &> /dev/null; then
    run_command "apt install -y python3-certbot-apache" "Installing Certbot Apache plugin"
    print_message "Apache detected: Certbot Apache plugin installed"
fi

# Set up auto-renewal for SSL certificates
print_message "Setting up automatic certificate renewal..."
cat > /etc/cron.d/certbot << EOL
0 3 * * * root certbot renew --quiet --post-hook "systemctl reload nginx" > /dev/null 2>&1
EOL
print_success "Certbot auto-renewal configured (runs daily at 3 AM)"

# Install additional useful tools
print_step "14. INSTALLING ADDITIONAL TOOLS"
print_message "Do you want to install additional useful tools? (y/n)"
read -p "Install additional tools? " INSTALL_TOOLS

if [[ "${INSTALL_TOOLS,,}" == "y" ]]; then
    print_message "Installing additional tools..."
    run_command "apt install -y fail2ban certbot python3-certbot-nginx ncdu tldr nmap speedtest-cli rsync zip unzip pv mtr traceroute whois" "Installing additional tools"
    
    # Configure fail2ban
    print_message "Configuring fail2ban for SSH protection..."
    cat > /etc/fail2ban/jail.local << EOL
[DEFAULT]
# Ban hosts for 1 hour
bantime = 3600
# Allows a host to attempt 5 times unsuccessfully before getting banned
maxretry = 5
# Look for unsuccessful login attempts for 10 minutes
findtime = 600

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
EOL
    run_command "systemctl enable fail2ban" "Enabling fail2ban service"
    run_command "systemctl restart fail2ban" "Starting fail2ban service"
    print_success "fail2ban configured for SSH protection"
    
    # Install Speedtest CLI
    print_message "Installing Speedtest CLI..."
    run_command "curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash" "Setting up Speedtest CLI repository"
    run_command "apt install -y speedtest" "Installing Speedtest CLI"
fi

# Install and configure Log monitoring tools
print_step "15. SETTING UP LOG MONITORING"
print_message "Do you want to install log monitoring tools? (y/n)"
read -p "Install log monitoring tools? " INSTALL_LOGS

if [[ "${INSTALL_LOGS,,}" == "y" ]]; then
    print_message "Installing log monitoring tools..."
    run_command "apt install -y logtail goaccess" "Installing log monitoring tools"
    
    # Create log viewer script
    cat > /usr/local/bin/scripts/viewlogs.sh << EOL
#!/bin/bash
# Log viewer script

# Define log files
declare -A logs=(
    ["nginx-access"]="/var/log/nginx/access.log"
    ["nginx-error"]="/var/log/nginx/error.log"
    ["system"]="/var/log/syslog"
    ["auth"]="/var/log/auth.log"
    ["docker"]="/var/log/docker.log"
    ["app"]="$APP_DIR/logs/app.log"
)

# Function to display menu
show_menu() {
    echo "=== Log Viewer ==="
    echo "Select a log to view:"
    count=1
    for key in "\${!logs[@]}"; do
        echo "\$count) \$key (\${logs[\$key]})"
        count=\$((count+1))
    done
    echo "q) Quit"
}

# Main loop
while true; do
    show_menu
    
    read -p "Enter your choice: " choice
    
    if [[ "\$choice" == "q" ]]; then
        exit 0
    fi
    
    # Convert choice to array index
    count=1
    for key in "\${!logs[@]}"; do
        if [[ "\$count" == "\$choice" ]]; then
            selected_key=\$key
            break
        fi
        count=\$((count+1))
    done
    
    if [[ -z "\$selected_key" ]]; then
        echo "Invalid choice!"
        continue
    fi
    
    log_file=\${logs[\$selected_key]}
    
    if [[ ! -f "\$log_file" ]]; then
        echo "Log file '\$log_file' does not exist!"
        continue
    fi
    
    echo "Press CTRL+C to return to menu"
    sleep 1
    tail -f "\$log_file"
done
EOL
    chmod +x /usr/local/bin/scripts/viewlogs.sh
    
    print_success "Log monitoring tools installed"
fi

# Setup backup cron job
print_step "16. SETTING UP AUTOMATED BACKUPS"
print_message "Do you want to set up automated backups? (y/n)"
read -p "Set up automated backups? " SETUP_BACKUPS

if [[ "${SETUP_BACKUPS,,}" == "y" ]]; then
    print_message "Setting up daily application backups..."
    cat > /etc/cron.d/app-backup << EOL
0 2 * * * $USERNAME /usr/local/bin/scripts/backup-app.sh > /dev/null 2>&1
EOL
    print_success "Automated backups configured (runs daily at 2 AM)"
fi

# Add custom bashrc/zshrc additions
print_step "17. CONFIGURING WELCOME SCREEN"
print_message "Setting up custom welcome screen..."

cat > /etc/update-motd.d/99-custom-welcome << 'EOL'
#!/bin/bash
# Custom welcome message

# Colors
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
NC="\033[0m"  # No Color

# System information
HOSTNAME=$(hostname)
OS=$(lsb_release -ds)
KERNEL=$(uname -r)
UPTIME=$(uptime -p)
MEMORY=$(free -h | awk '/^Mem:/ {print $3 "/" $2}')
LOAD=$(uptime | awk -F'[a-z]:' '{print $2}')
DISK=$(df -h / | awk 'NR==2 {print $5 " used (" $3 "/" $2 ")"}')
IP=$(hostname -I | awk '{print $1}')

# Display welcome message
echo -e "${GREEN}"
echo -e "   ██╗    ██╗███████╗██╗      ██████╗ ██████╗ ███╗   ███╗███████╗"
echo -e "   ██║    ██║██╔════╝██║     ██╔════╝██╔═══██╗████╗ ████║██╔════╝"
echo -e "   ██║ █╗ ██║█████╗  ██║     ██║     ██║   ██║██╔████╔██║█████╗  "
echo -e "   ██║███╗██║██╔══╝  ██║     ██║     ██║   ██║██║╚██╔╝██║██╔══╝  "
echo -e "   ╚███╔███╔╝███████╗███████╗╚██████╗╚██████╔╝██║ ╚═╝ ██║███████╗"
echo -e "    ╚══╝╚══╝ ╚══════╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝"
echo -e "${NC}"

echo -e "${BLUE}SYSTEM INFORMATION${NC}"
echo -e "  ${YELLOW}Hostname${NC}......: $HOSTNAME"
echo -e "  ${YELLOW}OS${NC}............: $OS"
echo -e "  ${YELLOW}Kernel${NC}........: $KERNEL"
echo -e "  ${YELLOW}Uptime${NC}........: $UPTIME"
echo -e "  ${YELLOW}Memory${NC}........: $MEMORY"
echo -e "  ${YELLOW}Load${NC}..........: $LOAD"
echo -e "  ${YELLOW}Disk Usage${NC}....: $DISK"
echo -e "  ${YELLOW}IP Address${NC}....: $IP"

echo -e "\n${BLUE}AVAILABLE COMMANDS${NC}"
echo -e "  ${YELLOW}sysinfo${NC}.......: Show detailed system information"
echo -e "  ${YELLOW}viewlogs${NC}......: Interactive log viewer"
echo -e "  ${YELLOW}backup-app${NC}....: Create application backup"
echo -e "  ${YELLOW}docker-cleanup${NC}: Clean up Docker resources"

echo
EOL
chmod +x /etc/update-motd.d/99-custom-welcome
print_success "Custom welcome screen configured"

# Final setup and permissions
print_step "18. APPLYING FINAL CONFIGURATIONS"

# Set permissions for scripts
run_command "chmod +x /usr/local/bin/scripts/*" "Setting permissions for utility scripts"

# Create setup completion marker
touch /etc/server-setup-complete
echo "Setup completed on $(date)" > /etc/server-setup-complete

# Add alias for sudo user
if [ "$USERNAME" != "root" ]; then
    print_message "Do you want to add $USERNAME to sudoers? (y/n)"
    read -p "Add to sudoers? " ADD_SUDO
    
    if [[ "${ADD_SUDO,,}" == "y" ]]; then
        run_command "usermod -aG sudo $USERNAME" "Adding $USERNAME to sudo group"
        
        # Allow sudo without password for specific commands
        cat > /etc/sudoers.d/$USERNAME << EOL
# Allow $USERNAME to run specific commands without password
$USERNAME ALL=(ALL) NOPASSWD: /usr/bin/docker, /usr/bin/docker-compose, /bin/systemctl reload nginx, /bin/systemctl restart nginx, /usr/local/bin/scripts/*, /usr/sbin/ufw
EOL
        chmod 0440 /etc/sudoers.d/$USERNAME
        print_success "$USERNAME added to sudoers with limited passwordless sudo"
    fi
fi

# End timing the script execution
end_time=$(date +%s)
runtime=$((end_time - start_time))
hours=$((runtime / 3600))
minutes=$(( (runtime % 3600) / 60 ))
seconds=$((runtime % 60))

print_step "SETUP COMPLETE"
echo -e "${GREEN}Server setup completed successfully in ${hours}h ${minutes}m ${seconds}s!${NC}"
echo

print_message "GitHub Deploy Key (add this to your GitHub repository deploy keys):"
echo -e "${YELLOW}---------------------------- BEGIN KEY ----------------------------${NC}"
cat /home/$USERNAME/.ssh/github_key.pub
echo -e "${YELLOW}---------------------------- END KEY ----------------------------${NC}"

print_message "To use this key with Git repositories, run:"
echo "  git config --local include.path \"$HOME/.gitconfig_deploy\""

print_message "For git operations requiring sudo, use the git_sudo alias:"
echo "  git_sudo clone git@github.com:username/repository.git"

print_message "Remember to enable the firewall if you didn't do it during setup:"
echo "  sudo ufw enable"

print_message "Use the following utility scripts:"
echo "  sysinfo       - Show detailed system information"
echo "  backup-app    - Create application backup"
echo "  docker-cleanup - Clean up Docker resources"
echo "  viewlogs      - Interactive log viewer (if installed)"
echo "  renew-certs   - Manually renew SSL certificates"

echo -e "\nServer will now restart in 10 seconds to apply all changes. Press Ctrl+C to cancel."
sleep 10
reboot

exit 0
