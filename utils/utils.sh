#!/bin/bash

function temp_folder(){
    # Use date instead of /dev/urandom since it's based on driver noise
    # and thus does not work in CI
    uuid="$(date | sed 's/[^0-9]//g')"
    temp_folder="temp_${uuid}"
    mkdir ${temp_folder}
    cd ${temp_folder}
}

function cleanup_folder(){
    folder="$(pwd)"
    cd ..
    rm -rf ${folder}
}

function apt_install_temp_packages() {
    output_file=$1
    packages=${@:2}
    echo 'RUN savedAptMark="$(apt-mark showmanual)" \' >>${output_file}
    echo '&& apt update \' >>${output_file}
    echo "&& apt install ${packages} -y --no-install-recommends \\" >>${output_file}
}

function apt_clean_temp_packages() {
    output_file=$1

    cat >>"${output_file}" <<-'EOF'
&& apt-mark auto '.*' > /dev/null \
&& apt-mark manual $savedAptMark \
&& apt purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
&& apt autoclean \
&& apt clean \
&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
EOF
}

function apt_install_packages() {
    output_file=$1
    packages=${@:2}
    echo 'RUN apt update \' >>${output_file}
    echo "&& apt install ${packages} -y --no-install-recommends \\" >>${output_file}
    echo "&& apt autoclean \\" >>${output_file}
    echo "&& apt clean \\" >>${output_file}
    echo "&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*" >>${output_file}
}