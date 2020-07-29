#!/bin/bash
SGX_AGENT_DIR=$PWD/sgx_agent
SGX_DCAP_TAG=DCAP_1.7
SGX_DCAP_REPO="https://github.com/intel/SGXDataCenterAttestationPrimitives.git"
GIT_CLONE_PATH=/tmp/dcap
SGX_AGENT_BIN_DIR=$SGX_AGENT_DIR/bin

build_PCKID_Retrieval_tool()
{
	pushd $PWD
	git clone $SGX_DCAP_REPO $GIT_CLONE_PATH
	cp -pf remove_pccs_connect.diff $GIT_CLONE_PATH/tools/PCKRetrievalTool
	cd $GIT_CLONE_PATH/
	git checkout $SGX_DCAP_TAG
	cd $GIT_CLONE_PATH/tools/PCKRetrievalTool
	git apply remove_pccs_connect.diff
	make
	mkdir -p $SGX_AGENT_BIN_DIR
	cp -pf libdcap_quoteprov.so.1 pck_retrieve_tool_enclave.signed.so PCKIDRetrievalTool $SGX_AGENT_BIN_DIR
	rm -rf $GIT_CLONE_PATH
	popd
}

build_PCKID_Retrieval_tool
