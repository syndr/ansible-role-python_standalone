#!/bin/bash
# Install pypy inside of a virtualenv, and configure it with the desired modules
#
# This script depends on the following environment variables:
#   - LANG: C
#   - LC_CTYPE: C
#   - LC_ALL: C
#   - LC_MESSAGES: C
#   - PKG_HOME: "{{python_standalone_pkg_home}}"
#   - PYPY_VERSION: "{{python_standalone_pypy_version}}"
#   - PYPY_FLAVOR: "{{python_standalone_pypy_flavor}}"
#   - PYPY_DOWNLOAD_URL: "{{python_standalone_pypy_url}}"
#   - PYPY_SHA256: "{{python_standalone_pypy_sha256}}"
#   - PYPY_MODULES_LIST: "{{python_standalone_pypy_modules | join(' ') }}"
#   - VENV_DOWNLOAD_URL: "{{python_standalone_venv_url}}"
#   - VENV_SHA256: "{{python_standalone_venv_sha256}}"
#   - SYSTEM_SSL_CERTS: "{{python_standalone_ssl_certs}}"
#


# The user accessible location of the pypy install (the venv is installed here)
PYPY_HOME="$PKG_HOME/pypy"

# The actual location of the pypy install -- should not be accessed directly
PYPY_INSTALL="$PKG_HOME/.pypy"

# The filename of the downloaded pypy tarball
PYPY_FILENAME="pypy$PYPY_VERSION-$PYPY_FLAVOR.tar.bz2"

# The filename of the downloaded virtualenv install package
VENV_FILENAME="virtualenv.pyz"

# The working directory for this script
WORKING_DIR="/tmp"

# Fail fast
set -e


function get_pypy() {
    echo "Downloading pypy $PYPY_VERSION-$PYPY_FLAVOR..."

    curl --retry 5 -L -o "$PYPY_FILENAME" "$PYPY_DOWNLOAD_URL/$PYPY_FILENAME" --output $WORKING_DIR/$PYPY_FILENAME

    if [[ -n "$PYPY_SHA256" ]]; then
        echo Checking sha256sum...
        echo "$PYPY_SHA256  $PYPY_FILENAME" > "$PYPY_FILENAME.sha256"
        sha256sum -c "$PYPY_FILENAME.sha256"
    fi

    echo Extracting tarball...
    tar -xjf "$PYPY_FILENAME"
    rm -f "$PYPY_FILENAME"

}

function get_virtualenv() {
    echo "Downloading virtualenv..."
    curl --retry 5 -L -o "$VENV_FILENAME" "$VENV_DOWNLOAD_URL"

    if [[ -n "$VENV_SHA256" ]]; then
        echo Checking sha256sum...
        echo "$VENV_SHA256  $VENV_FILENAME" > "$VENV_FILENAME.sha256"
        sha256sum -c "$VENV_FILENAME.sha256"
    fi
}

function wipe_install() {
    echo Clobbering application directory...
    $SUDO mkdir -p "$PYPY_INSTALL"
    $SUDO rm -rf "$PYPY_INSTALL"

    echo Clobbering python home directory...
    $SUDO mkdir -p `dirname "$PYPY_HOME"`
    $SUDO rm -rf "$PYPY_HOME"

}

function install_pypy() {
    echo "Installing pypy $PYPY_VERSION-$PYPY_FLAVOR..."
    $SUDO mv -n "pypy$PYPY_VERSION-$PYPY_FLAVOR" "$PYPY_INSTALL"
    $SUDO mv -n "$VENV_FILENAME" "$PYPY_INSTALL/$VENV_FILENAME"

    echo "Creating virtualenv in $PYPY_HOME..."
    $SUDO "$PYPY_INSTALL/bin/pypy" "$PYPY_INSTALL/$VENV_FILENAME" -p "$PYPY_INSTALL/bin/pypy" "$PYPY_HOME" --system-site-packages

    # make sure PATH contains the location where pip, wheel and friends are
    # so that ansible knows where to find them
    # this is needed since ansible 2.1 changed the way ansible_python_interpreter
    # is parsed
    echo Massaging PATH...
    $SUDO mkdir "$PYPY_INSTALL/site-packages"
    cat <<EOF > "$PYPY_INSTALL/site-packages/sitecustomize.py"
import os
import sys

os.environ["PATH"] += os.pathsep + os.path.sep.join([sys.prefix, "bin"])
EOF

    PYPY_SSL_PATH=`$PYPY_INSTALL/bin/pypy -c 'from __future__ import print_function; import ssl; print(ssl.get_default_verify_paths().openssl_capath)'`

    if [ $PYPY_SSL_PATH != "None" ]; then
        echo Linking system SSL certs...
        sudo mkdir -p `dirname $PYPY_SSL_PATH`
        sudo ln -sf $SYSTEM_SSL_CERTS $PYPY_SSL_PATH
    fi
}




#####↓↓↓↓↓↓##### MAIN #####↓↓↓↓↓↓#####

# Do we need sudo?
if [[ `stat -c '%U' $PKG_HOME 2>/dev/null || echo root` != `whoami` ]]; then
    SUDO="sudo"
else
    SUDO=""
fi

cd $WORKING_DIR

# Download pypy
get_pypy

# Download virtualenv
get_virtualenv

# Wipe out any existing install
wipe_install

# Install pypy
install_pypy

# This should fail if the virtualenv is not created properly
PIP_VERSION=`$PYPY_HOME/bin/pip --version | awk '{ print $2 }'`
WHEEL_VERSION=`$PYPY_HOME/bin/wheel version | awk '{ print $2 }'`

# Install requested modules
echo "Installing modules..."
echo "$PYPY_MODULES_LIST" | tr ' ' '\n' > $WORKING_DIR/requirements.txt
$PYPY_HOME/bin/pip install -r $WORKING_DIR/requirements.txt

echo 🐍




## This might be useful at some point.. maybe..
#
#sudo mkdir -p "$ANSIBLE_FACTS_DIR"
#sudo chown `whoami` "$ANSIBLE_FACTS_DIR"
#
#cat > "$ANSIBLE_FACTS_DIR/bootstrap.fact" <<EOF
#[pypy]
#version=$PYPY_VERSION
#ssl_path=$PYPY_SSL_PATH
#install_location=$PKG_HOME
#modules=$PYPY_MODULES_LIST
#
#[pip]
#version=$PIP_VERSION
#
#[wheel]
#version=$WHEEL_VERSION
#EOF
