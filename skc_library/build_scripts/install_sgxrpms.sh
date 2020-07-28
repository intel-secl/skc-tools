#!/bin/bash
SKCLIB_DIR=$PWD/skc_library
SKCLIB_BIN_DIR=$SKCLIB_DIR/bin
SGX_VERSION=2.10
OS_FLAVOUR="rhel8.1"
SGX_URL="https://download.01.org/intel-sgx/sgx-linux/${SGX_VERSION}/distro/$OS_FLAVOUR-server"

install_psw_qpl_qgl()
{
	wget -q $SGX_URL/sgx_rpm_local_repo.tgz || exit 1
	cp -pf sgx_rpm_local_repo.tgz $SKCLIB_BIN_DIR 
        tar -xf sgx_rpm_local_repo.tgz
        yum-config-manager --add-repo file://$PWD/sgx_rpm_local_repo || exit 1
        #dnf install -y --nogpgcheck libsgx-launch libsgx-uae-service libsgx-urts libsgx-ae-qve libsgx-dcap-ql libsgx-dcap-ql-devel libsgx-dcap-default-qpl-devel libsgx-dcap-default-qpl || exit 1
        dnf install -y --nogpgcheck libsgx-launch libsgx-uae-service libsgx-urts 

        sed -i "s/USE_SECURE_CERT=.*/USE_SECURE_CERT=FALSE/g" /etc/sgx_default_qcnl.conf
	rm -rf sgx_rpm_local_repo sgx_rpm_local_repo.tgz 
}

install_psw_qpl_qgl
