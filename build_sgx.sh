#!/bin/bash

SGX_VERSION=2.10
SGX_DRIVER_VERSION=1.35
SGX_SDK_VERSION=2.10.100.2
OS_FLAVOUR="rhel8.1"
SYSLIB_PATH=/usr/lib64
SGX_INSTALL_DIR=/opt/intel
GIT_CLONE_PATH=/tmp/sgx
CTK_BRANCH="v14+next-major"
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
	if [[ -d $SGX_INSTALL_DIR/sgxsdk ]]; then
		echo "uninstall sgxsdk"
		$SGX_INSTALL_DIR/sgxsdk/uninstall.sh
	fi

	modprobe -r intel_sgx
	dkms remove -m sgx -v $SGX_DRIVER_VERSION --all

	if [ -d /usr/src/sgx-$SGX_DRIVER_VERSION ]; then
		rm -rf /usr/src/sgx-$SGX_DRIVER_VERSION/
	fi

	if [[ -d $SGX_INSTALL_DIR/sgxssl ]]; then
		echo "uninstall sgxssl"
		rm -rf $SGX_INSTALL_DIR/sgxssl
	fi

	if [[ -d $CTK_INSTALL ]]; then
		echo "uninstall cryptoapitoolkit"
		rm -rf $CTK_INSTALL
	fi

	rpm -qa | grep 'sgx' | xargs rpm -e
	rm -rf /etc/yum.repos.d/tmp_sgxstuff_sgx_rpm_local_repo.repo
	rm -rf /usr/local/bin/ld /usr/local/bin/as /usr/local/bin/ld.gold /usr/local/bin/objdump
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
	chmod +x *.bin

	# install sgx dcap driver if it is not intel-next kernel
	if [ -z "$INKERNEL_SGX" ]; then
		echo "Installing dcap driver"
		./sgx_linux_x64_driver_${SGX_DRIVER_VERSION}.bin -prefix=$SGX_INSTALL_DIR || exit 1
	else
		echo "Found inbuilt sgx driver, skipping dcap driver installation"
	fi
	# install sgx sdk
	./sgx_linux_x64_sdk*.bin -prefix=$SGX_INSTALL_DIR || exit 1
	source $SGX_INSTALL_DIR/sgxsdk/environment

	# install sgx psw/qgl/qpl
	wget -q -c $SGX_URL/sgx_rpm_local_repo.tgz -O - | tar -xz
	yum-config-manager --add-repo file://$PWD/sgx_rpm_local_repo
	yum install -y --nogpgcheck libsgx-launch libsgx-uae-service libsgx-urts libsgx-ae-qve libsgx-dcap-ql libsgx-dcap-ql-devel libsgx-dcap-default-qpl-devel libsgx-dcap-default-qpl

	sed -i "s|PCCS_URL=.*|PCCS_URL=https://localhost:9000/scs/sgx/certification/v1/|g" /etc/sgx_default_qcnl.conf
	sed -i "s/USE_SECURE_CERT=.*/USE_SECURE_CERT=FALSE/g" /etc/sgx_default_qcnl.conf
	popd
}

install_sgxtoolkit()
{
	rm -rf $GIT_CLONE_PATH/crypto-api-toolkit-v2
	git clone $CTK_REPO $GIT_CLONE_PATH/crypto-api-toolkit-v2
	cp scripts/sgx_measurement.diff $GIT_CLONE_PATH/crypto-api-toolkit-v2
	pushd $GIT_CLONE_PATH/crypto-api-toolkit-v2
	git checkout $CTK_BRANCH
	git apply sgx_measurement.diff
	
	bash autogen.sh
	./configure --with-p11-kit-path=$P11_KIT_PATH --prefix=$CTK_INSTALL --enable-dcap || exit 1
	make install
	popd
}

install_prerequisites()
{
	yum update -y
	yum groupinstall -y "Development Tools"
	# RHEL 8 does not provide epel repo out of the box.
	yum localinstall -y https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/e/epel-release-8-8.el8.noarch.rpm
	yum install -y yum-utils python3 kernel-devel dkms elfutils-libelf-devel wget libcurl-devel ocaml protobuf cppunit-devel p11-kit-devel openssl-devel || exit 1
	ln -sf /usr/bin/python3 /usr/bin/python
}

install_prerequisites
uninstall_sgx
install_sgx_components
install_sgxssl
install_sgxtoolkit
