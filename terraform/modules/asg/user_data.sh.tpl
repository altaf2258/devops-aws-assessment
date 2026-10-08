#!/bin/bash
set -euxo pipefail

dnf install -y docker jq mariadb105
systemctl enable --now docker

# ---- Deploy script: also re-run by CI through SSM Run Command ----
cat > /opt/deploy.sh <<'EOF'
#!/bin/bash
set -euo pipefail
REGION=${region}
PREFIX=${name_prefix}

ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
REGISTRY=$ACCOUNT.dkr.ecr.$REGION.amazonaws.com
TAG=$(aws ssm get-parameter --region $REGION --name /$PREFIX/image-tag \
  --query Parameter.Value --output text)

aws ecr get-login-password --region $REGION | \
  docker login --username AWS --password-stdin $REGISTRY

docker pull $REGISTRY/$PREFIX-backend:$TAG
docker pull $REGISTRY/$PREFIX-frontend:$TAG

SECRET=$(aws secretsmanager get-secret-value --region $REGION \
  --secret-id ${secret_name} --query SecretString --output text)
DB_HOST=$(echo "$SECRET" | jq -r .host)
DB_PORT=$(echo "$SECRET" | jq -r .port)
DB_USER=$(echo "$SECRET" | jq -r .username)
DB_PASSWORD=$(echo "$SECRET" | jq -r .password)
DB_NAME=$(echo "$SECRET" | jq -r .dbname)

# Schema init (idempotent; init.sql is uploaded to S3 by CI)
if aws s3 cp s3://${bucket}/db/init.sql /tmp/init.sql --region $REGION; then
  MYSQL_PWD="$DB_PASSWORD" mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" "$DB_NAME" \
    < /tmp/init.sql || true
fi

docker network create appnet 2>/dev/null || true
docker rm -f backend frontend 2>/dev/null || true

docker run -d --name backend --restart unless-stopped --network appnet -p 3000:3000 \
  -e PORT=3000 -e DB_HOST="$DB_HOST" -e DB_PORT="$DB_PORT" \
  -e DB_USER="$DB_USER" -e DB_PASSWORD="$DB_PASSWORD" -e DB_NAME="$DB_NAME" \
  $REGISTRY/$PREFIX-backend:$TAG

docker run -d --name frontend --restart unless-stopped --network appnet -p 80:80 \
  $REGISTRY/$PREFIX-frontend:$TAG

docker image prune -f
EOF
chmod +x /opt/deploy.sh

# ---- First boot: retry until CI has pushed the first image ----
for i in $(seq 1 30); do
  /opt/deploy.sh && break || { echo "deploy failed, retry $i"; sleep 30; }
done