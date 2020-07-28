#!/bin/bash

#Install following packages before running this script: git, python3, makeself, golang
# for python create symlink as : ln -s /usr/bin/python3 /usr/bin/python
# for golang setup follow below steps:
  #  wget https://dl.google.com/go/go1.14.1.linux-amd64.tar.gz
  #  tar -xzf go1.14.1.linux-amd64.tar.gz
  #  sudo mv go /usr/local
  #  export GOROOT=/usr/local/go
  #  export PATH=$GOPATH/bin:$GOROOT/bin:$PATH
# create ssh key using following command : ssh-keygen
# copy the content of ~/.ssh/id_rsa.pub to the Gitlab (UserProfile->Settings->SSH Keys->Add Key)
# create ~/.gitconfig file and copy the following content in it:
#    [user]
#            email = <intel mail id>
#            name = <username>
#    [color]
#            ui = true
#    [url "ssh://git@gitlab.devtools.intel.com:29418/"]
#            insteadOf = https://gitlab.devtools.intel.com/
#    [core]
#            filemode = false
# Install Repo Tool
   # tmpdir=$(mktemp -d)
   # git clone https://gerrit.googlesource.com/git-repo $tmpdir
   # install -m 755 $tmpdir/repo /usr/local/bin
   # rm -rf $tmpdir

# Download SKC components
SKC_DIR=~/skc
SKC_BINARY_DIR=$SKC_DIR/bin
mkdir -p $SKC_BINARY_DIR
pushd $PWD
cd $SKC_DIR

repo init -u ssh://git@gitlab.devtools.intel.com:29418/sst/isecl/skc_manifest.git -b v13+next-major -m skc.xml
repo sync
# Build all the SKC components
make

# Copy the binaries to common directory
cp -pf certificate-management-service/out/cms-v2.2.0.bin $SKC_BINARY_DIR
cp -pf authservice/out/authservice-v2.2.0.bin $SKC_BINARY_DIR
cp -pf sgx-caching-service/out/scs-skc_M12.bin $SKC_BINARY_DIR
cp -pf sgx-verification-service/out/sqvs-skc_M12.bin $SKC_BINARY_DIR
cp -pf sgx-hvs/out/shvs-skc_M12.bin $SKC_BINARY_DIR
cp -pf sgx-ah/out/shub-skc_M12.bin $SKC_BINARY_DIR

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
cp -pf bin/kms-5.2-SNAPSHOT.bin $SKC_BINARY_DIR
