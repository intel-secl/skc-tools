#!/bin/bash
SGX_DRIVER_VERSION=1.35
KDIR=/lib/modules/$(uname -r)/build
SGX_INSTALL_DIR=/opt/intel
SGX_AGENT_BIN_NAME=sgx_agent-v3.0.0.bin
MP_RPM_VER=1.7.90.2-1
SGX_AGENT_BIN=bin

cat $KDIR/.config | grep "CONFIG_INTEL_SGX=y" > /dev/null
INKERNEL_SGX=$?
/sbin/modinfo intel_sgx &> /dev/null
SGX_DRIVER_INSTALLED=$?

install_prerequisites()
{
        source deployment_prerequisites.sh
        if [[ $? -ne 0 ]]
        then
                echo "Exiting. Pre-install script failed"
                exit 1
        fi
}

install_psw_qgl()
{
	tar -xf $SGX_AGENT_BIN/sgx_rpm_local_repo.tgz 
	yum-config-manager --add-repo file://$PWD/sgx_rpm_local_repo
	yum-config-manager --save --setopt=tmp_sgx_sgx_rpm_local_repo.gpgcheck=0
	dnf install -y --nogpgcheck libsgx-dcap-ql || exit 1
	rm -rf sgx_rpm_local_repo /etc/yum.repos.d/*sgx_rpm_local_repo.repo
}
	
install_pckretrieval_tool()
{
	if [ ! -f /usr/sbin/rdmsr ]; then
		dnf localinstall -y https://dl.fedoraproject.org/pub/fedora/linux/releases/30/Everything/x86_64/os/Packages/m/msr-tools-1.3-11.fc30.x86_64.rpm
	else
		echo "rdmsr present. Continuing...."
	fi

	cp -pf $SGX_AGENT_BIN/libdcap_quoteprov.so.1 $SGX_AGENT_BIN/pck_retrieve_tool_enclave.signed.so /usr/sbin/
	cp -pf $SGX_AGENT_BIN/PCKIDRetrievalTool /usr/sbin/
}

install_dcap_driver()
{
	chmod u+x $SGX_AGENT_BIN/sgx_linux_x64_driver_${SGX_DRIVER_VERSION}.bin
	echo "$INKERNEL_SGX"
	echo "$SGX_DRIVER_INSTALLED"
	if [[ "$INKERNEL_SGX" -ne 0 && "$SGX_DRIVER_INSTALLED" -ne 0 ]]; then
		echo "SGX DCAP Driver is not present in your system."
		echo "Do you like to install it(Y/N):"
		read answer
		if [ "$answer" != "${answer#[Yy]}" ] ;then
			echo "Installing SGX DCAP Driver"
			sh $SGX_AGENT_BIN/sgx_linux_x64_driver_${SGX_DRIVER_VERSION}.bin -prefix=$SGX_INSTALL_DIR || exit 1
		else
			echo "Skipping installation of SGX DCAP DRIVER"
			return
		fi
	else
		echo "Found inbuilt sgx driver, skipping dcap driver installation"
	fi
}

install_multipackage_agent_rpm()
{
	rpm -ivh $SGX_AGENT_BIN/libsgx-ra-uefi-$MP_RPM_VER.el8.x86_64.rpm
}
		
install_sgx_agent() { 
	if [ ! -f ~/sgx_agent.env ]
	then
		cp -pf sgx_agent.env ~/sgx_agent.env
	fi

	source agent.conf
	CMS_URL=https://$CMS_IP:$CMS_PORT/cms/v1
	AAS_URL=https://$AAS_IP:$AAS_PORT/aas
	SHVS_URL=https://$SHVS_IP:$SHVS_PORT/sgx-hvs/v1
	sed -i "s@^\(CMS_BASE_URL\s*=\s*\).*\$@\1$CMS_URL@" ~/sgx_agent.env
	sed -i "s@^\(AAS_API_URL\s*=\s*\).*\$@\1$AAS_URL@" ~/sgx_agent.env
	sed -i "s@^\(SHVS_BASE_URL\s*=\s*\).*\$@\1$SHVS_URL@" ~/sgx_agent.env
	sed -i "s/^\(SAN_LIST\s*=\s*\).*\$/\1$SGX_AGENT_IP/" ~/sgx_agent.env
	sed -i "s/^\(CMS_TLS_CERT_SHA384\s*=\s*\).*\$/\1$CMS_TLS_SHA/" ~/sgx_agent.env
	
	./sgx_agent_create_roles.sh
	if [ $? -ne 0 ];then
		echo "Retrieve of Bearer token failed. Exiting"
		exit 1
	fi

	sgx_agent uninstall --purge
	$SGX_AGENT_BIN/$SGX_AGENT_BIN_NAME
}

install_prerequisites
install_dcap_driver
install_psw_qgl
install_multipackage_agent_rpm
install_pckretrieval_tool
install_sgx_agent
