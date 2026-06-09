#!/bin/bash
set -euo pipefail

FOLDER=$(readlink -f "${BASH_SOURCE[0]}" | xargs dirname)
. "${FOLDER}/../utils/utils.sh"

BASE_IMAGES_FILE="${FOLDER}/base-images.json"

function apply_python_cleanup() {
    output_file=$1

    sed -i -e '/^[[:space:]]*libbluetooth-dev \\$/d' "${output_file}"
    sed -i -e '/^[[:space:]]*tk-dev \\$/d' "${output_file}"
    sed -i -e '/^[[:space:]]*--enable-shared \\/a\
		--disable-test-modules \\' "${output_file}"
    sed -i -e '/^[[:space:]]*make install; \\/a\
	find /usr/local -depth \\\
		\\( \\\
			\\( -type d -a \\( -name idlelib -o -name tkinter -o -name turtledemo \\) \\) \\\
			-o \\( -type f -a \\( -name "idle3*" -o -name "_test*.so" -o -name "_ctypes_test*.so" -o -name "_xxtestfuzz*.so" -o -name "xx*.so" \\) \\) \\\
		\\) -exec rm -rf "{}" +; \\' "${output_file}"
    sed -i -e 's/for src in idle3 pip3 pydoc3 python3 python3-config; do/for src in pip3 pydoc3 python3 python3-config; do/' "${output_file}"
}

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

    apply_python_cleanup "${output_file}"

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

function write_header() {
    output_file=$1
    ubuntu_base_image=$2
    from_line=$3

    echo "# DO NOT MODIFY MANUALLY" >"${output_file}"
    echo "# GENERATED FROM SCRIPTS" >>"${output_file}"
    echo "ARG UBUNTU_BASE_IMAGE=${ubuntu_base_image}" >>"${output_file}"
    echo "${from_line}" >>"${output_file}"
    echo '' >>"${output_file}"

    echo '# Avoid tzdata interactive action' >>"${output_file}"
    echo 'ENV DEBIAN_FRONTEND noninteractive' >>"${output_file}"
    echo '' >>"${output_file}"
    echo "# Adding Python" >>"${output_file}"
}

