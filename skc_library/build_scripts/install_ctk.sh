#!/bin/bash
SKCLIB_DIR=$PWD/skc_library
SGX_INSTALL_DIR=/opt/intel
GIT_CLONE_PATH=/tmp/sgx
GIT_CLONE_SGX_CTK=$GIT_CLONE_PATH/crypto-api-toolkit
CTK_REPO="ssh://git@gitlab.devtools.intel.com:29418/sst/isecl/crypto-api-toolkit.git"
CTK_BRANCH="v15+next-major"
CTK_INSTALL=$SGX_INSTALL_DIR/cryptoapitoolkit
P11_KIT_PATH=/usr/include/p11-kit-1/p11-kit/
CTK_PREFIX=$SGX_INSTALL_DIR/cryptoapitoolkit

install_cryptoapitoolkit()
{
	pushd $PWD
	mkdir -p $GIT_CLONE_PATH
        rm -rf $GIT_CLONE_SGX_CTK
        git clone $CTK_REPO $GIT_CLONE_SGX_CTK
        cd $GIT_CLONE_SGX_CTK
        git checkout $CTK_BRANCH
        bash autogen.sh
        ./configure --with-p11-kit-path=$P11_KIT_PATH --prefix=$CTK_INSTALL --enable-dcap || exit 1
	make install
	popd
	cp -rpf $CTK_INSTALL $SKCLIB_DIR
}

check_prerequisites()
{
        if [ ! -f /opt/intel/sgxsdk/bin/x64/sgx_edger8r ];then
                echo "sgx sdk is required for building cryptokit."
                exit 1
        fi

        if [ ! -f /opt/intel/sgxssl/include/sgx_tsgxssl.edl ]; then
                echo "sgx ssl is required for building cryptokit."
                exit 1
        fi
}

check_prerequisites
install_cryptoapitoolkit
