#!/bin/bash

SGX_VERSION=2.10
SGX_DRIVER_VERSION=1.35
SGX_SDK_VERSION=2.10.100.2
OS_FLAVOUR="rhel8.1"
SGX_INSTALL_DIR=/opt/intel
GIT_CLONE_PATH=/tmp/sgx
CTK_BRANCH="v15+next-major"
CTK_INSTALL=$SGX_INSTALL_DIR/cryptoapitoolkit
P11_KIT_PATH=/usr/include/p11-kit-1/p11-kit/
SGX_URL="https://download.01.org/intel-sgx/sgx-linux/${SGX_VERSION}/distro/$OS_FLAVOUR-server"
CTK_REPO="ssh://git@gitlab.devtools.intel.com:29418/sst/isecl/crypto-api-toolkit.git"
OPENSSL_URL="https://www.openssl.org/source/openssl-1.1.1g.tar.gz"
SGXSSL_CVE_URL="https://download.01.org/intel-sgx/sgx-linux/${SGX_VERSION}/as.ld.objdump.gold.r2.tar.gz"
SGXSSL_TAG=lin_2.10_1.1.1g
KDIR=/lib/modules/$(uname -r)/build
INKERNEL_SGX=$(cat $KDIR/.config | grep "CONFIG_INTEL_SGX=y")

uninstall_sgx()
{
	if [[ -d $CTK_INSTALL ]]; then
		echo "uninstalling cryptoapitoolkit"
		rm -rf $CTK_INSTALL
	fi

	if [[ -d $SGX_INSTALL_DIR/sgxssl ]]; then
		echo "uninstalling sgxssl"
		rm -rf $SGX_INSTALL_DIR/sgxssl
	fi

	echo "uninstalling sgx psw/qgl"
	rpm -qa | grep 'sgx' | xargs rpm -e
	rm -rf /etc/yum.repos.d/tmp_sgxstuff_sgx_rpm_local_repo.repo
	rm -rf /usr/local/bin/ld /usr/local/bin/as /usr/local/bin/ld.gold /usr/local/bin/objdump

	if [[ -d $SGX_INSTALL_DIR/sgxsdk ]]; then
		echo "uninstalling sgxsdk"
		sh $SGX_INSTALL_DIR/sgxsdk/uninstall.sh
	fi

	echo "uninstalling sgx dcap driver"
	sh $SGX_INSTALL_DIR/sgxdriver/uninstall.sh
	rm -rf $GIT_CLONE_PATH
}

install_sgxssl()
{
	mkdir -p $GIT_CLONE_PATH
	pushd $GIT_CLONE_PATH
	git clone https://github.com/intel/intel-sgx-ssl.git $GIT_CLONE_PATH/sgxssl
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
}

install_sgx_components()
{
	pushd $PWD
	mkdir -p $GIT_CLONE_PATH
	pushd $GIT_CLONE_PATH
	wget -q $SGX_URL/sgx_linux_x64_driver_$SGX_DRIVER_VERSION.bin
	wget -q $SGX_URL/sgx_linux_x64_sdk_$SGX_SDK_VERSION.bin
	chmod u+x *.bin

	# install sgx dcap driver if it is not intel-next kernel
	if [ -z "$INKERNEL_SGX" ]; then
		echo "Installing dcap driver"
		./sgx_linux_x64_driver_${SGX_DRIVER_VERSION}.bin -prefix=$SGX_INSTALL_DIR || exit 1
	else
		echo "Found in-built sgx driver, skipping dcap driver installation"
	fi
	# install sgx sdk
	./sgx_linux_x64_sdk_$SGX_SDK_VERSION.bin -prefix=$SGX_INSTALL_DIR || exit 1
	source $SGX_INSTALL_DIR/sgxsdk/environment

	# install sgx psw/qgl/qpl
	wget -q -c $SGX_URL/sgx_rpm_local_repo.tgz -O - | tar -xz
	yum-config-manager --add-repo file://$PWD/sgx_rpm_local_repo
	dnf install -y --nogpgcheck libsgx-launch libsgx-uae-service libsgx-urts libsgx-ae-qve libsgx-dcap-ql libsgx-dcap-ql-devel libsgx-dcap-default-qpl-devel libsgx-dcap-default-qpl
	popd
}

install_ctk()
{
	rm -rf $GIT_CLONE_PATH/crypto-api-toolkit
	git clone $CTK_REPO $GIT_CLONE_PATH/crypto-api-toolkit
	pushd $GIT_CLONE_PATH/crypto-api-toolkit
	git checkout $CTK_BRANCH
	
	bash autogen.sh
	./configure --with-p11-kit-path=$P11_KIT_PATH --prefix=$CTK_INSTALL --enable-dcap || exit 1
	make install
	popd
}

install_prerequisites()
{
	dnf localinstall -y https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/e/epel-release-8-8.el8.noarch.rpm
	dnf install -y make wget git tar gcc-c++ automake autoconf libtool yum-utils kernel-devel dkms protobuf cppunit-devel p11-kit-devel openssl-devel || exit 1
}

for arg in "$@"
do
	install_prerequisites
	case $arg in
		uninstall)
			uninstall_sgx
			;;
		sgx)
			install_sgx_components
			;;
		sgxssl)
			install_sgxssl
			;;
		ctk)
			install_ctk
			;;
		all)
			uninstall_sgx
			install_sgx_components
			install_sgxssl
			install_ctk
	esac
done
