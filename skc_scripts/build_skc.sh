#!/bin/bash
SKC_DIR=~/skc
SKC_BINARY_DIR=$SKC_DIR/bin
GO_VERSION=go1.14.2

dnf install -y wget python3 gcc make
dnf localinstall -y https://rpmfind.net/linux/fedora/linux/releases/30/Everything/x86_64/os/Packages/m/makeself-2.4.0-3.fc30.noarch.rpm
ln -sf /usr/bin/python3 /usr/bin/python

go version > /dev/null 2>&1
if [ $? -ne 0 ]
then
	echo "golang not installed. installing now"
	wget -q --delete-after https://dl.google.com/go/$GO_VERSION.linux-amd64.tar.gz -O - | tar -xz || exit 1
	mv -f go /usr/local
	grep -q '/usr/local/go/bin' ~/.bash_profile || echo "export PATH=$PATH:/usr/local/go/bin" >> ~/.bash_profile
	[[ "$PATH" == *"/usr/local/go/bin"* ]] || PATH="${PATH}:/usr/local/go/bin"
fi

# Install Repo Tool
if [ ! -f /usr/local/bin/repo ]
then
	tmpdir=$(mktemp -d)
	git clone https://gerrit.googlesource.com/git-repo $tmpdir
	install -m 755 $tmpdir/repo /usr/local/bin
	rm -rf $tmpdir
fi

mkdir -p $SKC_BINARY_DIR
pushd $PWD
cd $SKC_DIR

repo init -u ssh://git@gitlab.devtools.intel.com:29418/sst/isecl/skc_manifest.git -b v14+next-major -m skc.xml
repo sync
# Build all the SKC components
make || exit 1

# Copy the binaries to common directory
cp -pf certificate-management-service/out/cms-*.bin $SKC_BINARY_DIR
cp -pf authservice/out/authservice-*.bin $SKC_BINARY_DIR
cp -pf sgx-caching-service/out/scs-*.bin $SKC_BINARY_DIR
cp -pf sgx-verification-service/out/sqvs-*.bin $SKC_BINARY_DIR
cp -pf sgx-hvs/out/shvs-*.bin $SKC_BINARY_DIR
cp -pf sgx-ah/out/shub-*.bin $SKC_BINARY_DIR

# Copy env files to Home directory
HOME_DIR=~/
cp -pf sgx-caching-service/dist/linux/scs.env $HOME_DIR
cp -pf sgx-verification-service/dist/linux/sqvs.env $HOME_DIR
cp -pf sgx-hvs/dist/linux/shvs.env $HOME_DIR
cp -pf sgx-ah/dist/linux/shub.env $HOME_DIR

# Copy DB scripts to Home directory
cp -pf sgx-caching-service/dist/linux/install_pgscsdb.sh $HOME_DIR
cp -pf sgx-hvs/dist/linux/install_pgshvsdb.sh $HOME_DIR
cp -pf sgx-ah/dist/linux/install_pgshubdb.sh $HOME_DIR
popd
cp -pf env/cms.env $HOME_DIR
cp -pf env/authservice.env $HOME_DIR
cp -pf env/kms.env $HOME_DIR
cp -pf env/iseclpgdb.env $HOME_DIR
cp -pf env/install_pg.sh $HOME_DIR
cp -pf env/trusted_rootca.pem /tmp
cp -pf bin/kms-*.bin $SKC_BINARY_DIR
