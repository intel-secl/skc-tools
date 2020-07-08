#!/bin/bash

SGX_DRIVER_VERSION=1.22
SYSLIB_PATH=/usr/lib64
SGX_INSTALL_DIR=/opt/intel
SGX_TOOLKIT_INSTALL_PREFIX=$SGX_INSTALL_DIR/sgxtoolkit
GIT_CLONE_PATH=/tmp/sgxstuff
CENTRL_REPO=$PWD
bold=$(tput bold)
normal=$(tput sgr0)

uninstall_sgx()
{
	if [[ -d $SGX_INSTALL_DIR/sgxsdk ]]; then
		$SGX_INSTALL_DIR/sgxsdk/uninstall.sh
	fi

	modprobe -r intel_sgx
	dkms remove -m sgx -v $SGX_DRIVER_VERSION --all

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
	rm -rf /etc/yum.repos.d/*sgx_rpm_local_repo.repo
	rm -rf /usr/local/bin/ld /usr/local/bin/as /usr/local/bin/ld.gold /usr/local/bin/objdump /usr/local/bin/PCKIDRetrievalTool /usr/local/bin/enclave.signed.so /usr/local/libdcap_quoteprov.so.1
	#rm -rf $GIT_CLONE_PATH
}

install_sgxssl()
{
	mkdir -p  /opt/intel/sgxssl/include/
	mkdir -p /opt/intel/sgxssl/lib64/
	cp -prf $CENTRL_REPO/sgxssl/include/include/* /opt/intel/sgxssl/include/
	cp -prf $CENTRL_REPO/sgxssl/lib/lib64/* /opt/intel/sgxssl/lib64/
}

install_DCAP()
{
	mkdir -p /usr/src/sgx-$SGX_DRIVER_VERSION/
        cp -rpf $CENTRL_REPO/DCAP/* /usr/src/sgx-$SGX_DRIVER_VERSION/

        dkms add -m sgx -v $SGX_DRIVER_VERSION
        dkms build -m sgx -v $SGX_DRIVER_VERSION
        dkms install -m sgx -v $SGX_DRIVER_VERSION

        modprobe intel_sgx

        cp $CENTRL_REPO/DCAP/10-sgx.rules /etc/udev/rules.d
        groupadd sgx_prv
        usermod -a -G sgx_prv root
        udevadm trigger
}

install_SDK()
{
	pushd $CENTRL_REPO/SGX_SDK
        chmod +x *.bin
        # install SGX SDK
        ./sgx_linux_x64_sdk*.bin -prefix=$SGX_INSTALL_DIR || exit 1
        source $SGX_INSTALL_DIR/sgxsdk/environment

        tar -xzf sgx_rpm_local_repo.tgz
        yum-config-manager --add-repo file://$PWD/sgx_rpm_local_repo
        yum install -y --nogpgcheck libsgx-launch libsgx-uae-service libsgx-urts
	popd
}

install_QGL()
{
	cp -f $CENTRL_REPO/QGL/lib/*.so $SYSLIB_PATH
	cp -f $CENTRL_REPO/QGL/header_files/*.h $SGX_INSTALL_DIR/sgxsdk/include/
        ln -fs $SYSLIB_PATH/libsgx_dcap_ql.so $SYSLIB_PATH/libsgx_dcap_ql.so.1
        ln -sf $SYSLIB_PATH/libsgx_default_qcnl_wrapper.so $SYSLIB_PATH/libsgx_default_qcnl_wrapper.so.1
        ln -sf $SYSLIB_PATH/libdcap_quoteprov.so $SYSLIB_PATH/libdcap_quoteprov.so.1
	
	cp -p $CENTRL_REPO/QGL/conf/* /etc
	sed -i "s|PCCS_URL=.*|PCCS_URL=https://localhost:9000/scs/sgx/certification/v1/|g" /etc/sgx_default_qcnl.conf
        sed -i "s/USE_SECURE_CERT=.*/USE_SECURE_CERT=FALSE/g" /etc/sgx_default_qcnl.conf
}

install_sgxtoolkit()
{
	mkdir $SGX_TOOLKIT_INSTALL_PREFIX/
        cp -prf ${CENTRL_REPO}/sgxtoolkit/include $SGX_TOOLKIT_INSTALL_PREFIX/include/
        cp -prf ${CENTRL_REPO}/sgxtoolkit/lib $SGX_TOOLKIT_INSTALL_PREFIX/lib/

	mkdir $SGX_INSTALL_DIR/cryptoapitoolkit
	mkdir $SGX_INSTALL_DIR/cryptoapitoolkit/tokens
	chmod -R 1777 $SGX_INSTALL_DIR/cryptoapitoolkit/tokens

}

check_for_prerequisites()
{
	echo "CHECKING IF DEPENDENT PACKAGES ARE INSTALLED"
 	pkg_list='yum-utils dkms ocaml protobuf'
	deps_installed='y'
	for pkg in $pkg_list
	do
        	if rpm -q $pkg
        	then
                	echo "$pkg installed"
        	else
               		echo "${bold}$pkg NOT installed${normal}"
                	deps_installed='n'
        	fi
	done

	if [ $deps_installed = 'n' ]
	then
       		echo "${bold}Dependent packages are not installed. Please refer to install document"
        	echo "Exiting${normal}"
		exit 1
	fi
}

uninstall_sgx
check_for_prerequisites
echo "DCAP install started"
install_DCAP
echo "DCAP install completed"
echo "SDK install started"
install_SDK
echo "DCAP install completed"
echo "QGL install started"
install_QGL
echo "DCAP install completed"
echo "PCK install started"
install_PCK
echo "PCK install completed"
echo "SGXSSL INSTALL started"
install_sgxssl
echo "SGXSSL install completed"
echo "SGX toolkit install started"
install_sgxtoolkit
echo "SGX toolkit install completed"
