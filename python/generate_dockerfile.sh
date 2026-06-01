#!/bin/bash
set -euo pipefail

FOLDER=$(readlink -f "${BASH_SOURCE[0]}" | xargs dirname)
. "${FOLDER}/../utils/utils.sh"

BASE_IMAGES_FILE="${FOLDER}/base-images.json"

function install_python() {
    output_file=$1
    python_version=$2
    debian_variant=$3
    debian_version=$4

    # Creating temp folder and entering it
    temp_folder

    source_url="https://raw.githubusercontent.com/docker-library/python/master/${python_version}/${debian_variant}-${debian_version}/Dockerfile"
    wget --quiet ${source_url}
    # Skip 8 first lines (comment)
    tail -n +8 Dockerfile >Dockerfile_trunc
    # Remove CMD
    sed -i -e 's/^CMD .*$//g' Dockerfile_trunc
    # Remove FROM
    sed -i -e 's/^FROM .*$//g' Dockerfile_trunc
    # # Cd to a folder to avoid weird error in CI
    # sed -i -e 's/make install/make install \&\& cd \/usr\/local/' Dockerfile_trunc

    # Comment under are to keep this version
    PYTHON_PRECISE_VERSION=$(cat Dockerfile_trunc | grep 'ENV PYTHON_VERSION' | sed -e 's/ENV PYTHON_VERSION \(.*\)$/\1/g')
    # PIP_PRECISE_VERSION=$(cat Dockerfile_trunc | grep 'ENV PYTHON_PIP_VERSION' | sed -e 's/ENV PYTHON_PIP_VERSION \(.*\)$/\1/g')

    echo '' >>"${output_file}"
    # Create empty dir to avoid error
    # echo '# Create empty dir to avoid error' >>"${output_file}"
    # echo 'RUN mkdir -p /usr/local' >>"${output_file}"
    # echo '' >>"${output_file}"
    echo '# Dockerfile generated fragment to install Python and Pip' >>"${output_file}"
    echo "# Source: ${source_url}" >>"${output_file}"
    echo "# Python: ${PYTHON_PRECISE_VERSION}" >>"${output_file}"
    echo "" >>"${output_file}"

    cat Dockerfile_trunc >>"${output_file}"

    # Now, to avoid GPG problems
    # https://github.com/f-secure-foundry/usbarmory-debian-base_image/issues/9
    sed -i -e 's|GNUPGHOME="$(mktemp -d)"; export GNUPGHOME;|GNUPGHOME="$(mktemp -d)"; export GNUPGHOME;\\\n\t# Fix to avoid GPG server problem\\\n\techo "disable-ipv6" >> "${GNUPGHOME}\/dirmngr.conf";|'  "${output_file}"
    # sed -i 's/^\(.*&&.*export GNUPGHOME="$(mktemp -d)" \)/\1\\\n# Fix to avoid GPG server problem\\\n echo "disable-ipv6" >> ${GNUPGHOME}\/dirmngr.conf /' "${output_file}"
    # This is to not remove static lib when using CUDA
    # sed -i "s/ -o -name '\*\.a' / /" "${output_file}"

    sed -i -e 's|xargs -r apt-mark manual \\|xargs -I {} sh -c "apt-mark manual {} \|\| echo 'OK'" \\|' "${output_file}"

# | xargs -r apt-mark manual \
		# | xargs -I sh -c "apt-mark manual {} || echo 'OK'" \


    # && export GNUPGHOME="$(mktemp -d)" \
    # && echo "disable-ipv6" >> ${GNUPGHOME}/dirmngr.conf \

    # Exiting temp folder and removing it
    cleanup_folder
}

ubuntu_versions=$(jq -r '.images | keys[]' "${BASE_IMAGES_FILE}")
for ubuntu_version in ${ubuntu_versions}; do
    ubuntu_base_image=$(jq -r --arg version "${ubuntu_version}" '.images[$version].image' "${BASE_IMAGES_FILE}")
    debian_variant=$(jq -r --arg version "${ubuntu_version}" '.images[$version].debian_variant' "${BASE_IMAGES_FILE}")
    debian_version=$(jq -r --arg version "${ubuntu_version}" '.images[$version].debian_version' "${BASE_IMAGES_FILE}")

    if [[ "${ubuntu_base_image}" == "null" || -z "${ubuntu_base_image}" ]]; then
        echo "No base image configured for Ubuntu ${ubuntu_version}" >&2
        exit 1
    fi
    if [[ "${debian_variant}" == "null" || -z "${debian_variant}" || "${debian_version}" == "null" || -z "${debian_version}" ]]; then
        echo "No Debian fragment configured for Ubuntu ${ubuntu_version}" >&2
        exit 1
    fi

    output_folder="${FOLDER}/ubuntu${ubuntu_version}"
    mkdir -p "${output_folder}"

    for python_version in "3.12" "3.13" "3.14"; do
        output_file="${output_folder}/Dockerfile_${python_version}"
        echo "# DO NOT MODIFY MANUALLY" >"${output_file}"
        echo "# GENERATED FROM SCRIPTS" >>"${output_file}"
        echo "ARG UBUNTU_BASE_IMAGE=${ubuntu_base_image}" >>"${output_file}"
        echo 'FROM ${UBUNTU_BASE_IMAGE}' >>"${output_file}"
        echo '' >>"${output_file}"

        echo '# Avoid tzdata interactive action' >>"${output_file}"
        echo 'ENV DEBIAN_FRONTEND noninteractive' >>"${output_file}"
        echo '' >>"${output_file}"
        echo "# Adding Python to image" >>"${output_file}"
        install_python "${output_file}" "${python_version}" "${debian_variant}" "${debian_version}"
        echo '' >>"${output_file}"
    done
done

echo "Done !"
