#!/bin/bash
set -e

# Update and install Node.js
curl -fsSL https://rpm.nodesource.com/setup_24.x | bash -
yum update -y
yum install -y nodejs

# Create app directory
mkdir -p /opt/app
cd /opt/app

# Write package.json
cat << 'EOF' > package.json
${package_json_content}
EOF

# Write server.js
cat << 'EOF' > server.js
${app_js_content}
EOF

# Install dependencies
npm install

# Create environment file
cat << EOF > .env
REGION_NAME="${region_name}"
DB_HOST="${db_host}"
DB_USER="${db_user}"
DB_PASS="${db_pass}"
DB_NAME="${db_name}"
EOF

# Setup Systemd service to run the Node.js app
cat << 'EOF' > /etc/systemd/system/webapp.service
[Unit]
Description=Warm Standby Node.js App
After=network.target

[Service]
EnvironmentFile=/opt/app/.env
ExecStart=/usr/bin/node /opt/app/server.js
WorkingDirectory=/opt/app
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# Start the application
systemctl daemon-reload
systemctl enable webapp
systemctl start webapp
