#!/usr/bin/env bash

set -e

if [[ -z "$GPG_KEY" ]]; then
	GPG_KEY=/secrets/key.gpg
fi

if [[ -f "${GPG_KEY}" ]]; then
	echo "importing gpg key..."
	if gpg --batch --import "${GPG_KEY}"; then
		gpg --list-secret-keys --keyid-format long
	fi
fi

if [[ -z "$DOCKER_CREDS_FILE" ]]; then
	DOCKER_CREDS_FILE=/secrets/.docker-creds
fi

if [[ -f $DOCKER_CREDS_FILE ]]; then
	if cat "$DOCKER_CREDS_FILE" | jq >/dev/null 2>&1 ; then
		while read user pass registry ; do
			echo "$pass" | docker login --username "$user" --password-stdin "$registry"
		done <<< $(cat "$DOCKER_CREDS_FILE" | jq -Mr '.registries[] | [.user, .pass, .registry] | @tsv')
	else
		IFS=':'
			while read -r user pass registry; do
				echo "$pass" | docker login -u "$user" --password-stdin "$registry"
			done <$DOCKER_CREDS_FILE
	fi
fi

if [ -n "$DOCKER_USERNAME" ] && [ -n "$DOCKER_PASSWORD" ]; then
	echo "Login to the docker..."
	echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin "$DOCKER_REGISTRY"
fi

# Workaround for github actions when access to different repositories is needed.
# Github actions provides a GITHUB_TOKEN secret that can only access the current
# repository and you cannot configure it's value.
# Access to different repositories is needed by brew for example.

if [ -n "$GORELEASER_GITHUB_TOKEN" ] ; then
	export GITHUB_TOKEN=$GORELEASER_GITHUB_TOKEN
fi

if [ -n "$GITHUB_TOKEN" ]; then
	# Log into GitHub package registry
	echo "$GITHUB_TOKEN" | docker login docker.pkg.github.com -u docker --password-stdin
	echo "$GITHUB_TOKEN" | docker login ghcr.io -u docker --password-stdin
fi

if [ -n "$CI_REGISTRY_PASSWORD" ]; then
	# Log into GitLab registry
	echo "$CI_REGISTRY_PASSWORD" | docker login "$CI_REGISTRY" -u "$CI_REGISTRY_USER" --password-stdin
fi

git config --global --add safe.directory "$(pwd)"

exec goreleaser "$@"
