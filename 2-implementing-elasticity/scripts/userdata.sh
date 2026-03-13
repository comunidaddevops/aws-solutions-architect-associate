#!/bin/bash
# Simulate a basic game server by installing Apache and a custom page
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd

# Get the instance ID and Availability Zone to display on the page
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)

cat <<HTML > /var/www/html/index.html
<!DOCTYPE html>
<html>
<head>
    <title>AWS Elasticity Lab - Game Server</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; background-color: #f4f4f9; }
        h1 { color: #333; }
        .server-info { background: #fff; border-radius: 8px; padding: 20px; display: inline-block; box-shadow: 0 4px 8px rgba(0,0,0,0.1); }
        .highlight { color: #ff9900; font-weight: bold; }
    </style>
</head>
<body>
    <h1>🎮 Simulearn Gaming Server 🎮</h1>
    <div class="server-info">
        <p>You are connected to instance: <span class="highlight">$INSTANCE_ID</span></p>
        <p>Running in Availability Zone: <span class="highlight">$AZ</span></p>
        <p>Status: <strong>READY FOR PLAYERS</strong></p>
    </div>
</body>
</html>
HTML
