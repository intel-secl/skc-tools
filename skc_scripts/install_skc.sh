#!/bin/bash
SKC_DIR=~/skc
SKC_BINARY_DIR=$SKC_DIR/bin

# read from environment variables file if it exists
if [ -f ./skc.conf ]; then
    echo "Reading Installation variables from $(pwd)/skc.conf"
    source skc.conf
    env_file_exports=$(cat ./skc.conf | grep -E '^[A-Z0-9_]+\s*=' | cut -d = -f 1)
    if [ -n "$env_file_exports" ]; then eval export $env_file_exports; fi
fi

############## Install pre-req
which jq &> /dev/null 
if [ $? -ne 0 ]; then
  yum install -y jq
fi

echo "################ Uninstalling CMS....  #################"
cms uninstall --purge
echo "################ Uninstalling AAS....  #################"
authservice uninstall --purge
echo "################ Remove AAS DB....  #################"
pushd $PWD
cd /usr/local/pgsql
sudo -u postgres dropdb aas_db
echo "################ Uninstalling SCS....  #################"
scs uninstall --purge
echo "################ Remove SCS DB....  #################"
sudo -u postgres dropdb pgscsdb
echo "################ Uninstalling SQVS....  #################"
sqvs uninstall --purge
echo "################ Uninstalling SHVS....  #################"
shvs uninstall --purge
echo "################ Remove SHVS DB....  #################"
sudo -u postgres dropdb pgshvsdb
echo "################ Uninstalling SHUB....  #################"
shub uninstall --purge
echo "################ Remove SHUB DB....  #################"
sudo -u postgres dropdb pgshubdb
echo "################ Uninstalling KMS....  #################"
kms uninstall --purge
popd

export PGPASSWORD=dbpassword
function is_database() {
    psql -U dbuser -lqt | cut -d \| -f 1 | grep -wq $1
}

export DBNAME=aas_db
if is_database $DBNAME
then 
   echo $DBNAME database exists
else
   echo "################ Update iseclpgdb.env for AAS....  #################"
   sed -i "s/^\(ISECL_PGDB_DBNAME\s*=\s*\).*\$/\1$DBNAME/" ~/iseclpgdb.env
   pushd $PWD
   cd ~
   bash install_pg.sh
fi

export DBNAME=pgscsdb
if is_database $DBNAME
then
   echo $DBNAME database exists
else
   echo "################ Update iseclpgdb.env for SCS....  #################"
   sed -i "s/^\(ISECL_PGDB_DBNAME\s*=\s*\).*\$/\1$DBNAME/" ~/iseclpgdb.env
   bash install_pgscsdb.sh
fi

export DBNAME=pgshvsdb
if is_database $DBNAME
then
   echo $DBNAME database exists
else
   echo "################ Update iseclpgdb.env for SHVS....  #################"
   sed -i "s/^\(ISECL_PGDB_DBNAME\s*=\s*\).*\$/\1$DBNAME/" ~/iseclpgdb.env
   bash install_pgshvsdb.sh
fi

export DBNAME=pgshubdb
if is_database $DBNAME
then
   echo $DBNAME database exists
else
   echo "################ Update iseclpgdb.env for SHUB....  #################"
   sed -i "s/^\(ISECL_PGDB_DBNAME\s*=\s*\).*\$/\1$DBNAME/" ~/iseclpgdb.env
   bash install_pgshubdb.sh
fi
popd

pushd $PWD
cd $SKC_BINARY_DIR
echo "################ Installing CMS....  #################"
AAS_URL=https://$AAS_IP:8444/aas/
sed -i "s/^\(AAS_TLS_SAN\s*=\s*\).*\$/\1$AAS_IP/" ~/cms.env
sed -i "s@^\(AAS_API_URL\s*=\s*\).*\$@\1$AAS_URL@" ~/cms.env
sed -i "s/^\(SAN_LIST\s*=\s*\).*\$/\1$CMS_IP/" ~/cms.env

