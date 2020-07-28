#!/bin/bash
SGX_INSTALL_DIR=/opt/intel
SGX_VERSION=2.10
OS_FLAVOUR="rhel8.1"
SGX_URL="https://download.01.org/intel-sgx/sgx-linux/${SGX_VERSION}/distro/$OS_FLAVOUR-server"
SGX_SDK_VERSION=2.10.100.2

install_sgxsdk()
{
	wget -q $SGX_URL/sgx_linux_x64_sdk_$SGX_SDK_VERSION.bin || exit 1
	chmod u+x sgx_linux_x64_sdk_$SGX_SDK_VERSION.bin
	sh sgx_linux_x64_sdk*.bin -prefix=$SGX_INSTALL_DIR || exit 1
	source $SGX_INSTALL_DIR/sgxsdk/environment
	rm -f sgx_linux_x64_sdk_$SGX_SDK_VERSION.bin
}

install_sgxsdk
