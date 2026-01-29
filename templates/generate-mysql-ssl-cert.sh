#!/bin/bash

# Script to generate self-signed SSL certificates for MariaDB/MySQL
# Usage: ./generate-mysql-ssl-cert.sh [days] [output_dir]
# Example: ./generate-mysql-ssl-cert.sh 10950 /etc/mysql/ssl

set -e

# Configuration
DAYS=${1:-10950}  # Default: 30 years (30 * 365 = 10950 days)
OUTPUT_DIR=${2:-"./mysql-ssl-certs"}
COUNTRY="CA"
STATE="Quebec"
LOCALITY="Quebec"
ORGANIZATION="SFL"
ORG_UNIT="IT"
COMMON_NAME="MySQL CA"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== MySQL/MariaDB SSL Certificate Generator ===${NC}"
echo -e "${YELLOW}Certificate will be valid for: ${DAYS} days${NC}"
echo -e "${YELLOW}Output directory: ${OUTPUT_DIR}${NC}"
echo ""

# Create output directory if it doesn't exist
mkdir -p "${OUTPUT_DIR}"
cd "${OUTPUT_DIR}"

# Function to check if certificate exists and is valid
check_certificate_validity() {
    local cert_file="$1"
    
    if [ ! -f "${cert_file}" ]; then
        echo -e "${YELLOW}Certificate ${cert_file} not found.${NC}"
        return 1
    fi
    
    # Get expiration date
    local expiry_date=$(openssl x509 -in "${cert_file}" -noout -enddate | cut -d= -f2)
    local expiry_epoch=$(date -d "${expiry_date}" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "${expiry_date}" +%s 2>/dev/null)
    local current_epoch=$(date +%s)
    
    if [ ${expiry_epoch} -gt ${current_epoch} ]; then
        local days_remaining=$(( (expiry_epoch - current_epoch) / 86400 ))
        echo -e "${GREEN}Certificate is valid. Expires in ${days_remaining} days (${expiry_date})${NC}"
        return 0
    else
        echo -e "${RED}Certificate has expired on ${expiry_date}${NC}"
        return 1
    fi
}

# Check if certificates exist and are valid
if [ -f "ca-cert.pem" ] && [ -f "server-cert.pem" ] && [ -f "client-cert.pem" ]; then
    echo -e "${YELLOW}Checking existing certificates...${NC}"
    echo ""
    
    echo -e "${YELLOW}CA Certificate:${NC}"
    if check_certificate_validity "ca-cert.pem"; then
        ca_valid=true
    else
        ca_valid=false
    fi
    
    echo ""
    echo -e "${YELLOW}Server Certificate:${NC}"
    if check_certificate_validity "server-cert.pem"; then
        server_valid=true
    else
        server_valid=false
    fi
    
    echo ""
    echo -e "${YELLOW}Client Certificate:${NC}"
    if check_certificate_validity "client-cert.pem"; then
        client_valid=true
    else
        client_valid=false
    fi
    
    echo ""
    
    # If all certificates are valid, skip generation
    if [ "$ca_valid" = true ] && [ "$server_valid" = true ] && [ "$client_valid" = true ]; then
        echo -e "${GREEN}✓ All certificates are valid. Skipping generation.${NC}"
        echo -e "${YELLOW}To force regeneration, delete the existing certificates or use a different output directory.${NC}"
        echo ""
        echo -e "${GREEN}=== Certificate Details ===${NC}"
        echo -e "${YELLOW}CA Certificate:${NC}"
        openssl x509 -in ca-cert.pem -noout -subject -issuer -dates
        echo ""
        echo -e "${YELLOW}Server Certificate:${NC}"
        openssl x509 -in server-cert.pem -noout -subject -issuer -dates
        echo ""
        echo -e "${YELLOW}Client Certificate:${NC}"
        openssl x509 -in client-cert.pem -noout -subject -issuer -dates
        exit 0
    else
        echo -e "${YELLOW}One or more certificates are expired or missing. Regenerating all certificates...${NC}"
        echo ""
        # Backup old certificates
        if [ -f "ca-cert.pem" ]; then
            backup_dir="backup-$(date +%Y%m%d-%H%M%S)"
            mkdir -p "${backup_dir}"
            echo -e "${YELLOW}Backing up old certificates to ${backup_dir}/${NC}"
            mv -f *.pem "${backup_dir}/" 2>/dev/null || true
            echo ""
        fi
    fi
else
    echo -e "${YELLOW}No existing certificates found. Generating new certificates...${NC}"
    echo ""
fi

# Generate CA private key
echo -e "${GREEN}[1/5] Generating CA private key...${NC}"
openssl genrsa 2048 > ca-key.pem