./cms-*.bin || exit 1
if [ $? -ne 0 ]; then
  echo "############ CMS Installation Failed"
  exit 1
fi
echo "################ Installed CMS....  #################"

echo "################ Installing AuthService....  #################"

echo "################ Copy CMS token to AuthService....  #################"
export AAS_TLS_SAN=$AAS_IP
CMS_TOKEN=`cms setup cms_auth_token --force | grep 'JWT Token:' | awk '{print $3}'`
sed -i "s/^\(BEARER_TOKEN\s*=\s*\).*\$/\1$CMS_TOKEN/"  ~/authservice.env

CMS_TLS_SHA=`cat /etc/cms/config.yml | grep tlscertdigest |  cut -d' ' -f2`
sed -i "s/^\(CMS_TLS_CERT_SHA384\s*=\s*\).*\$/\1$CMS_TLS_SHA/"  ~/authservice.env

CMS_URL=https://$CMS_IP:8445/cms/v1/
sed -i "s@^\(CMS_BASE_URL\s*=\s*\).*\$@\1$CMS_URL@"  ~/authservice.env

sed -i "s/^\(SAN_LIST\s*=\s*\).*\$/\1$AAS_IP/"  ~/authservice.env

./authservice-*.bin || exit 1
if [ $? -ne 0 ]; then
  echo "############ AuthService Installation Failed"
  exit 1
fi
echo "################ Installed AuthService....  #################"

echo "################ Create user and role on AuthService....  #################"
TOKEN=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/token -d '{"username": "admin", "password": "password" }'`

if [ $? -ne 0 ]; then
  echo "############ Could not get TOKEN from AuthService "
  exit 1
fi

USER_ID=`curl --noproxy "*" -k https://$AAS_IP:8444/aas/users?name=admin -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' | jq -r '.[0].user_id'`
echo "Got admin user ID $USER_ID"

# SGX Caching Service User and Roles

SCS_USER=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/users -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"username": "scsuser@scs","password": "scspassword"}'`
SCS_USER_ID=`curl --noproxy "*" -k https://$AAS_IP:8444/aas/users?name=scsuser@scs -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' | jq -r '.[0].user_id'`
echo "Created SCS User with user ID $SCS_USER_ID"
SCS_ROLE_ID1=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"service": "CMS","name": "CertApprover","context": "CN=SCS TLS Certificate;SAN='$SCS_IP';certType=TLS"}' | jq -r ".role_id"`
echo "Created SCS TLS cert role with ID $SCS_ROLE_ID1"
SCS_ROLE_ID2=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"service": "SCS","name": "CacheManager","context": ""}' | jq -r ".role_id"`
echo "Created SCS CacheManager role with ID $SCS_ROLE_ID2"

if [ $? -eq 0 ]; then
  curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/users/$SCS_USER_ID/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"role_ids": ["'"$SCS_ROLE_ID1"'", "'"$SCS_ROLE_ID2"'"]}'
fi

SCS_TOKEN=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/token -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"username": "scsuser@scs","password": "scspassword"}'`
echo "SCS Token $SCS_TOKEN"

# SGX Quote Verification Service User and Roles

SQVS_USER=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/users -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"username": "sqvsuser@sqvs","password": "sqvspassword"}'`
SQVS_USER_ID=`curl --noproxy "*" -k https://$AAS_IP:8444/aas/users?name=sqvsuser@sqvs -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' | jq -r '.[0].user_id'`
echo "Created SQVS User with user ID $SQVS_USER_ID"
SQVS_ROLE_ID1=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"service": "CMS","name": "CertApprover","context": "CN=SQVS TLS Certificate;SAN='$SQVS_IP';certType=TLS"}' | jq -r ".role_id"`
echo "Created SQVS TLS cert role with ID $SQVS_ROLE_ID1"

