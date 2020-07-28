#!/bin/bash
SKCLIB_DIR=$PWD/skc_library
SKCLIB_BIN_DIR=$SKCLIB_DIR/bin
SGX_VERSION=2.10
OS_FLAVOUR="rhel8.1"
SGX_URL="https://download.01.org/intel-sgx/sgx-linux/${SGX_VERSION}/distro/$OS_FLAVOUR-server"
SGX_DRIVER_VERSION=1.35

fetch_dcap_driver()
{
	wget -q $SGX_URL/sgx_linux_x64_driver_$SGX_DRIVER_VERSION.bin -P $SKCLIB_BIN_DIR || exit 1
}

fetch_dcap_driver
