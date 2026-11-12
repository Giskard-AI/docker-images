#!/bin/bash
# Check that the generated Dockerfiles use the base images pinned in base-images.json.
set -euo pipefail

FOLDER=$(readlink -f "${BASH_SOURCE[0]}" | xargs dirname)
BASE_IMAGES_FILE="${FOLDER}/base-images.json"

jq -e '.default == "24.04"' "${BASE_IMAGES_FILE}"
jq -e '.images["24.04"].image | test("^ubuntu:24\\.04@sha256:[0-9a-f]{64}$")' "${BASE_IMAGES_FILE}"
jq -e '.images["26.04"].image | test("^ubuntu:26\\.04@sha256:[0-9a-f]{64}$")' "${BASE_IMAGES_FILE}"
jq -e '.images["24.04"].debian_version == "bookworm"' "${BASE_IMAGES_FILE}"
jq -e '.images["26.04"].debian_version == "trixie"' "${BASE_IMAGES_FILE}"

for version in 24.04 26.04; do
    image="$(jq -r --arg version "${version}" '.images[$version].image' "${BASE_IMAGES_FILE}")"
    debian_variant="$(jq -r --arg version "${version}" '.images[$version].debian_variant' "${BASE_IMAGES_FILE}")"
    debian_version="$(jq -r --arg version "${version}" '.images[$version].debian_version' "${BASE_IMAGES_FILE}")"
    for f in "${FOLDER}/ubuntu${version}"/Dockerfile_*; do
        echo "Checking ${f#"${FOLDER}/"}"
        grep -Fxq "ARG UBUNTU_BASE_IMAGE=${image}" "${f}"
        grep -Fq "/${debian_variant}-${debian_version}/Dockerfile" "${f}"
        grep -q '^FROM ${UBUNTU_BASE_IMAGE} AS dev$' "${f}"
    done
done
