#!/bin/bash
export DEBIAN_FRONTEND="noninteractive"
set -eo pipefail

apt-get update && apt-get install -y \
    build-essential \
    libssl-dev \
    uuid-dev \
    libgpgme11-dev \
    squashfs-tools \
    libseccomp-dev \
    pkg-config

export GOLANG_VERSION=1.19.5
export SINGULARITY_VERSION=3.10.5

mkdir -p /opt/go/${GOLANG_VERSION}
mkdir -p /opt/singularity/${SINGULARITY_VERSION}

export OS=linux
export ARCH=amd64

cd /opt/go/${GOLANG_VERSION}
wget -q https://dl.google.com/go/go$GOLANG_VERSION.$OS-$ARCH.tar.gz
tar -xzf go$GOLANG_VERSION.$OS-$ARCH.tar.gz
rm go$GOLANG_VERSION.$OS-$ARCH.tar.gz
# tar -C /usr/local -xzf go$GOLANG_VERSION.$OS-$ARCH.tar.gz

export GOPATH=/var/tmp/go
export GOCACHE=/var/tmp/go/.cache/go-build
mkdir -p ${GOPATH}/{bin,pkg,src}

cd /opt/singularity/${SINGULARITY_VERSION}
wget -q https://github.com/sylabs/singularity/releases/download/v${SINGULARITY_VERSION}/singularity-ce-${SINGULARITY_VERSION}.tar.gz
tar -xzf singularity-ce-${SINGULARITY_VERSION}.tar.gz
mv singularity-ce-${SINGULARITY_VERSION} singularity

cd singularity

mkdir -p /opt/apps/singularity/${SINGULARITY_VERSION}
export PATH=/opt/go/${GOLANG_VERSION}/go/bin:$PATH

./mconfig --prefix=/opt/apps/singularity/${SINGULARITY_VERSION}
make -C ./builddir
make -C ./builddir install

rm -rf ${GOPATH}

mkdir -p /opt/apps/modulefiles/singularity

bash -c "cat > /opt/apps/modulefiles/singularity/${SINGULARITY_VERSION}" <<SINGULARITY_MODULEFILE
#%Module1.0#####################################################################
##
## modules singularity/${SINGULARITY_VERSION}.
##
## modulefiles/singularity/${SINGULARITY_VERSION}.
##
proc ModulesHelp { } {
        global version modroot
        puts stderr "singularity/${SINGULARITY_VERSION} - sets the environment for Singularity ${SINGULARITY_VERSION}"
}
module-whatis   "Sets the environment for using Singularity ${VERSION}"
# for Tcl script use only
set     topdir          /opt/apps/singularity/${SINGULARITY_VERSION}
set     version         ${SINGULARITY_VERSION}
set     sys             linux86
prepend-path    PATH            \$topdir/bin
SINGULARITY_MODULEFILE