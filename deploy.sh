#!/bin/bash

if [[ -z "$TARGET" ]]; then
	echo "TARGET environment variable must be set e.g. TARGET=stage3-amd64-openrc."
	exit 1
fi

# Split the TARGET variable into three elements separated by hyphens
IFS=- read -r NAME ARCH SUFFIX <<< "${TARGET}"

VERSION=${VERSION:-$(date -u +%Y%m%d)}

ORG=${ORG:-gentoo}

# Push built images
docker push --all-tags "${ORG}/${NAME}"

declare -A MANIFEST_TAGS=(
	[stage3:latest]="amd64-openrc;armv5tel;armv6j_hardfp;armv7a_hardfp;arm64;i686-openrc;ppc64le-openrc;rv64_lp64d-openrc;s390x"
	[stage3:hardened]="amd64-hardened-openrc;i686-hardened-openrc"
	[stage3:hardened-nomultilib]="amd64-hardened-nomultilib-openrc"
	[stage3:musl]="amd64-musl;i686-musl"
	[stage3:musl-hardened]="amd64-musl-hardened;ppc64le-musl-hardened-openrc"
	[stage3:nomultilib]="amd64-nomultilib-openrc"
	[stage3:nomultilib-systemd]="amd64-nomultilib-systemd"
	[stage3:systemd]="amd64-systemd;armv5tel-systemd;armv6j_hardfp-systemd;armv7a_hardfp-systemd;arm64-systemd;i686-systemd;ppc64le-systemd;rv64_lp64d-systemd"
)

# Find latest manifest
TAG="${ARCH}${SUFFIX:+-${SUFFIX}}"
for MANIFEST in "${!MANIFEST_TAGS[@]}"; do
	if [[ "${MANIFEST_TAGS[${MANIFEST}]}" =~ (^|;)"${TAG}"(;|$) ]]; then
		IFS=';' read -ra TAGS <<< "${MANIFEST_TAGS[${MANIFEST}]}"
		break
	fi
done
if [[ -z "${TAGS+x}" ]]; then
	echo "Done! No manifests to push for TARGET=${TARGET}."
	exit 0
fi

# Latest manifests
IMAGES=()
for TAG in "${TAGS[@]}"; do
	IMAGE="${ORG}/${NAME}:${TAG}"
	if docker manifest inspect "${IMAGE}" &>/dev/null; then
		IMAGES+=("${IMAGE}")
	fi
done

docker manifest create "${ORG}/${MANIFEST}" "${IMAGES[@]}"
docker manifest push "${ORG}/${MANIFEST}"

# Dated manifests
MANIFEST="${MANIFEST}-${VERSION}"
MANIFEST="${MANIFEST/:latest-/:}"  # Remove "latest" tag prefix

IMAGES=()
for TAG in "${TAGS[@]}"; do
	IMAGE="${ORG}/${NAME}:${TAG}-${VERSION}"
	if docker manifest inspect "${IMAGE}" &>/dev/null; then
		IMAGES+=("${IMAGE}")
	fi
done

docker manifest create "${ORG}/${MANIFEST}" "${IMAGES[@]}"
docker manifest push "${ORG}/${MANIFEST}"
