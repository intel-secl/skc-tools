#!/bin/bash
SGX_AGENT_DIR=$PWD/sgx_agent
SGX_AGENT_BIN_DIR=$SGX_AGENT_DIR/bin
SGX_VERSION=2.10
OS_FLAVOUR="rhel8.1"
SGX_URL="https://download.01.org/intel-sgx/sgx-linux/${SGX_VERSION}/distro/$OS_FLAVOUR-server"

download_psw_qpl_qgl()
{
	wget -q $SGX_URL/sgx_rpm_local_repo.tgz -P $SGX_AGENT_BIN_DIR || exit 1
}

download_psw_qpl_qgl
