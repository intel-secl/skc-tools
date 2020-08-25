#!/bin/bash
SKCLIB_DIR=$PWD/skc_library
SKCLIB_BIN_DIR=$SKCLIB_DIR/bin
SKCLIB_URL="https://github.com/intel-secl/skc_library.git"
SKCLIB_BRANCH="v3.0/develop"
SKCLIB_CLONE_PATH=/tmp/skc_library
SKCLIB_BIN_NAME=skc_library_v1.0.bin
SKCLIB_VERSION=1.0

build_skc_library()
{
	pushd $PWD
	git clone $SKCLIB_URL $SKCLIB_CLONE_PATH 
	cd $SKCLIB_CLONE_PATH
	git checkout $SKCLIB_BRANCH

	scripts/build.sh
	if [ $? -ne 0 ]
	then
		echo "ERROR:Build of skc_library failed with $?"
		exit 1
	fi

	scripts/generate_bin.sh $SKCLIB_VERSION
	if [ $? -ne 0 ]
        then
                echo "ERROR:Genrating binary of skc_library failed with $?"
                exit 1
        fi
	
	mkdir -p $SKCLIB_BIN_DIR
	cp -pf $SKCLIB_CLONE_PATH/$SKCLIB_BIN_NAME $SKCLIB_BIN_DIR
	rm -rf $SKCLIB_CLONE_PATH
	popd
	cp -pf /usr/lib64/engines-1.1/pkcs11.so $SKCLIB_BIN_DIR
}

build_skc_library
