#!/bin/bash

SGX_DRIVER_VERSION=1.22
SGX_STACK_VERSION=2.9
SGX_DCAP_TAG=DCAP_1.5
SGX_URL="https://download.01.org/intel-sgx/sgx-linux/${SGX_STACK_VERSION}/distro/rhel8.0-server"
SYSLIB_PATH=/usr/lib64
SGX_DCAP_REPO="https://github.com/intel/SGXDataCenterAttestationPrimitives.git"
SGX_TOOLKIT_URL="ssh://git@gitlab.devtools.intel.com:29418/sst/isecl/crypto-api-toolkit.git"
SGX_TOOLKIT_BRANCH="v10+next-major"
OPENSSL_DOWNLOAD_URL="https://www.openssl.org/source/old/1.1.1/openssl-1.1.1d.tar.gz"
SGXSSL_CVE_URL="https://download.01.org/intel-sgx/sgx-linux/2.9/as.ld.objdump.gold.r1.tar.gz"
SGX_INSTALL_DIR=/opt/intel
SGX_TOOLKIT_INSTALL_PREFIX=$SGX_INSTALL_DIR/sgxtoolkit
P11_KIT_PATH=/usr/include/p11-kit-1/p11-kit/
GIT_CLONE_PATH=/tmp/sgxstuff
CENTRAL_REPO_DIR=~/central_repo
TAR_DIR=central_repo

