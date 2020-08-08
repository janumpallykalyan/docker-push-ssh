#!/usr/bin/env bash

set -e
set -x

echo '{"insecure-registries": ["localhost:5000"]}' | sudo tee /etc/docker/daemon.json
sudo service docker stop
sudo service docker start

docker run --name docker-dind-sshd --privileged -d brthornbury/docker-dind-sshd --storage-driver=overlay
hostIp=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' docker-dind-sshd)
echo $hostIp

python3.8 setup.py sdist
pip3.8 install dist/*.tar.gz

# Create Test Images
image1="a84b42fbe17b4a87b032c45f3c8c74e3"
mkdir /tmp/${image1}
(cd /tmp/${image1} \
    && echo "FROM alpine" >> ./Dockerfile \
    && echo "RUN touch /etc/${image1}" >> ./Dockerfile \
    && echo "CMD echo out-${image1}" >> ./Dockerfile \
    && docker build -t ${image1} .)

image2="e294fca67f674bda84013057fd48fb62"
mkdir /tmp/${image2}
(cd /tmp/${image2} \
    && echo "FROM alpine" >> ./Dockerfile \
    && echo "RUN touch /etc/${image2}" >> ./Dockerfile \
    && echo "CMD echo out-${image2}" >> ./Dockerfile \
    && docker build -t ${image2} .)

echo "" > ./emptykey

set +e
ssh  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 22 root@${hostIp} 'sh -l -c "docker run "'"${image1}"
failResult1="$?"

ssh  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 22 root@${hostIp} 'sh -l -c "docker run "'"${image2}"
failResult2="$?"
set -e

[ "$failResult1" != "0" ]
[ "$failResult2" != "0" ]

docker-push-ssh --prime-image alpine -i ./emptykey -p 22 root@${hostIp} ${image1}
docker-push-ssh --prime-image alpine -r 5002 -i ./emptykey -p 22 root@${hostIp} ${image2}

ssh  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 22 root@${hostIp} 'sh -l -c "docker run "'"${image1}"
ssh  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 22 root@${hostIp} 'sh -l -c "docker run "'"${image2}"
