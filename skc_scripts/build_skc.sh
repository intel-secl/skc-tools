#!/bin/bash
SKC_DIR=~/skc
SKC_BINARY_DIR=$SKC_DIR/bin

mkdir -p $SKC_BINARY_DIR

# Copy the binaries to common directory
cp -pf ../../certificate-management-service/out/cms-*.bin $SKC_BINARY_DIR
cp -pf ../../authservice/out/authservice-*.bin $SKC_BINARY_DIR
cp -pf ../../sgx-caching-service/out/scs-*.bin $SKC_BINARY_DIR
cp -pf ../../sgx-verification-service/out/sqvs-*.bin $SKC_BINARY_DIR
cp -pf ../../sgx-hvs/out/shvs-*.bin $SKC_BINARY_DIR
cp -pf ../../sgx-ah/out/shub-*.bin $SKC_BINARY_DIR
cp -pf ../../key-broker-service/packages/kms/target/kms-*.bin $SKC_BINARY_DIR

# Copy env files to Home directory
HOME_DIR=~/
cp -pf ../../sgx-caching-service/dist/linux/scs.env $HOME_DIR
cp -pf ../../sgx-verification-service/dist/linux/sqvs.env $HOME_DIR
cp -pf ../../sgx-hvs/dist/linux/shvs.env $HOME_DIR
cp -pf ../../sgx-ah/dist/linux/shub.env $HOME_DIR

# Copy DB scripts to Home directory
cp -pf ../../sgx-caching-service/dist/linux/install_pgscsdb.sh $HOME_DIR
cp -pf ../../sgx-hvs/dist/linux/install_pgshvsdb.sh $HOME_DIR
cp -pf ../../sgx-ah/dist/linux/install_pgshubdb.sh $HOME_DIR
cp -pf env/cms.env $HOME_DIR
cp -pf env/authservice.env $HOME_DIR
cp -pf env/kms.env $HOME_DIR
cp -pf env/iseclpgdb.env $HOME_DIR
cp -pf env/install_pg.sh $HOME_DIR
cp -pf env/trusted_rootca.pem /tmp