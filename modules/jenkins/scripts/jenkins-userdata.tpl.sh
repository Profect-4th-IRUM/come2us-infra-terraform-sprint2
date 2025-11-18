#!/bin/bash
set -euxo pipefail

JENKINS_VOL_ID="${jenkins_volume_id}"
DOCKER_VOL_ID="${docker_volume_id}"

########################################
# Function: NVMe 디바이스 찾기
########################################
find_nvme_device() {
  VOL_ID="$1"
  VOL_ID_CLEAN=$(echo "$VOL_ID" | tr -d '-')  # 하이픈 제거 버전

  # 1) by-id 검색
  for path in \
    "/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_$VOL_ID" \
    "/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_$VOL_ID_CLEAN"
  do
    if [ -e "$path" ]; then
      readlink -f "$path"
      return 0
    fi
  done

  # 2) SERIAL 검색
  for DEV in /dev/nvme*n1; do
    if [ -b "$DEV" ]; then
      SERIAL=$(lsblk -no SERIAL "$DEV" 2>/dev/null || true)
      case "$SERIAL" in
        *"$VOL_ID"*|*"$VOL_ID_CLEAN"*)
          echo "$DEV"
          return 0
          ;;
      esac
    fi
  done

  return 1
}

########################################
# Docker / Network Ready
########################################
apt-get update -y || true
systemctl enable docker
systemctl start docker

timeout 120 bash -c '
  until systemctl is-active --quiet network-online.target; do sleep 2; done
'

timeout 120 bash -c '
  until docker info >/dev/null 2>&1; do sleep 2; done
'

########################################
# 1. Jenkins Volume
########################################
JENKINS_MNT="/mnt/jenkins_data"
JENKINS_DEVICE=""

echo "Searching for Jenkins volume: $JENKINS_VOL_ID"

for i in $(seq 1 120); do
  if JENKINS_DEVICE=$(find_nvme_device "$JENKINS_VOL_ID"); then
    break
  fi
  echo "Retry $i/120: Jenkins volume not found..."
  sleep 2
done

if [ -z "$JENKINS_DEVICE" ]; then
  echo "ERROR: Jenkins EBS not found ($JENKINS_VOL_ID)" >&2
  exit 1
fi

echo "Found Jenkins device: $JENKINS_DEVICE"

if ! blkid "$JENKINS_DEVICE" >/dev/null 2>&1; then
  mkfs.ext4 -F "$JENKINS_DEVICE"
fi

mkdir -p "$JENKINS_MNT"
if ! mount | grep -q "$JENKINS_MNT"; then
  mount "$JENKINS_DEVICE" "$JENKINS_MNT"
  echo "$JENKINS_DEVICE $JENKINS_MNT ext4 defaults,nofail 0 2" >> /etc/fstab
fi
chown -R ubuntu:ubuntu "$JENKINS_MNT"

########################################
# 2. Docker Volume
########################################
DOCKER_MNT="/var/lib/docker"
DOCKER_DEVICE=""

echo "Searching for Docker volume: $DOCKER_VOL_ID"

for i in $(seq 1 120); do
  if DOCKER_DEVICE=$(find_nvme_device "$DOCKER_VOL_ID"); then
    break
  fi
  echo "Retry $i/120: Docker volume not found..."
  sleep 2
done

if [ -z "$DOCKER_DEVICE" ]; then
  echo "ERROR: Docker EBS not found ($DOCKER_VOL_ID)" >&2
  exit 1
fi

echo "Found Docker device: $DOCKER_DEVICE"

if ! blkid "$DOCKER_DEVICE" >/dev/null 2>&1; then
  mkfs.ext4 -F "$DOCKER_DEVICE"
fi

systemctl stop docker || true
mkdir -p "$DOCKER_MNT"
if ! mount | grep -q "$DOCKER_MNT"; then
  mount "$DOCKER_DEVICE" "$DOCKER_MNT"
  echo "$DOCKER_DEVICE $DOCKER_MNT ext4 defaults,nofail 0 2" >> /etc/fstab
fi
systemctl start docker

timeout 60 bash -c '
  until docker info >/dev/null 2>&1; do
    echo "Waiting for Docker..."
    sleep 2
  done
'

########################################
# 3. Jenkins Container
########################################
IMG="jenkins/jenkins:lts-jdk21"

echo "Pulling Jenkins image..."
for i in 1 2 3 4 5 6; do
  docker pull "$IMG" && break || sleep "$(expr $i \* 5)"
done

HOST_DOCKER_GID=$(getent group docker | cut -d: -f3)

if ! docker ps -a --format '{{.Names}}' | grep -q '^jenkins$'; then
  echo "Starting Jenkins container..."
  docker run -d --name jenkins \
    --restart unless-stopped \
    --user root \
    -e "HOST_DOCKER_GID=$HOST_DOCKER_GID" \
    -p 8080:8080 -p 50000:50000 \
    -v "$JENKINS_MNT":/var/jenkins_home \
    -v /var/run/docker.sock:/var/run/docker.sock \
    "$IMG" \
    bash -c "
      groupadd -g $HOST_DOCKER_GID docker || true;
      usermod -aG docker jenkins || true;
      exec /usr/bin/tini -- /usr/local/bin/jenkins.sh
    "
else
  docker start jenkins
fi

########################################
# 4. systemd 등록
########################################
cat >/etc/systemd/system/jenkins-container.service <<'SERVICE'
[Unit]
Description=Jenkins Docker Container
Wants=network-online.target docker.service
After=network-online.target docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
Environment="IMG=jenkins/jenkins:lts-jdk21"

ExecStartPre=/bin/bash -c 'for i in 1 2 3 4 5 6; do docker pull $IMG && break || sleep $(expr $i \* 5); done'
ExecStart=/usr/bin/docker start jenkins
ExecStop=/usr/bin/docker stop -t 10 jenkins

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable jenkins-container.service

########################################
# 5. Jenkins 시작 대기 & 툴 설치
########################################
echo "Waiting for Jenkins to be ready..."
for i in $(seq 1 60); do
  if docker exec jenkins test -f /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null; then
    echo "Jenkins is ready!"
    break
  fi
  echo "Waiting... ($i/60)"
  sleep 5
done

docker exec -u 0 jenkins bash -c "
  apt-get update -y &&
  apt-get install -y docker.io awscli &&
  echo 'Tools installed'
" || echo "Tool installation failed (will retry on next boot)"

echo "=========================================="
echo "Jenkins setup completed!"
echo "=========================================="