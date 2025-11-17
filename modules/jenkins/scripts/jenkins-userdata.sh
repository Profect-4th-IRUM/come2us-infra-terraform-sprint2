#!/bin/bash
set -euxo pipefail

# 0) 네트워크가 완전히 준비될 때까지 대기
apt-get update -y || true  # NAT/라우팅 워밍업 겸 가벼운 트래픽
systemctl enable docker
systemctl start docker
# network-online.target 확실히 대기 (cloud-init보다 늦게 준비되는 경우 대비)
timeout 120s bash -c 'until systemctl is-active --quiet network-online.target; do sleep 2; done' || true
# Docker 데몬 준비 대기
timeout 120s bash -c 'until docker info >/dev/null 2>&1; do sleep 2; done'

MNT="/mnt/jenkins_data"

# 1) 데이터 디스크 탐색(루트 제외) + 준비
DEVICE=""
for _ in $(seq 1 120); do
  CANDIDATE=$(lsblk -ndo NAME,TYPE | awk '$2=="disk"{print $1}' | grep -E '^(nvme|xvd)' | grep -vE 'nvme0n1|xvda' | head -n1 || true)
  [ -n "$CANDIDATE" ] && DEVICE="/dev/$CANDIDATE"
  [ -b "$DEVICE" ] && break
  sleep 2
done

if [ -z "${DEVICE:-}" ] || [ ! -b "$DEVICE" ]; then
  echo "EBS device not found; skipping mount to let instance come up"; exit 0
fi

if ! blkid "$DEVICE" >/dev/null 2>&1; then
  mkfs -t ext4 "$DEVICE"
fi

mkdir -p "$MNT"
if ! mount | grep -q "$MNT"; then
  mount "$DEVICE" "$MNT"
  echo "$DEVICE $MNT ext4 defaults,nofail 0 2" >> /etc/fstab
fi
chown -R ubuntu:ubuntu "$MNT"

# 2) docker pull 재시도 (exponential backoff, 최대 ~2분)
IMG="jenkins/jenkins:lts-jdk21"
for i in 1 2 3 4 5 6; do
  if docker pull "$IMG"; then break; fi
  sleep $((i * 5))
done

HOST_DOCKER_GID=$(getent group docker | cut -d: -f3)
echo "Host Docker GID = $HOST_DOCKER_GID"

# 3) 컨테이너 기동 (존재하면 재사용)
if ! docker ps -a --format '{{.Names}}' | grep -q '^jenkins$'; then
  docker run -d --name jenkins \
    --user root \
    -e "HOST_DOCKER_GID=$HOST_DOCKER_GID" \
    -p 8080:8080 -p 50000:50000 \
    -v "$MNT":/var/jenkins_home \
    -v /var/run/docker.sock:/var/run/docker.sock \
    "$IMG" \
    bash -c "
      groupadd -g $HOST_DOCKER_GID docker || true;
      usermod -aG docker jenkins || true;
      exec /usr/bin/tini -- /usr/local/bin/jenkins.sh
    "
fi

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

ExecStartPre=/usr/bin/bash -c '
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
