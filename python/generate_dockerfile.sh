#!/bin/bash
set -euo pipefail

FOLDER=$(readlink -f "${BASH_SOURCE[0]}" | xargs dirname)
. "${FOLDER}/../utils/utils.sh"

DEBIAN_VERSION="bookworm"
DEBIAN_VARIANT="slim"

POETRY_VERSION="1.1.5"

function install_python() {
    output_file=$1
    python_version=$2

    # Creating temp folder and entering it
    temp_folder

    source_url="https://raw.githubusercontent.com/docker-library/python/master/${python_version}/${DEBIAN_VARIANT}-${DEBIAN_VERSION}/Dockerfile"
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

    sed -i -e 's|xargs -r apt-mark manual \\|xargs -I sh -c "apt-mark manual {} \|\| echo 'OK'" \\|' "${output_file}"

# | xargs -r apt-mark manual \
		# | xargs -I sh -c "apt-mark manual {} || echo 'OK'" \


    # && export GNUPGHOME="$(mktemp -d)" \
    # && echo "disable-ipv6" >> ${GNUPGHOME}/dirmngr.conf \

    # Exiting temp folder and removing it
    cleanup_folder
}

python_version="3.12"
output_file="${FOLDER}/Dockerfile"
echo "# DO NOT MODIFY MANUALLY" >"${output_file}"
echo "# GENERATED FROM SCRIPTS" >>"${output_file}"
echo "FROM ubuntu:24.04" >>"${output_file}"
echo '' >>"${output_file}"
# echo "ARG UNAME=poetry" >>"${output_file}"
# echo "ARG UID=15000" >>"${output_file}"
# echo "ARG GID=15000" >>"${output_file}"
# echo "ARG POETRY_VERSION=${POETRY_VERSION}" >>"${output_file}"
# echo '' >>"${output_file}"

echo '# Avoid tzdata interactive action' >>"${output_file}"
echo 'ENV DEBIAN_FRONTEND noninteractive' >>"${output_file}"
echo '' >>"${output_file}"
echo "# Adding Python to image" >>"${output_file}"
install_python "${output_file}" "${python_version}"
echo '' >>"${output_file}"
# echo "# Installing packages" >>"${output_file}"
# apt_install_packages ${output_file} "libgomp1 libopenblas-base"
# echo '' >>"${output_file}"

# echo "# Adding Poetry user" >>"${output_file}"
# echo "RUN groupadd -g \$GID -o \$UNAME" >>"${output_file}"
# echo "RUN useradd -m -d /home/\$UNAME -u \$UID -g \$GID -o -s /bin/bash \$UNAME" >>"${output_file}"
# echo '' >>"${output_file}"
# echo "# Installing poetry" >>"${output_file}"
# apt_install_temp_packages ${output_file} "curl"
# echo '&& curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py -o /home/$UNAME/get-poetry.py \' >>"${output_file}"
# apt_clean_temp_packages ${output_file}
# echo '' >>"${output_file}"
# echo "# Switching to user poetry" >>"${output_file}"
# echo 'USER $UNAME' >>"${output_file}"
# echo 'RUN python /home/$UNAME/get-poetry.py --version $POETRY_VERSION' >>"${output_file}"
# echo "# Removing file (even if it's already in layers)" >>"${output_file}"
# echo 'RUN rm /home/$UNAME/get-poetry.py' >>"${output_file}"
# echo "# Adding Poetry to path" >>"${output_file}"
# echo 'ENV PATH /home/poetry/.poetry/bin:${PATH}' >>"${output_file}"
# echo 'SHELL [ "bash", "-lc" ]' >>"${output_file}"
# echo '' >>"${output_file}"

echo "Done !"