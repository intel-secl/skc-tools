#!/bin/bash
SKCLIB_BIN=bin
SGX_DRIVER_VERSION=1.35
SGX_INSTALL_DIR=/opt/intel
SKC_LIBRARY_BIN_NAME=skc_library_M13_v1.0.bin

source skc_library.conf

KDIR=/lib/modules/$(uname -r)/build
/sbin/lsmod | grep intel_sgx >/dev/null 2>&1
SGX_DRIVER_INSTALLED=$?
cat $KDIR/.config | grep "CONFIG_INTEL_SGX=y" > /dev/null
INKERNEL_SGX=$?

install_prerequisites()
{
	source deployment_prerequisites.sh 
	if [[ $? -ne 0 ]]
	then
		echo "pre requisited installation failed"
		exit 1
	fi
}

install_dcap_driver()
{
	if [[ $SGX_DRIVER_INSTALLED -eq 0 ]]; then
		echo "found sgx driver, skipping dcap driver installation"
		return
	fi
	if [[ $INKERNEL_SGX -eq 0 ]]; then
		echo "found in-built sgx driver, skipping dcap driver installation"
		return
	fi

	chmod u+x $SKCLIB_BIN/sgx_linux_x64_driver_${SGX_DRIVER_VERSION}.bin
	$SKCLIB_BIN/sgx_linux_x64_driver_${SGX_DRIVER_VERSION}.bin -prefix=$SGX_INSTALL_DIR || exit 1
	echo "sgx dcap driver installed"
}

install_psw_qgl()
{
	tar -xvf $SKCLIB_BIN/sgx_rpm_local_repo.tgz
	yum-config-manager --add-repo file://$PWD/sgx_rpm_local_repo || exit 1
	yum-config-manager --save --setopt=tmp_sgxstuff_sgx_rpm_local_repo.gpgcheck=0
	dnf install -y --nogpgcheck libsgx-launch libsgx-uae-service libsgx-urts libsgx-ae-qve libsgx-dcap-ql libsgx-dcap-ql-devel libsgx-dcap-default-qpl-devel libsgx-dcap-default-qpl || exit 1

	sed -i "s|PCCS_URL=.*|PCCS_URL=https://$SCS_IP:$SCS_PORT/scs/sgx/certification/v1/|g" /etc/sgx_default_qcnl.conf
	sed -i "s|USE_SECURE_CERT=.*|USE_SECURE_CERT=FALSE|g" /etc/sgx_default_qcnl.conf
}

install_sgxssl()
{
	cp -prf sgxssl $SGX_INSTALL_DIR
}

install_cryptoapitoolkit()
{
	cp -prf cryptoapitoolkit $SGX_INSTALL_DIR
}

install_skc_library_bin()
{
	$SKCLIB_BIN/$SKC_LIBRARY_BIN_NAME
	if [ $? -ne 0 ]
	then
		echo "SKC Library installation failed with $?"
		exit 1
	fi
}

run_post_deployment_script()
{
	if [  ! -f /etc/pki/tls/openssl.cnf.orig ]
	then
		mv /etc/pki/tls/openssl.cnf /etc/pki/tls/openssl.cnf.orig
		cp -pf openssl.cnf /etc/pki/tls/
	fi
	if [  ! -f /etc/nginx/nginx.conf.orig ]
	then
		mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.orig
		cp -pf nginx.conf /etc/nginx/
	fi
	./skc_library_create_roles.sh
	if [ $? -ne 0 ]
	then
		echo "failed to create skc_library roles and get TLS certificate from CMS"
		exit 1
	fi
}

install_prerequisites
install_dcap_driver
install_psw_qgl
install_sgxssl
install_cryptoapitoolkit
install_skc_library_bin
run_post_deployment_script