# Generate CA certificate
echo -e "${GREEN}[2/5] Generating CA certificate...${NC}"
openssl req -new -x509 -nodes -days ${DAYS} -key ca-key.pem -out ca-cert.pem \
    -subj "/C=${COUNTRY}/ST=${STATE}/L=${LOCALITY}/O=${ORGANIZATION}/OU=${ORG_UNIT}/CN=${COMMON_NAME}"

# Generate server private key and certificate request
echo -e "${GREEN}[3/5] Generating server private key and certificate request...${NC}"
openssl req -newkey rsa:2048 -days ${DAYS} -nodes -keyout server-key.pem -out server-req.pem \
    -subj "/C=${COUNTRY}/ST=${STATE}/L=${LOCALITY}/O=${ORGANIZATION}/OU=${ORG_UNIT}/CN=MySQL Server"

# Process server RSA key
echo -e "${GREEN}[4/5] Processing server RSA key...${NC}"
openssl rsa -in server-key.pem -out server-key.pem

# Sign server certificate
echo -e "${GREEN}[5/5] Signing server certificate...${NC}"
openssl x509 -req -in server-req.pem -days ${DAYS} -CA ca-cert.pem -CAkey ca-key.pem \
    -set_serial 01 -out server-cert.pem

# Generate client certificates (optional but recommended)
echo -e "${GREEN}[BONUS] Generating client certificates...${NC}"
openssl req -newkey rsa:2048 -days ${DAYS} -nodes -keyout client-key.pem -out client-req.pem \
    -subj "/C=${COUNTRY}/ST=${STATE}/L=${LOCALITY}/O=${ORGANIZATION}/OU=${ORG_UNIT}/CN=MySQL Client"

openssl rsa -in client-key.pem -out client-key.pem

openssl x509 -req -in client-req.pem -days ${DAYS} -CA ca-cert.pem -CAkey ca-key.pem \
    -set_serial 01 -out client-cert.pem

# Verify certificates
echo ""
echo -e "${GREEN}=== Verifying Certificates ===${NC}"
openssl verify -CAfile ca-cert.pem server-cert.pem client-cert.pem

# Set appropriate permissions
echo ""
echo -e "${GREEN}=== Setting File Permissions ===${NC}"
chmod 644 ca-key.pem server-key.pem client-key.pem
chmod 644 ca-cert.pem server-cert.pem client-cert.pem

# Display certificate information
echo ""
echo -e "${GREEN}=== Certificate Details ===${NC}"
echo -e "${YELLOW}CA Certificate:${NC}"
openssl x509 -in ca-cert.pem -noout -subject -issuer -dates

echo ""
echo -e "${YELLOW}Server Certificate:${NC}"
openssl x509 -in server-cert.pem -noout -subject -issuer -dates

echo ""
echo -e "${GREEN}=== Generated Files ===${NC}"
ls -lh *.pem

echo ""
echo -e "${GREEN}=== Next Steps ===${NC}"
echo -e "${YELLOW}1. For MariaDB/MySQL Server Configuration:${NC}"
echo "   Add to /etc/mysql/mariadb.conf.d/50-server.cnf or /etc/mysql/my.cnf:"
echo "   [mysqld]"
echo "   ssl-ca=${OUTPUT_DIR}/ca-cert.pem"
echo "   ssl-cert=${OUTPUT_DIR}/server-cert.pem"
echo "   ssl-key=${OUTPUT_DIR}/server-key.pem"
echo ""
echo -e "${YELLOW}2. For Laravel Application (.env):${NC}"
echo "   MYSQL_ATTR_SSL_CA=${OUTPUT_DIR}/ca-cert.pem"
echo ""
echo -e "${YELLOW}3. Restart MariaDB/MySQL:${NC}"
echo "   sudo systemctl restart mariadb"
echo "   or"
echo "   sudo systemctl restart mysql"
echo ""
echo -e "${YELLOW}4. Verify SSL is enabled:${NC}"
echo "   sudo mysql -u root -p -e \"SHOW VARIABLES LIKE '%ssl%';\""
echo ""
echo -e "${YELLOW}5. Test SSL connection:${NC}"
echo "   mysql -u your_user -p --ssl-ca=${OUTPUT_DIR}/ca-cert.pem -e \"STATUS\""
echo ""
echo -e "${GREEN}=== Files Description ===${NC}"
echo "ca-cert.pem      - CA certificate (use in Laravel .env)"
echo "ca-key.pem       - CA private key (keep secure!)"
echo "server-cert.pem  - Server certificate (for MySQL server)"
echo "server-key.pem   - Server private key (for MySQL server)"
echo "client-cert.pem  - Client certificate (optional)"
echo "client-key.pem   - Client private key (optional)"
echo ""
echo -e "${GREEN}✓ SSL certificates generated successfully!${NC}"
