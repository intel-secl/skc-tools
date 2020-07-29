#!/bin/bash
source skc_library.conf
SKCLIB_INST_PATH=/opt/skc
KMS_NPM_PATH=$SKCLIB_INST_PATH/etc/kms_npm.ini
CREDENTIAL_PATH=$SKCLIB_INST_PATH/etc/credential_agent.ini
CURL_OPTS="-s -k"
mkdir -p /tmp/skclib
tmpdir=$(mktemp -d -p /tmp/skclib)

aas_url=https://$AAS_IP:$AAS_PORT/aas

update_credential_ini()
{
	sed -i "s|server=.*|server=https:\/\/$KBS_HOSTNAME:$KBS_PORT|g" $KMS_NPM_PATH
	sed -i "s|request_params=.*|request_params=\"\/CN=$SKC_USER\"|g" $CREDENTIAL_PATH
	sed -i "s|server=.*|server=$CMS_IP|g" $CREDENTIAL_PATH
	sed -i "s|port=.*|port=$CMS_PORT|g" $CREDENTIAL_PATH
	sed -i "s|^token=.*|token=\"$SKC_TOKEN\"|g" $CREDENTIAL_PATH
	curl -k -H 'Accept:application/x-pem-file' https://$CMS_IP:$CMS_PORT/cms/v1/ca-certificates > $SKCLIB_INST_PATH/store/cms-ca.cert
}	

cat > $tmpdir/aasadmin.json << EOF
{
"username": "admin",
"password": "password"
}
EOF

#Get the AAS Admin Token
output=`curl $CURL_OPTS -X POST -H "Content-Type: application/json" -H "Accept: application/jwt" --data @$tmpdir/aasadmin.json -w "%{http_code}" $aas_url/token`
Bearer_token=`echo $output | rev | cut -c 4- | rev`
response_status=`echo "${output: -3}"`

#Create SKC_Library User
create_skclib_user()
{
cat > $tmpdir/user.json << EOF
{
"username":"$SKC_USER",
"password":"$SKC_USER_PASSWORD"
}
EOF

	curl $CURL_OPTS -X POST -H "Content-Type: application/json" -H "Authorization: Bearer ${Bearer_token}" --data @$tmpdir/user.json -o $tmpdir/user_response.json -w "%{http_code}" $aas_url/users > $tmpdir/create_skc_user-response.status

	local status=$(cat $tmpdir/create_skc_user-response.status)
	if [ $status -ne 201 ]; then
		response_mesage=$(cat $tmpdir/user_response.json)
		if [ "$response_mesage" = "same user exists" ]; then
			return 2 
		fi
		return 1
	fi

	if [ -s $tmpdir/user_response.json ]; then
		user_id=$(jq -r '.user_id' < $tmpdir/user_response.json)
		if [ -n "$user_id" ]; then
			SKCLIB_USER_ID=$user_id;
		fi
	fi
}

create_user_roles()
{
cat > $tmpdir/roles.json << EOF
{	
"service": "$1",
"name": "$2",
"context": "$3"
}
EOF

	curl $CURL_OPTS -X POST -H "Content-Type: application/json" -H "Authorization: Bearer ${Bearer_token}" --data @$tmpdir/roles.json -o $tmpdir/role_response.json -w "%{http_code}" $aas_url/roles > $tmpdir/role_response-status.json

	local status=$(cat $tmpdir/role_response-status.json)
	if [ $status -ne 201 ]; then
		local response_mesage=$(cat $tmpdir/role_response.json)
		if [ "$response_mesage"="same role exists" ]; then
			return 2 
		fi
		return 1
	fi

	if [ -s $tmpdir/role_response.json ]; then
		role_id=$(jq -r '.role_id' < $tmpdir/role_response.json)
	fi
	echo $role_id
}

create_roles()
{
	local cms_role_id=$(create_user_roles "CMS" "CertApprover" "CN=$SKC_USER;CERTTYPE=TLS-Client" ) #get roleid
	local kms_role_id=$(create_user_roles "KMS" "KeyTransfer" "permissions=nginx,USA")
	ROLE_ID_TO_MAP=`echo \"$cms_role_id\",\"$kms_role_id\"`
}

#Map skc_library User to Roles
mapUser_to_role() {
cat >$tmpdir/mapRoles.json <<EOF
{
	"role_ids": [$ROLE_ID_TO_MAP]
}
EOF

	curl $CURL_OPTS -X POST -H "Content-Type: application/json" -H "Authorization: Bearer ${Bearer_token}" --data @$tmpdir/mapRoles.json -o $tmpdir/mapRoles_response.json -w "%{http_code}" $aas_url/users/$user_id/roles > $tmpdir/mapRoles_response-status.json

	local actual_status=$(cat $tmpdir/mapRoles_response-status.json)
	if [ $actual_status -ne 201 ]; then
		return 1 
	fi
}

SKCLIB_SETUP="create_skclib_user create_roles mapUser_to_role"
status=
for api in $SKCLIB_SETUP
do
	eval $api
    	status=$?
	if [ $status -ne 0 ]; then
		echo "SKC_Library-AAS User/Roles creation failed.: $api"
		break;
	fi
done

if [ $status -eq 0 ]; then
    echo "SKC_Library Setup for AAS-CMS complete: No errors"
fi
if [ $status -eq 2 ]; then
    echo "SKC_Library Setup for AAS-CMS already exists in AAS Database: No action will be taken"
fi

#Get Token for SKC_Library user
curl $CURL_OPTS -X POST -H "Content-Type: application/json" -H "Accept: application/jwt" --data @$tmpdir/user.json -o $tmpdir/skclib_token-response.json -w "%{http_code}" $aas_url/token > $tmpdir/get_skclibusertoken-response.status

status=$(cat $tmpdir/get_skclibusertoken-response.status)
if [ $status -ne 200 ]; then
	echo "Couldn't get bearer token"
else
	SKC_TOKEN=`cat $tmpdir/skclib_token-response.json`
fi

run_credential_agent()
{
	$SKCLIB_INST_PATH/bin/credential_agent_init
	if [ $? -ne 0 ]
	then
		echo "credential init failed"
		exit 1
	fi
}

update_credential_ini
run_credential_agent
rm -rf $tmpdir