if [ $? -eq 0 ]; then
  curl --noproxy "*" -k  -X POST https://$AAS_IP:8444/aas/users/$SQVS_USER_ID/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"role_ids": ["'"$SQVS_ROLE_ID1"'"]}'
fi

SQVS_TOKEN=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/token -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"username": "sqvsuser@sqvs","password": "sqvspassword"}'`
echo "SQVS Token $SQVS_TOKEN"

# SGX Host Verification Service User and Roles

SHVS_USER=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/users -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"username": "shvsuser@shvs","password": "shvspassword"}'`
SHVS_USER_ID=`curl --noproxy "*" -k https://$AAS_IP:8444/aas/users?name=shvsuser@shvs -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' | jq -r '.[0].user_id'`
echo "Created SHVS User with user ID $SHVS_USER_ID"
SHVS_ROLE_ID1=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"service": "CMS","name": "CertApprover","context": "CN=SHVS TLS Certificate;SAN='$SHVS_IP';certType=TLS"}' | jq -r ".role_id"`
echo "Created SHVS TLS cert role with ID $SHVS_ROLE_ID1"
SHVS_ROLE_ID2=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"service": "SGX_AGENT","name": "HostDataReader","context": ""}' | jq -r ".role_id"`
echo "Created SHVS HostDataReader role with ID $SHVS_ROLE_ID2"
SHVS_ROLE_ID3=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"service": "SCS","name": "HostDataUpdater","context": ""}' | jq -r ".role_id"`
echo "Created SHVS HostDataUpdater role with ID $SHVS_ROLE_ID3"
SHVS_ROLE_ID4=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"service": "SCS","name": "HostDataReader","context": ""}' | jq -r ".role_id"`
echo "Created SHVS HostDataReader role with ID $SHVS_ROLE_ID4"
SHVS_ROLE_ID5=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"service": "SHVS","name": "HostListManager","context": ""}' | jq -r ".role_id"`
echo "Created SHVS HostListManager role with ID $SHVS_ROLE_ID5"

if [ $? -eq 0 ]; then
  curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/users/$SHVS_USER_ID/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"role_ids": ["'"$SHVS_ROLE_ID1"'", "'"$SHVS_ROLE_ID2"'", "'"$SHVS_ROLE_ID3"'", "'"$SHVS_ROLE_ID4"'", "'"$SHVS_ROLE_ID5"'"]}'
fi

SHVS_TOKEN=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/token -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"username": "shvsuser@shvs","password": "shvspassword"}'`
echo "SHVS Token $SHVS_TOKEN"

# SGX HUB User and Roles

SHUB_USER=`curl --noproxy "*" -k  -X POST https://$AAS_IP:8444/aas/users -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"username": "shubuser@shub","password": "shubpassword"}'`
SHUB_USER_ID=`curl --noproxy "*" -k https://$AAS_IP:8444/aas/users?name=shubuser@shub -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' | jq -r '.[0].user_id'`
echo "Created SHUB User with user ID $SHUB_USER_ID"
SHUB_ROLE_ID1=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"service": "CMS","name": "CertApprover","context": "CN=SHUB TLS Certificate;SAN='$SHUB_IP';certType=TLS"}' | jq -r ".role_id"`
echo "Created SHUB TLS cert role with ID $SHUB_ROLE_ID1"
SHUB_ROLE_ID2=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"service": "SHVS","name": "HostDataReader","context": ""}' | jq -r ".role_id"`
echo "Created SHUB HostDataReader role with ID $SHUB_ROLE_ID2"
SHUB_ROLE_ID3=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"service": "SHVS","name": "HostsListReader","context": ""}' | jq -r ".role_id"`
echo "Created SHUB HostsListReader role with ID $SHUB_ROLE_ID3"
SHUB_ROLE_ID4=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"service": "SHUB","name": "TenantManager","context": ""}' | jq -r ".role_id"`
echo "Created SHUB TenantManager role with ID $SHUB_ROLE_ID4"

