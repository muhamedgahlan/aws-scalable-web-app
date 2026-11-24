#!/bin/bash
dnf install -y httpd
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
IID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)

cat > /var/www/html/index.html <<HTML
<!DOCTYPE html>
<html><head><title>Scalable Web App</title></head>
<body style="font-family:sans-serif;text-align:center;margin-top:60px">
<h1>Hello from AWS!</h1>
<p>Instance: <b>$IID</b></p>
<p>Availability Zone: <b>$AZ</b></p>
<p><img src="/static/logo.svg" width="80" alt="static asset served from S3 via CloudFront"></p>
</body></html>
HTML

echo "OK" > /var/www/html/health
systemctl enable --now httpd
