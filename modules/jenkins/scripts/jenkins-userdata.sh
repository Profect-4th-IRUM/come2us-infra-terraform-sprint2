#!/bin/bash
set -euxo pipefail

########################################
# 0. 네트워크 / Docker 대기
########################################
apt-get update -y || true
systemctl enable docker
systemctl start docker

timeout 120s bash -c 'until systemctl is-active --quiet network-online.target; do sleep 2; done' || true
timeout 120s bash -c 'until docker info >/dev/null 2>&1; do sleep 2; done'


########################################
# 1. Jenkins Data Volume Mount
########################################
JENKINS_MNT="/mnt/jenkins_data"
JENKINS_DEVICE=""

for _ in $(seq 1 120); do
  CAND=$(lsblk -ndo NAME,TYPE | awk '$2=="disk"{print $1}' \
        | grep -vE '^(nvme0n1|xvda)$' \
        | head -n1 || true)
  [ -n "$CAND" ] && JENKINS_DEVICE="/dev/$CAND"
  [ -b "$JENKINS_DEVICE" ] && break
  sleep 2
done

if ! blkid "$JENKINS_DEVICE" >/dev/null 2>&1; then
  mkfs.ext4 "$JENKINS_DEVICE"
fi

mkdir -p "$JENKINS_MNT"
if ! mount | grep -q "$JENKINS_MNT"; then
  mount "$JENKINS_DEVICE" "$JENKINS_MNT"
  echo "$JENKINS_DEVICE $JENKINS_MNT ext4 defaults,nofail 0 2" >> /etc/fstab
fi
chown -R ubuntu:ubuntu "$JENKINS_MNT"


########################################
# 2. Docker Data Volume Mount
########################################
DOCKER_MNT="/var/lib/docker"
DOCKER_DEVICE=""

# 루트 디스크는 자동으로 첫 번째 디스크
ROOT_DISK=$(lsblk -ndo NAME,TYPE | awk '$2=="disk"{print $1}' | head -n1)

for _ in $(seq 1 120); do
  CAND=$(lsblk -ndo NAME,TYPE | awk '$2=="disk"{print $1}' \
        | grep -vF "$ROOT_DISK" \
        | grep -vF "$(basename $JENKINS_DEVICE)" \
        | head -n1 || true)

  [ -n "$CAND" ] && DOCKER_DEVICE="/dev/$CAND"
  [ -b "$DOCKER_DEVICE" ] && break
  sleep 2
done

if ! blkid "$DOCKER_DEVICE" >/dev/null 2>&1; then
  mkfs.ext4 "$DOCKER_DEVICE"
fi

systemctl stop docker || true

mkdir -p "$DOCKER_MNT"
mount "$DOCKER_DEVICE" "$DOCKER_MNT"
echo "$DOCKER_DEVICE $DOCKER_MNT ext4 defaults,nofail 0 2" >> /etc/fstab

systemctl start docker


########################################
# 3. Jenkins Container Run
########################################
IMG="jenkins/jenkins:lts-jdk21"

for i in 1 2 3 4 5 6; do
  docker pull "$IMG" && break || sleep $((i * 5))
done

HOST_DOCKER_GID=$(getent group docker | cut -d: -f3)

if ! docker ps -a --format '{{.Names}}' | grep -q '^jenkins$'; then
  docker run -d --name jenkins \
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
fi


########################################
# 4. systemd 관리
########################################
cat >/etc/systemd/system/jenkins-container.service <<SERVICE
[Unit]
Description=Jenkins Docker Container
Wants=network-online.target docker.service
After=network-online.target docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
Environment="IMG=$IMG"
Environment="HOST_DOCKER_GID=$HOST_DOCKER_GID"

ExecStartPre=/bin/bash -c '
  for i in 1 2 3 4 5 6; do 
    docker pull $IMG && break || sleep \$((i*5));
  done
'

ExecStart=/usr/bin/docker start jenkins || /usr/bin/docker run -d --name jenkins \
    --user root \
    -e "HOST_DOCKER_GID=\${HOST_DOCKER_GID}" \
    -p 8080:8080 -p 50000:50000 \
    -v /mnt/jenkins_data:/var/jenkins_home \
    -v /var/run/docker.sock:/var/run/docker.sock \
    \${IMG} \
    bash -c "
      groupadd -g \${HOST_DOCKER_GID} docker || true;
      usermod -aG docker jenkins || true;
      exec /usr/bin/tini -- /usr/local/bin/jenkins.sh
    "

ExecStop=/usr/bin/docker stop -t 5 jenkins

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable jenkins-container.service
systemctl start jenkins-container.service


# Wait until Jenkins starts
for i in {1..60}; do
  if docker exec jenkins test -f /var/jenkins_home/secrets/initialAdminPassword; then
    echo "Jenkins is ready!"
    break
  fi
  echo "Waiting for Jenkins to be ready..."
  sleep 5
done

# Now safe to exec inside Jenkins
docker exec -u 0 jenkins bash -c "
  apt-get update -y &&
  apt-get install -y docker.io awscli
"