if [ $? -eq 0 ]; then
  curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/users/$SHUB_USER_ID/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"role_ids": ["'"$SHUB_ROLE_ID1"'", "'"$SHUB_ROLE_ID2"'", "'"$SHUB_ROLE_ID3"'", "'"$SHUB_ROLE_ID4"'"]}'
fi

SHUB_TOKEN=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/token -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"username": "shubuser@shub","password": "shubpassword"}'`
echo "SHUB Token $SHUB_TOKEN"

# KMS User and Roles

KMS_USER=`curl --noproxy "*" -k  -X POST https://$AAS_IP:8444/aas/users -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"username": "kmsuser@kms","password": "kmspassword"}'`
KMS_USER_ID=`curl --noproxy "*" -k https://$AAS_IP:8444/aas/users?name=kmsuser@kms -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' | jq -r '.[0].user_id'`
echo "Created KMS User with user ID $KMS_USER_ID"
KMS_ROLE_ID1=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"service": "CMS","name": "CertApprover","context": "CN=KMS TLS Certificate;SAN='$KMS_IP',kbshostname;certType=TLS"}' | jq -r ".role_id"`
echo "Created KMS TLS cert role with ID $KMS_ROLE_ID1"
KMS_ROLE_ID2=`curl --noproxy "*" -k -X GET https://$AAS_IP:8444/aas/roles?name=Administrator -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' | jq -r '.[0].role_id'`
echo "Retrieved KMS Administrator role with ID $KMS_ROLE_ID2"
KMS_ROLE_ID3=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"service": "SQVS","name": "QuoteVerifier","context": ""}' | jq -r ".role_id"`

if [ $? -eq 0 ]; then
  curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/users/$KMS_USER_ID/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"role_ids": ["'"$KMS_ROLE_ID1"'", "'"$KMS_ROLE_ID2"'", "'"$KMS_ROLE_ID3"'"]}'
fi

KMS_TOKEN=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/token -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"username": "kmsuser@kms","password": "kmspassword"}'`
echo "KMS Token $KMS_TOKEN"

echo "################ Update SCS env....  #################"
sed -i "s/^\(SAN_LIST\s*=\s*\).*\$/\1$SCS_IP/"  ~/scs.env
sed -i "s/^\(BEARER_TOKEN\s*=\s*\).*\$/\1$SCS_TOKEN/"  ~/scs.env
sed -i "s/^\(CMS_TLS_CERT_SHA384\s*=\s*\).*\$/\1$CMS_TLS_SHA/" ~/scs.env
sed -i "s@^\(AAS_API_URL\s*=\s*\).*\$@\1$AAS_URL@" ~/scs.env
sed -i "s@^\(CMS_BASE_URL\s*=\s*\).*\$@\1$CMS_URL@" ~/scs.env

echo "################ Installing SCS....  #################"
./scs-*.bin || exit 1
if [ $? -ne 0 ]; then
  echo "############ SCS Installation Failed"
  exit 1
fi
echo "################ Installed SCS....  #################"

echo "################ Update SQVS env....  #################"
sed -i "s/^\(SAN_LIST\s*=\s*\).*\$/\1$SQVS_IP/"  ~/sqvs.env
sed -i "s/^\(BEARER_TOKEN\s*=\s*\).*\$/\1$SQVS_TOKEN/"  ~/sqvs.env
sed -i "s/^\(CMS_TLS_CERT_SHA384\s*=\s*\).*\$/\1$CMS_TLS_SHA/" ~/sqvs.env
sed -i "s@^\(AAS_API_URL\s*=\s*\).*\$@\1$AAS_URL@" ~/sqvs.env
sed -i "s@^\(CMS_BASE_URL\s*=\s*\).*\$@\1$CMS_URL@" ~/sqvs.env
SCS_URL=https://$SCS_IP:9000/scs/sgx/certification/v1
sed -i "s@^\(SCS_BASE_URL\s*=\s*\).*\$@\1$SCS_URL@" ~/sqvs.env