function append_runtime_image() {
    output_file=$1

    cat >>"${output_file}" <<'EOF'

# Build a small root filesystem for the runtime image.
# The runtime keeps Python and the shared libraries it needs, but not apt/dpkg,
# shells, pip, headers, tests, or other build/debug-only files.
FROM dev AS runtime-files

RUN set -eux; \
	rm -rf \
		/usr/local/bin/2to3* \
		/usr/local/bin/idle* \
		/usr/local/bin/pip* \
		/usr/local/bin/pydoc* \
		/usr/local/bin/python*-config \
		/usr/local/include \
		/usr/local/lib/pkgconfig \
		/usr/local/lib/python*/config-* \
		/usr/local/lib/python*/ensurepip \
		/usr/local/lib/python*/idlelib \
		/usr/local/lib/python*/lib2to3 \
		/usr/local/lib/python*/site-packages/pip* \
		/usr/local/lib/python*/site-packages/setuptools* \
		/usr/local/lib/python*/site-packages/wheel* \
		/usr/local/lib/python*/tkinter \
		/usr/local/lib/python*/turtle.py \
		/usr/local/lib/python*/turtledemo \
		/usr/local/lib/python*/venv \
		/usr/local/lib/python*/__phello__ \
		/usr/local/share/man \
	; \
	find /usr/local -depth \
		\( \
			\( -type d -a \( -name __pycache__ -o -name test -o -name tests -o -name idle_test \) \) \
			-o \( -type f -a \( -name '*.pyc' -o -name '*.pyo' -o -name '_test*.so' -o -name '_ctypes_test*.so' -o -name '_xxtestfuzz*.so' -o -name 'xx*.so' \) \) \
		\) -exec rm -rf '{}' +; \
	# Keep merged-usr compatibility without copying /usr/lib twice. \
	# /usr/lib stays real so scanners can read /usr/lib/os-release. \
	mkdir -p /runtime-root/usr/lib; \
	ln -s ../lib64 /runtime-root/usr/lib64; \
	# Scratch has no default /tmp; keep it root-owned and world-writable. \
	mkdir -m 1777 /runtime-root/tmp; \
	# Copy only shared libraries required by Python and stdlib native modules. \
	find /usr/local/bin /usr/local/lib -type f \( -perm /111 -o -name '*.so*' \) -exec ldd '{}' ';' \
		| awk '/=> \// { print $(NF - 1) } $1 ~ /^\// { print $1 }' \
		| sort -u \
		| while read -r lib; do cp -L --parents "${lib}" /runtime-root; done; \
	# Keep common native-wheel and DNS/NSS runtime libraries that ldd on CPython \
	# cannot see, but downstream wheels and hostname resolution may need. \
	for lib in /lib/*/libdl.so.2 /lib/*/libgcc_s.so.1 /lib/*/libpthread.so.0 /lib/*/librt.so.1 /lib/*/libstdc++.so.6 /lib/*/libutil.so.1 /lib/*/libnss_dns.so.2 /lib/*/libnss_files.so.2 /lib/*/libresolv.so.2; do \
		if [ -e "${lib}" ]; then cp -L --parents "${lib}" /runtime-root; fi; \
	done; \
	find /runtime-root/lib -mindepth 1 -maxdepth 1 -type d \
		| while read -r lib_dir; do ln -s "../../lib/$(basename "${lib_dir}")" "/runtime-root/usr/lib/$(basename "${lib_dir}")"; done; \
	# Keep minimal Ubuntu package metadata for scanners such as Trivy. \
	# Only packages owning copied runtime files are listed, not the full dev image. \
	mkdir -p /runtime-root/etc /runtime-root/var/lib/dpkg; \
	cp /usr/lib/os-release /runtime-root/usr/lib/os-release; \
	ln -s ../usr/lib/os-release /runtime-root/etc/os-release; \
	: > /tmp/runtime-packages.list; \
	find /runtime-root -type f \
		| sed 's#^/runtime-root##' \
		| while read -r path; do \
			for query_path in "${path}" "/usr${path}"; do \
				if [ "${query_path}" != "${path}" ]; then \
					case "${path}" in /bin/*|/lib/*|/lib64/*|/sbin/*) ;; *) continue ;; esac; \
				fi; \
				if dpkg-query --search "${query_path}" > /tmp/dpkg-query.out 2>/dev/null; then \
					awk -F': ' '/^[A-Za-z0-9][A-Za-z0-9+.-]*(:[A-Za-z0-9][A-Za-z0-9+.-]*)?: / { print $1 }' /tmp/dpkg-query.out > /tmp/dpkg-query.packages; \
					if [ -s /tmp/dpkg-query.packages ]; then cat /tmp/dpkg-query.packages; break; fi; \
				fi; \
			done; \
		done \
		| sed 's/:.*//' \
		| sort -u > /tmp/runtime-packages.list; \
	awk 'BEGIN { while ((getline pkg < "/tmp/runtime-packages.list") > 0) wanted[pkg] = 1; RS = ""; ORS = "\n\n" } { package = ""; n = split($0, lines, "\n"); for (i = 1; i <= n; i++) { if (lines[i] ~ /^Package: /) { package = substr(lines[i], 10); break } } if (package in wanted) print }' /var/lib/dpkg/status > /runtime-root/var/lib/dpkg/status; \
	: > /runtime-root/var/lib/dpkg/available; \
	rm -f /tmp/runtime-packages.list /tmp/dpkg-query.out /tmp/dpkg-query.packages; \
	printf 'root:x:0:0:root:/root:/sbin/nologin\nnobody:x:65534:65534:nobody:/nonexistent:/sbin/nologin\n' > /etc/passwd; \
	printf 'root:x:0:\nnogroup:x:65534:\n' > /etc/group; \
	printf 'hosts: files dns\n' > /etc/nsswitch.conf

FROM scratch AS runtime

ENV PATH=/usr/local/bin
ENV LANG=C.UTF-8
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
ENV PYTHONDONTWRITEBYTECODE=1

COPY --from=runtime-files /usr/local /usr/local
# Runtime shared libraries and merged-usr symlinks harvested above.
COPY --from=runtime-files /runtime-root /
COPY --from=runtime-files /etc/passwd /etc/passwd
COPY --from=runtime-files /etc/group /etc/group
COPY --from=runtime-files /etc/nsswitch.conf /etc/nsswitch.conf
COPY --from=runtime-files /etc/protocols /etc/protocols
COPY --from=runtime-files /etc/services /etc/services
COPY --from=runtime-files /etc/ssl/certs /etc/ssl/certs
COPY --from=runtime-files /usr/share/zoneinfo /usr/share/zoneinfo

ENTRYPOINT ["python3"]
EOF
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
        write_header "${output_file}" "${ubuntu_base_image}" 'FROM ${UBUNTU_BASE_IMAGE} AS dev'
        install_python "${output_file}" "${python_version}" "${debian_variant}" "${debian_version}"
        append_runtime_image "${output_file}"
        echo '' >>"${output_file}"
    done
done

echo "Done !"
