#!/bin/bash
SGX_VERSION=2.10
SGX_DRIVER_VERSION=1.35
SGX_SDK_VERSION=2.10.100.2
OS_FLAVOUR="rhel8.1"
SGX_URL="https://download.01.org/intel-sgx/sgx-linux/${SGX_VERSION}/distro/$OS_FLAVOUR-server"
CTK_URL="https://gitlab.devtools.intel.com/sst/isecl/crypto-api-toolkit.git"
OPENSSL_URL="https://www.openssl.org/source/openssl-1.1.1g.tar.gz"
SGXSSL_URL="https://github.com/intel/intel-sgx-ssl.git"
SGXSSL_CVE_URL="https://download.01.org/intel-sgx/sgx-linux/$SGX_VERSION/as.ld.objdump.gold.r2.tar.gz"
CTK_BRANCH="v14+next-major"
SGXSSL_TAG=lin_2.10_1.1.1g
SGX_INSTALL_DIR=/opt/intel
P11_KIT_PATH=/usr/include/p11-kit-1/p11-kit
CTK_INSTALL=$SGX_INSTALL_DIR/cryptoapitoolkit
CENTRAL_REPO_DIR=~/central_repo
TAR_DIR=central_repo

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

	if [[ -d $SGX_INSTALL_DIR/sgxsdk ]]; then
		echo "uninstalling sgxsdk"
		sh $SGX_INSTALL_DIR/sgxsdk/uninstall.sh
	fi

	rpm -qa | grep 'sgx' | xargs rpm -e
	rm -rf /etc/yum.repos.d/*_sgx_rpm_local_repo.repo
	rm -rf /usr/local/bin/ld /usr/local/bin/as /usr/local/bin/ld.gold /usr/local/bin/objdump 
}

create_central_repo()
{
	if [ -d "$CENTRAL_REPO_DIR" ]; then
		mkdir -p ${CENTRAL_REPO_DIR}_old/
		mv -f $CENTRAL_REPO_DIR ${CENTRAL_REPO_DIR}_old/${TAR_DIR}_$(date +"%Y%m%d%H%M")
		mkdir $CENTRAL_REPO_DIR
		echo "NOTE: Old Central Repo is moved to ${CENTRAL_REPO_DIR}_old/${TAR_DIR}_$(date +"%Y%m%d%H%M")"
	else
		mkdir $CENTRAL_REPO_DIR
	fi
	cp deploy_sgx_artifacts.sh $CENTRAL_REPO_DIR/
}

package_dcap_driver()
{
	mkdir ${CENTRAL_REPO_DIR}/sgx_driver
	wget -q $SGX_URL/sgx_linux_x64_driver_$SGX_DRIVER_VERSION.bin -P ${CENTRAL_REPO_DIR}/sgx_driver
}

install_sgxsdk()
{
	wget -q $SGX_URL/sgx_linux_x64_sdk_$SGX_SDK_VERSION.bin
	chmod u+x sgx_linux_x64_sdk_$SGX_SDK_VERSION.bin
	sh sgx_linux_x64_sdk_$SGX_SDK_VERSION.bin -prefix=$SGX_INSTALL_DIR || exit 1
	source $SGX_INSTALL_DIR/sgxsdk/environment
	rm -rf ./sgx_linux_x64_sdk_$SGX_SDK_VERSION.bin
}

package_psw_rpms()
{
	mkdir -p ${CENTRAL_REPO_DIR}/sgxpsw
	wget -q $SGX_URL/sgx_rpm_local_repo.tgz
	cp sgx_rpm_local_repo.tgz ${CENTRAL_REPO_DIR}/sgxpsw
	tar -xzf sgx_rpm_local_repo.tgz
	yum-config-manager --add-repo file://$PWD/sgx_rpm_local_repo
	dnf install -y --nogpgcheck libsgx-dcap-ql-devel
	rm -rf sgx_rpm_local_repo.tgz sgx_rpm_local_repo
}

install_sgxssl()
{
	pushd $PWD
	git clone $SGXSSL_URL
	cd intel-sgx-ssl
	git checkout $SGXSSL_TAG
	wget -q $SGXSSL_CVE_URL -O - | tar -xz
	cp -rpf external/toolset/$OS_FLAVOUR/* /usr/local/bin
	cd openssl_source
	wget -q $OPENSSL_URL
	cd ../Linux
	make all
	make install

	cp -prf $SGX_INSTALL_DIR/sgxssl ${CENTRAL_REPO_DIR}
	popd
	rm -rf intel-sgx-ssl
}

install_ctk()
{
	pushd $PWD
	git clone $CTK_URL
	cd crypto-api-toolkit
	git checkout $CTK_BRANCH

	bash autogen.sh
	./configure --with-p11-kit-path=$P11_KIT_PATH --prefix=$CTK_INSTALL --enable-dcap || exit 1
	make install

	cp -prf $CTK_INSTALL ${CENTRAL_REPO_DIR}
	popd
	rm -rf crypto-api-toolkit
}

install_prerequisites()
{
	dnf install make wget tar gcc-c++ automake autoconf libtool yum-utils git openssl-devel cppunit-devel p11-kit-devel || exit 1
}
	
create_tar_bundle()
{
	cd ${CENTRAL_REPO_DIR}
	tar -cvf $(uname -r)_SKC_DCAP.tar ../$(echo $TAR_DIR/)
	if [ $? -eq 0 ]
	then
		echo "Created $(uname -r)_SKC_DCAP.tar in $(pwd)"
	fi
}

for arg in "$@"
do
	install_prerequisites
	create_central_repo
	case $arg in
		uninstall)
			uninstall_sgx
			;;
		driver)
			package_dcap_driver
			;;
		sgxsdk)
			install_sgxsdk
			;;
		sgxpsw)
			package_psw_rpms
			;;
		sgxssl)
			install_sgxssl
			;;
		ctk)
			install_ctk
			;;
		all)
			uninstall_sgx
			package_dcap_driver
			install_sgxsdk
			package_psw_rpms
			install_sgxssl
			install_ctk
	esac
	create_tar_bundle
done