uninstall_sgx()
{
	if [[ -d $SGX_INSTALL_DIR/sgxsdk ]]; then
		$SGX_INSTALL_DIR/sgxsdk/uninstall.sh
	fi

	if [ -d /usr/src/sgx-$SGX_DRIVER_VERSION ]; then
		rm -rf /usr/src/sgx-$SGX_DRIVER_VERSION/
	fi

	if [[ -d $SGX_INSTALL_DIR/sgxssl ]]; then
		echo "Uninstalling SGX SSL"
		rm -rf $SGX_INSTALL_DIR/sgxssl
	fi

	if [[ -d $SGX_TOOLKIT_INSTALL_PREFIX ]]; then
		echo "Uninstalling SGX Toolkit"
		rm -rf $SGX_TOOLKIT_INSTALL_PREFIX
		rm -rf $SGX_INSTALL_DIR/cryptoapitoolkit/
	fi

	rpm -qa | grep 'sgx' | xargs rpm -e
	find $SYSLIB_PATH -name 'libsgx*' -exec rm -f {} \;
	find $SYSLIB_PATH -name 'libdcap*' -exec rm -f {} \;
	find $SYSLIB_PATH -name 'libquote*' -exec rm -f {} \;
	rm -rf /etc/yum.repos.d/*_sgx_rpm_local_repo.repo
	rm -rf /usr/local/bin/ld /usr/local/bin/as /usr/local/bin/ld.gold /usr/local/bin/objdump 
	rm -rf $GIT_CLONE_PATH
}

create_central_repo() {
	
        if [ -d "$CENTRAL_REPO_DIR" ]; then
		mkdir -p ${CENTRAL_REPO_DIR}_old/
                mv -f $CENTRAL_REPO_DIR ${CENTRAL_REPO_DIR}_old/${TAR_DIR}_$(date +"%Y%m%d%H%M")
                mkdir $CENTRAL_REPO_DIR
		echo "NOTE:OLD CENTRAL REPO IS MOVED TO ${CENTRAL_REPO_DIR}_old/${TAR_DIR}_$(date +"%Y%m%d%H%M")"
        else
                mkdir $CENTRAL_REPO_DIR
        fi

	sed -i 's/^OS_VERSION=.*$/OS_VERSION='"$(uname -r)"'/g' deploy_sgx_artifacts.sh
	cp deploy_sgx_artifacts.sh $CENTRAL_REPO_DIR/
}

	

build_DCAP()  {
	pushd $PWD
        mkdir -p $GIT_CLONE_PATH
        pushd $GIT_CLONE_PATH
        git clone $SGX_DCAP_REPO $GIT_CLONE_PATH/
        git checkout $SGX_DCAP_TAG
        pushd driver/linux

	mkdir ${CENTRAL_REPO_DIR}/DCAP
	
	cp -rpf * ${CENTRAL_REPO_DIR}/DCAP/
	cp 10-sgx.rules ${CENTRAL_REPO_DIR}/DCAP/
	popd
}

install_SGX_SDK() {
	wget -nd -nv -rNc -e robots=off -l1 --no-parent --reject "index.html*" -A "*.bin" $SGX_URL
	mkdir ${CENTRAL_REPO_DIR}/SGX_SDK
	cp -rpf *.bin ${CENTRAL_REPO_DIR}/SGX_SDK/
        chmod +x *.bin
        # install SGX SDK
        ./sgx_linux_x64_sdk*.bin -prefix=$SGX_INSTALL_DIR || exit 1
        source $SGX_INSTALL_DIR/sgxsdk/environment
 
        wget -nv $SGX_URL/sgx_rpm_local_repo.tgz
	cp -rpf sgx_rpm_local_repo.tgz ${CENTRAL_REPO_DIR}/SGX_SDK/
}

build_QGL() {
	install_SGX_SDK
	pushd $GIT_CLONE_PATH/QuoteGeneration
        # Downlad and install the Intel signed architecture enclaves (QE, PCE)
        ./download_prebuilt.sh

        # Build the Quote Generation and Quote Provider Libraries
        make quote_wrapper qpl_wrapper || exit 1

	cp build/linux/*.so $SYSLIB_PATH
        cp -p psw/ae/data/prebuilt/libsgx_qe3.signed.so psw/ae/data/prebuilt/libsgx_pce.signed.so $SYSLIB_PATH
        cp -p quote_wrapper/common/inc/sgx_quote_3.h pce_wrapper/inc/sgx_pce.h quote_wrapper/ql/inc/sgx_dcap_ql_wrapper.h quote_wrapper/common/inc/sgx_ql_lib_common.h ../QuoteVerification/QVL/Src/AttestationLibrary/include/SgxEcdsaAttestation/QuoteVerification.h $SGX_INSTALL_DIR/sgxsdk/include/
        ln -fs $SYSLIB_PATH/libsgx_dcap_ql.so $SYSLIB_PATH/libsgx_dcap_ql.so.1
        ln -sf $SYSLIB_PATH/libsgx_default_qcnl_wrapper.so $SYSLIB_PATH/libsgx_default_qcnl_wrapper.so.1
        ln -sf $SYSLIB_PATH/libdcap_quoteprov.so $SYSLIB_PATH/libdcap_quoteprov.so.1

        cp -p qcnl/linux/sgx_default_qcnl.conf /etc
        sed -i "s|PCCS_URL=.*|PCCS_URL=https://localhost:9000/scs/sgx/certification/v1/|g" /etc/sgx_default_qcnl.conf
        sed -i "s/USE_SECURE_CERT=.*/USE_SECURE_CERT=FALSE/g" /etc/sgx_default_qcnl.conf

	
	mkdir ${CENTRAL_REPO_DIR}/QGL
	mkdir ${CENTRAL_REPO_DIR}/QGL/lib 
	mkdir ${CENTRAL_REPO_DIR}/QGL/header_files

	cp build/linux/*.so ${CENTRAL_REPO_DIR}/QGL/lib
	cp -p psw/ae/data/prebuilt/libsgx_qe3.signed.so psw/ae/data/prebuilt/libsgx_pce.signed.so ${CENTRAL_REPO_DIR}/QGL/lib/
	cp -p quote_wrapper/common/inc/sgx_quote_3.h pce_wrapper/inc/sgx_pce.h quote_wrapper/ql/inc/sgx_dcap_ql_wrapper.h quote_wrapper/common/inc/sgx_ql_lib_common.h ../QuoteVerification/QVL/Src/AttestationLibrary/include/SgxEcdsaAttestation/QuoteVerification.h ${CENTRAL_REPO_DIR}/QGL/header_files

	mkdir ${CENTRAL_REPO_DIR}/QGL/conf
	cp -p qcnl/linux/sgx_default_qcnl.conf ${CENTRAL_REPO_DIR}/QGL/conf

	popd
}

build_sgx_SSL() {
	mkdir ${CENTRAL_REPO_DIR}/sgxssl
	mkdir ${CENTRAL_REPO_DIR}/sgxssl/lib
	mkdir ${CENTRAL_REPO_DIR}/sgxssl/include
	
	mkdir -p $GIT_CLONE_PATH
        pushd $GIT_CLONE_PATH
        git clone https://github.com/intel/intel-sgx-ssl.git $GIT_CLONE_PATH/sgxssl
        cd $GIT_CLONE_PATH/sgxssl
        wget -nv $SGXSSL_CVE_URL
        tar -xzf as.ld.objdump.gold.r1.tar.gz
        cp -rpf external/toolset/* /usr/local/bin
        cd openssl_source
        wget -nv $OPENSSL_DOWNLOAD_URL || exit 1
        cd ../Linux
        make all || exit 1
	make install || exit 1

	cp -prf $GIT_CLONE_PATH/sgxssl/Linux/package/include ${CENTRAL_REPO_DIR}/sgxssl/include
	cp -prf $GIT_CLONE_PATH/sgxssl/Linux/package/lib64 ${CENTRAL_REPO_DIR}/sgxssl/lib
	cd $GIT_CLONE_PATH
}

build_sgxtoolkit()
{
        rm -rf $GIT_CLONE_PATH/crypto-api-toolkit-v2
        git clone $SGX_TOOLKIT_URL $GIT_CLONE_PATH/crypto-api-toolkit-v2
        cp scripts/sgx_measurement.diff $GIT_CLONE_PATH/crypto-api-toolkit-v2
        pushd $GIT_CLONE_PATH/crypto-api-toolkit-v2
        git checkout $SGX_TOOLKIT_BRANCH
        git apply sgx_measurement.diff

        bash autogen.sh
        #./configure --enable-p11-kit --prefix=$SGX_TOOLKIT_INSTALL_PREFIX --enable-dcap || exit 1
	./configure --with-p11-kit-path=$P11_KIT_PATH --prefix=$SGX_TOOLKIT_INSTALL_PREFIX --enable-dcap || exit 1
        make
	make install || exit 1

	mkdir ${CENTRAL_REPO_DIR}/sgxtoolkit
	mkdir ${CENTRAL_REPO_DIR}/sgxtoolkit/include
	mkdir ${CENTRAL_REPO_DIR}/sgxtoolkit/lib

	cp -prf $SGX_TOOLKIT_INSTALL_PREFIX/include/* ${CENTRAL_REPO_DIR}/sgxtoolkit/include
	cp -prf $SGX_TOOLKIT_INSTALL_PREFIX/lib/* ${CENTRAL_REPO_DIR}/sgxtoolkit/lib

        popd
}


install_prerequisites()
{
        yum update -y
        yum groupinstall -y "Development Tools"
        # RHEL 8 does not provide epel repo out of the box yet.
        yum localinstall -y https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/e/epel-release-8-8.el8.noarch.rpm
        yum install -y yum-utils python3 dkms elfutils-libelf-devel wget libcurl-devel ocaml protobuf cppunit-devel p11-kit-devel || exit 1

}
	
create_tar_bundle() {
        cd ${CENTRAL_REPO_DIR}
        tar -cvf $(uname -r)_SKC_DCAP.tar ../$(echo $TAR_DIR/)
        if [ $? -eq 0 ]
        then
                echo "Created $(uname -r)_SKC_DCAP.tar in $(pwd)"
        fi
}


uninstall_sgx
install_prerequisites
create_central_repo
build_DCAP 
build_QGL
build_PCKID
build_sgx_SSL 
build_sgxtoolkit
create_tar_bundle 
