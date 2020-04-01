#!/usr/bin/env bash

set -o errexit

# Create a container
container=$(buildah from java:openjdk-8-jdk-alpine)

# Labels
buildah config --label maintainer="lRamm <lukas.ramm.1998@gmail.com>" $container

#---
# Install sharry
buildah run $container apk add --no-cache --update bash curl jq wget
#buildah run $container adduser -DH -u 1000 sharry
buildah run $container mkdir -p /data
buildah commit $container

#---
# Prepare Container
echo 'curl -sL https://api.github.com/repos/eikek/sharry/releases/latest | jq -r ".assets[] | select(.name | contains(\"zip\")) | .browser_download_url" | wget -i - && unzip *.zip -d /data && rm *.zip' >&1 | buildah run $container bash
echo "cp /data/sharry-restserver*/conf/sharry.conf /data/sharry-restserver*/" >&1 | buildah run $container bash
echo "sed 's/    address = \"localhost\"/    address = \"0.0.0.0\"/' -i /data/sharry-restserver*/sharry.conf" >&1 | buildah run $container bash
buildah copy $container entrypoint.sh /
#buildah run $container chown -R sharry:sharry /data
buildah commit $container

#---
# Config Container
buildah config \
		--healthcheck-timeout 2s \
		--healthcheck-retries 3 \
		--healthcheck-interval 10s \
		--healthcheck-start-period 30s \
		--healthcheck "wget -q -t1 -o /dev/null http://localhost:9090/app || exit 1" \
		--workingdir /data \
		--env BASE_URL="http://localhost:9080" \
		--cmd /entrypoint.sh \
		--port 9090/tcp \
		$container

buildah commit --format docker $container sharry
