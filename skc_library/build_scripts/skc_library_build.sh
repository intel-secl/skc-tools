#!/bin/bash
SKCLIB_DIR=skc_library
TAR_NAME=$(basename $SKCLIB_DIR)

install_prerequisites()
{
	source build_prerequisites.sh	
	if [ $? -ne 0 ]
	then
		"Pre-build step failed"
		exit 1
	fi
}

create_skc_library_tar()
{
	cp -pf ../deploy_scripts/*.sh $SKCLIB_DIR
	cp -pf ../deploy_scripts/skc_library.conf $SKCLIB_DIR
	cp -pf ../deploy_scripts/README.install $SKCLIB_DIR
	cp -pf ../deploy_scripts/openssl.cnf $SKCLIB_DIR
	cp -pf ../deploy_scripts/nginx.conf $SKCLIB_DIR
	tar -cf $TAR_NAME.tar -C $SKCLIB_DIR . --remove-files
	sha256sum $TAR_NAME.tar > $TAR_NAME.sha2
}

download_dcap_driver()
{
	source download_dcap_driver.sh
	if [ $? -ne 0 ]; then
		echo "sgx dcap driver download failed"
		exit 1
	fi
}

install_sgxsdk()
{
	source install_sgxsdk.sh
	if [ $? -ne 0 ]; then
		echo "sgx sdk installation failed"
		exit 1
	fi
}

install_sgxrpm()
{
	source install_sgxrpms.sh
	if [ $? -ne 0 ]; then
		echo "sgx psw/qgl rpm installation failed"
		exit 1
	fi
}
	
install_sgxssl()
{
	source install_sgxssl.sh
	if [ $? -ne 0 ]; then
		echo "sgxssl installtion failed"
		exit 1
        fi
}

install_ctk()
{
	source install_ctk.sh
	if [ $? -ne 0 ]; then
		echo "cryptoapitoolkit installation failed"
		exit 1
	fi
}

build_skc_library()
{
	source build_skclib.sh
	if [ $? -ne 0 ]; then
		echo "skc_library build failed"
		exit 1
	fi
}

rm -rf $SKCLIB_DIR
rm -f /etc/yum.repos.d/*sgx_rpm_local_repo.repo
install_prerequisites
download_dcap_driver
install_sgxsdk
install_sgxrpm
install_sgxssl
install_ctk
build_skc_library
create_skc_library_tar
