#!/bin/bash
SGX_DRIVER_VERSION=1.35
SGX_INSTALL_DIR=/opt/intel
SGX_TOOLKIT_INSTALL_PREFIX=$SGX_INSTALL_DIR/cryptoapitoolkit
KDIR=/lib/modules/$(uname -r)/build
INKERNEL_SGX=$(cat $KDIR/.config | grep "CONFIG_INTEL_SGX=y")
CENTRL_REPO=$PWD
bold=$(tput bold)
normal=$(tput sgr0)

uninstall_sgx()
{
	if [[ -d $SGX_TOOLKIT_INSTALL_PREFIX ]]; then
		echo "Uninstalling cryptoapitoolkit"
		rm -rf $SGX_TOOLKIT_INSTALL_PREFIX
	fi

	if [[ -d $SGX_INSTALL_DIR/sgxssl ]]; then
		echo "uninstalling sgxssl"
		rm -rf $SGX_INSTALL_DIR/sgxssl
	fi

	echo "uninstalling sgx psw/qgl"
	rpm -qa | grep 'sgx' | xargs rpm -e
	rm -rf /etc/yum.repos.d/*sgx_rpm_local_repo.repo

	echo "uninstalling sgx dcap driver"
	sh $SGX_INSTALL_DIR/sgxdriver/uninstall.sh
}

install_sgxssl()
{
	cp -prf $CENTRL_REPO/sgxssl $SGX_INSTALL_DIR
}

install_dcap_driver()
{
	pushd $CENTRL_REPO/sgx_driver
	# install sgx dcap driver if not intel-next kernel
	if [ -z "$INKERNEL_SGX" ]; then
		echo "installing sgx dcap driver"
		chmod u+x sgx_linux_x64_driver_${SGX_DRIVER_VERSION}.bin
		./sgx_linux_x64_driver_${SGX_DRIVER_VERSION}.bin -prefix=$SGX_INSTALL_DIR || exit 1
	else
		echo "found in-built sgx dcap driver, skipping installation"
	fi
	popd
}

install_psw()
{
	pushd $CENTRL_REPO/sgxpsw
	tar -xzf sgx_rpm_local_repo.tgz
	yum-config-manager --add-repo file://$PWD/sgx_rpm_local_repo
	dnf install -y --nogpgcheck libsgx-launch libsgx-uae-service libsgx-urts libsgx-ae-qve libsgx-dcap-ql libsgx-dcap-ql-devel libsgx-dcap-default-qpl-devel libsgx-dcap-default-qpl
	popd
}

install_ctk()
{
	cp -prf ${CENTRL_REPO}/cryptoapitoolkit $SGX_INSTALL_DIR
}

check_for_prerequisites()
{
	echo "Checking if dependent packages are installed"
	pkg_list='epel-release kernel-devel kernel-headers yum-utils dkms protobuf'
	for pkg in $pkg_list
	do
		if rpm -q $pkg
		then
			continue
		else
			echo "${bold}$pkg NOT installed${normal}. Please refer to the install document"
			exit 1
		fi
	done
}

for arg in "$@"
do
	check_for_prerequisites
	case $arg in
		uninstall)
			uninstall_sgx
			;;
		driver)
			install_dcap_driver
			;;
		sgxpsw)
			install_psw
			;;
		sgxssl)
			install_sgxssl
			;;
		ctk)
			install_ctk
			;;
		all)
			uninstall_sgx
			install_dcap_driver
			install_psw
			install_sgxssl
			install_ctk
	esac
done
