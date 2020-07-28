#!/bin/bash
DCAP_VERSION=1.7
SGX_DCAP_TAG=DCAP_1.7
OS_FLAVOUR="rhel8.1-server"
MULTIPACKAGE_AGENT_RPM="https://download.01.org/intel-sgx/sgx-dcap/$DCAP_VERSION/linux/tools/SGXMultiPackageAgent/$OS_FLAVOUR"
SGX_DCAP_REPO="https://github.com/intel/SGXDataCenterAttestationPrimitives.git"
GIT_CLONE_PATH=/tmp/dataCenterAttestationPrimitives
MP_RPM_VER=1.7.90.2-1

install_sgx_components()
{
	#install msr-tools
	if [ ! -f /usr/sbin/rdmsr ]; then
		yum localinstall -y http://rpmfind.net/linux/fedora/linux/releases/30/Everything/x86_64/os/Packages/m/msr-tools-1.3-11.fc30.x86_64.rpm
	fi
	rm -rf $GIT_CLONE_PATH

	# remove_pccs_connect.diff disables access to PCCS
	echo "Please provide patch file path"
	read path
	if [ ! -f $path/remove_pccs_connect.diff ]; then
		echo "file not found on the given path"
		exit 1
	fi

	# install uefi rpm to extract manifest file
	rpm -ivh $MULTIPACKAGE_AGENT_RPM/libsgx-ra-uefi-$MP_RPM_VER.el8.x86_64.rpm

	# build and  install PCKidretrieval tool
	git clone $SGX_DCAP_REPO $GIT_CLONE_PATH/
	cd $GIT_CLONE_PATH/
	git checkout $SGX_DCAP_TAG
	cp $path/remove_pccs_connect.diff $GIT_CLONE_PATH/
	cd $GIT_CLONE_PATH/tools/PCKRetrievalTool
	git apply $path/remove_pccs_connect.diff
	make
	cp -u libdcap_quoteprov.so.1 pck_retrieve_tool_enclave.signed.so PCKIDRetrievalTool /usr/local/bin
}

install_sgx_components
