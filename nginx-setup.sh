#!/bin/bash

# Colors for better readability
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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
}

# Function to get user inputs with validation
get_user_input() {
    local prompt="$1"
    local var_name="$2"
    local default="$3"
    local value=""
    
    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " value
        value=${value:-$default}
    else
        while [ -z "$value" ]; do
            read -p "$prompt: " value
            if [ -z "$value" ]; then
                print_error "This field cannot be empty. Please try again."
            fi
        done
    fi
    
    eval "$var_name=\"$value\""
}

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run this script as root or with sudo"
    exit 1
fi

print_message "Starting Nginx Docker Proxy Setup Script"
print_message "=========================================\n"

# Domain setup
print_message "DOMAIN CONFIGURATION"
print_message "--------------------"
get_user_input "Enter your domain name (e.g., example.com)" DOMAIN
get_user_input "Do you want to include www subdomain? (y/n)" INCLUDE_WWW "y"

# Generate domain list for certbot
DOMAIN_LIST="$DOMAIN"
NGINX_SERVER_NAME="$DOMAIN"

if [[ "${INCLUDE_WWW,,}" == "y" ]]; then
    DOMAIN_LIST="$DOMAIN,www.$DOMAIN"
    NGINX_SERVER_NAME="$DOMAIN www.$DOMAIN"
fi

# Docker container configuration
print_message "\nDOCKER CONTAINER CONFIGURATION"
print_message "-----------------------------"
get_user_input "Enter the Docker container port (e.g., 8080)" CONTAINER_PORT

# Create an upstream name from the domain (removing dots and special chars)
UPSTREAM_NAME=$(echo "$DOMAIN" | sed 's/[^a-zA-Z0-9]/_/g')

# Ask for additional paths to proxy
print_message "\nPATH CONFIGURATION"
print_message "-----------------"
print_message "Do you want to add specific paths to proxy? (default paths: /, /static/, /media/)"
get_user_input "Add additional paths? (y/n)" ADD_PATHS "n"

# Initialize paths array with default locations
declare -a PATHS=("/" "/static/" "/media/")
declare -a PROXY_PATHS=("" "/static/" "/media/")

if [[ "${ADD_PATHS,,}" == "y" ]]; then
    while true; do
        get_user_input "Enter path (e.g., /api/ or press enter to finish)" NEW_PATH
        if [ -z "$NEW_PATH" ]; then
            break
        fi
        
        # Ensure path starts with /
        [[ "$NEW_PATH" != /* ]] && NEW_PATH="/$NEW_PATH"
        # Ensure path ends with /
        [[ "$NEW_PATH" != */ ]] && NEW_PATH="$NEW_PATH/"
        
        get_user_input "Enter proxy destination path (default: same as path)" PROXY_PATH "$NEW_PATH"
        
        # Ensure proxy path starts with /
        [[ "$PROXY_PATH" != /* ]] && PROXY_PATH="/$PROXY_PATH"
        # Ensure proxy path ends with /
        [[ "$PROXY_PATH" != */ ]] && PROXY_PATH="$PROXY_PATH/"
        
        PATHS+=("$NEW_PATH")
        PROXY_PATHS+=("$PROXY_PATH")
        
        print_success "Path added: $NEW_PATH -> $PROXY_PATH"
    done
fi

# SSL configuration
print_message "\nSSL CONFIGURATION"
print_message "----------------"
get_user_input "Generate new SSL certificate? (y/n)" GENERATE_SSL "y"

if [[ "${GENERATE_SSL,,}" == "y" ]]; then
    # Check if certbot is installed
    if ! command -v certbot &> /dev/null; then
        print_warning "Certbot is not installed. Installing Certbot..."
        apt-get update
        apt-get install -y certbot python3-certbot-nginx
    fi
    
    print_message "Generating SSL certificate for $DOMAIN_LIST using Certbot..."
    certbot certonly --standalone -d $(echo $DOMAIN_LIST | tr ',' ' -d ') --agree-tos --non-interactive
    
    if [ $? -ne 0 ]; then
        print_error "Failed to generate SSL certificate. Please check your domain configuration."
        exit 1
    fi
    
    print_success "SSL certificate generated successfully!"
else
    print_message "Skipping SSL certificate generation. Using existing certificates."
fi

# Create Nginx configuration
print_message "\nCREATING NGINX CONFIGURATION"
print_message "---------------------------"

# Create Nginx config file
CONFIG_FILE="/etc/nginx/sites-available/$DOMAIN"

cat > "$CONFIG_FILE" << EOF
# Upstream block for the backend server
upstream ${UPSTREAM_NAME}_backend {
    server localhost:${CONTAINER_PORT};
}

# HTTP server block to redirect to HTTPS
server {
    listen 80;
    server_name ${NGINX_SERVER_NAME};
    
    # Redirect all HTTP traffic to HTTPS
    return 301 https://\$host\$request_uri;
}

# HTTPS server block
server {
    listen 443 ssl;
    server_name ${NGINX_SERVER_NAME};
    
    # SSL certificate paths from Certbot
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    
    # Improved SSL security settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Increase body size limit if needed
    client_max_body_size 50M;

EOF

# Add location blocks
for i in "${!PATHS[@]}"; do
    PATH_PATTERN="${PATHS[$i]}"
    PROXY_DESTINATION="${PROXY_PATHS[$i]}"
    
    # Special case for root location
    if [ "$PATH_PATTERN" == "/" ]; then
        cat >> "$CONFIG_FILE" << EOF
    # Default location
    location / {
        proxy_pass http://${UPSTREAM_NAME}_backend;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
EOF
    else
        cat >> "$CONFIG_FILE" << EOF
    # Proxy settings for ${PATH_PATTERN}
    location ${PATH_PATTERN} {
        proxy_pass http://${UPSTREAM_NAME}_backend${PROXY_DESTINATION};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
EOF
    fi
done

# Close the server block
cat >> "$CONFIG_FILE" << EOF
}
EOF

print_success "Nginx configuration file created at $CONFIG_FILE"

# Create symbolic link to enable the site
ln -sf "$CONFIG_FILE" /etc/nginx/sites-enabled/

# Test Nginx configuration
print_message "Testing Nginx configuration..."
nginx -t

if [ $? -ne 0 ]; then
    print_error "Nginx configuration test failed. Please check your configuration."
    exit 1
fi

# Reload Nginx
print_message "Reloading Nginx..."
systemctl reload nginx

if [ $? -ne 0 ]; then
    print_error "Failed to reload Nginx. Please check the service status."
    exit 1
fi

print_success "Nginx configuration completed and service reloaded successfully!"
print_message "Your website should now be accessible at https://$DOMAIN"

# Final instructions
print_message "\nNEXT STEPS"
print_message "----------"
print_message "1. Make sure your Docker container is running on port $CONTAINER_PORT"
print_message "2. Ensure your firewall allows incoming traffic on ports 80 and 443"
print_message "3. Set up a cron job for SSL certificate renewal:"
print_message "   0 3 * * * certbot renew --quiet && systemctl reload nginx"

exit 0
