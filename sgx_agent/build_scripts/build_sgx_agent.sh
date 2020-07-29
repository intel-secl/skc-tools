#!/bin/bash

SGX_AGENT_DIR=$PWD/sgx_agent
SGX_AGENT_BIN_DIR=$SGX_AGENT_DIR/bin
SGX_AGENT_BRANCH="v14+next-major"
SGX_AGENT_URL="ssh://git@gitlab.devtools.intel.com:29418/sst/isecl/sgx_agent.git"
SGX_AGENT_CLONE_PATH=/tmp/sgx_agent

build_sgx_agent()
{
	pushd $PWD
	git clone $SGX_AGENT_URL $SGX_AGENT_CLONE_PATH 
	cd $SGX_AGENT_CLONE_PATH
	git checkout $SGX_AGENT_BRANCH
	make installer || exit 1
	mkdir -p $SGX_AGENT_BIN_DIR
	cp -pf out/sgx_agent-*.bin $SGX_AGENT_BIN_DIR
	cp -pf dist/linux/sgx_agent.env $SGX_AGENT_DIR
	rm -rf $SGX_AGENT_CLONE_PATH
	popd
}

build_sgx_agent