echo "################ Installing SQVS....  #################"
./sqvs-*.bin || exit 1
if [ $? -ne 0 ]; then
  echo "############ SQVS Installation Failed"
  exit 1
fi
echo "################ Installed SQVS....  #################"

echo "################ Update SHVS env....  #################"
sed -i "s/^\(SAN_LIST\s*=\s*\).*\$/\1$SHVS_IP/" ~/shvs.env
sed -i "s/^\(BEARER_TOKEN\s*=\s*\).*\$/\1$SHVS_TOKEN/" ~/shvs.env
sed -i "s/^\(CMS_TLS_CERT_SHA384\s*=\s*\).*\$/\1$CMS_TLS_SHA/" ~/shvs.env
sed -i "s@^\(AAS_API_URL\s*=\s*\).*\$@\1$AAS_URL@" ~/shvs.env
sed -i "s@^\(CMS_BASE_URL\s*=\s*\).*\$@\1$CMS_URL@" ~/shvs.env
SCS_URL=https://$SCS_IP:9000/scs/sgx/
sed -i "s@^\(SCS_BASE_URL\s*=\s*\).*\$@\1$SCS_URL@" ~/shvs.env

echo "################ Installing SHVS....  #################"
./shvs-*.bin || exit 1
if [ $? -ne 0 ]; then
  echo "############ SHVS Installation Failed"
  exit 1
fi
echo "################ Installed SHVS....  #################"

echo "################ Update SHUB env....  #################"
sed -i "s/^\(SAN_LIST\s*=\s*\).*\$/\1$SHUB_IP/" ~/shub.env
sed -i "s/^\(BEARER_TOKEN\s*=\s*\).*\$/\1$SHUB_TOKEN/" ~/shub.env
sed -i "s/^\(CMS_TLS_CERT_SHA384\s*=\s*\).*\$/\1$CMS_TLS_SHA/" ~/shub.env
sed -i "s@^\(AAS_API_URL\s*=\s*\).*\$@\1$AAS_URL@" ~/shub.env
sed -i "s@^\(CMS_BASE_URL\s*=\s*\).*\$@\1$CMS_URL@" ~/shub.env
SHVS_URL=https://$SHVS_IP:13000/sgx-hvs/v1/
sed -i "s@^\(SHVS_BASE_URL\s*=\s*\).*\$@\1$SHVS_URL@" ~/shub.env

echo "################ Installing SHUB....  #################"
./shub-*.bin || exit 1
if [ $? -ne 0 ]; then
  echo "############ SHUB Installation Failed"
  exit 1
fi
echo "################ Installed SHUB....  #################"

echo "################ Update KMS env....  #################"
sed -i "s/^\(JETTY_TLS_CERT_IP\s*=\s*\).*\$/\1$KMS_IP/" ~/kms.env
sed -i "s/^\(BEARER_TOKEN\s*=\s*\).*\$/\1$KMS_TOKEN/" ~/kms.env
sed -i "s/^\(CMS_TLS_CERT_SHA384\s*=\s*\).*\$/\1$CMS_TLS_SHA/" ~/kms.env
sed -i "s@^\(AAS_API_URL\s*=\s*\).*\$@\1$AAS_URL@" ~/kms.env
sed -i "s@^\(CMS_BASE_URL\s*=\s*\).*\$@\1$CMS_URL@" ~/kms.env
SQVS_URL=https://$SQVS_IP:12000/svs/v1
sed -i "s@^\(SVS_BASE_URL\s*=\s*\).*\$@\1$SQVS_URL@" ~/kms.env
hostnamectl set-hostname kbshostname
echo "################ Installing KMS....  #################"
./kms-*.bin || exit 1
if [ $? -ne 0 ]; then
  echo "############ KMS Installation Failed"
  exit 1
fi
echo "################ Installed KMS....  #################"
popd
