#!/bin/bash
SGX_AGENT_DIR=$PWD/sgx_agent
DCAP_VERSION=1.7
SGX_AGENT_BIN_DIR=$SGX_AGENT_DIR/bin
MP_RPM_VER=1.7.90.2-1
OS_FLAVOUR="rhel8.1-server"
MPA_URL="https://download.01.org/intel-sgx/sgx-dcap/$DCAP_VERSION/linux/tools/SGXMultiPackageAgent/$OS_FLAVOUR"

fetch_mpa_uefi_rpm() {
	wget -q $MPA_URL/libsgx-ra-uefi-$MP_RPM_VER.el8.x86_64.rpm -P $SGX_AGENT_BIN_DIR || exit 1
}

fetch_mpa_uefi_rpm
