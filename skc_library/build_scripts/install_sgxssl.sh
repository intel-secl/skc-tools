#!/bin/bash
SKCLIB_DIR=$PWD/skc_library
SGX_VERSION=2.10
GIT_CLONE_PATH=/tmp/sgx
SGX_SSL_CLONE_URL="https://github.com/intel/intel-sgx-ssl.git"
SGXSSL_TAG=lin_2.10_1.1.1g
SGXSSL_CVE_URL="https://download.01.org/intel-sgx/sgx-linux/${SGX_VERSION}/as.ld.objdump.gold.r2.tar.gz"
OS_FLAVOUR="rhel8.1"
OPENSSL_URL="https://www.openssl.org/source/openssl-1.1.1g.tar.gz"

install_sgxssl()
{
	pushd $PWD
	mkdir -p $GIT_CLONE_PATH
	cd $GIT_CLONE_PATH
	git clone $SGX_SSL_CLONE_URL $GIT_CLONE_PATH/sgxssl
	cd $GIT_CLONE_PATH/sgxssl
	git checkout $SGXSSL_TAG

	wget -q $SGXSSL_CVE_URL -O - | tar -xz
	cp -rpf external/toolset/$OS_FLAVOUR/* /usr/local/bin

	cd openssl_source
	wget -q $OPENSSL_URL || exit 1
	cd ../Linux
	make all
	make install
	popd
	mkdir -p $SKCLIB_DIR/sgxssl
	cp -rpf /opt/intel/sgxssl/lib64 $SKCLIB_DIR/sgxssl/lib64
	rm -rf $GIT_CLONE_PATH/sgxssl
}

install_sgxssl
