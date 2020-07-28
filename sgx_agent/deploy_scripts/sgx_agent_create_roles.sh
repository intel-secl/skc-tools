#!/bin/bash
#set -x
#Steps:
#Get token from AAS
#to customize, export the correct values before running the script

echo "Setting up SGX_AGENT Related roles and user in AAS Database"

AGENT_env="/root/sgx_agent.env";
source $AGENT_env

#Get the value of AAS IP address and port. Default vlue is also provided.
aas_hostname=$AAS_API_URL
CURL_OPTS="-s -k"
CN="SGX_AGENT TLS Certificate"

mkdir -p /tmp/sgx_agent
tmpdir=$(mktemp -d -p /tmp/sgx_agent)

cat >$tmpdir/aasAdmin.json <<EOF
{
"username": "admin",
"password": "password"
}
EOF

output=`curl $CURL_OPTS -X POST -H "Content-Type: application/json" -H "Accept: application/jwt" --data @$tmpdir/aasAdmin.json -w "%{http_code}" $aas_hostname/token`

Bearer_token=`echo $output | rev | cut -c 4- | rev`
response_status=`echo "${output: -3}"`

#Create SGX_AGENT User
create_sgx_agent_user() {
cat > $tmpdir/user.json << EOF
{
	"username":"sgx_agent",
	"password":"password"
}
EOF

curl $CURL_OPTS -X POST -H "Content-Type: application/json" -H "Authorization: Bearer ${Bearer_token}" --data @$tmpdir/user.json -o $tmpdir/user_response.json -w "%{http_code}" $aas_hostname/users > $tmpdir/createsgx_agentuser-response.status

local status=$(cat $tmpdir/createsgx_agentuser-response.status)
if [ $status -ne 201 ]; then
	local response_mesage=$(cat $tmpdir/user_response.json)
	if [ "$response_mesage" = "same user exists" ]; then
		return 2 
	fi
	return 1
fi

if [ -s $tmpdir/user_response.json ]; then
	user_id=$(jq -r '.user_id' < $tmpdir/user_response.json)
	if [ -n "$user_id" ]; then
		echo "Created user id: $user_id"
		SGX_AGENT_USER_ID=$user_id;
	fi
fi
}

#Add SGX AGENT roles
create_user_roles() {

cat > $tmpdir/roles.json << EOF
{
	"service": "$1",
	"name": "$2",
	"context": "$3"
}
EOF

curl $CURL_OPTS -X POST -H "Content-Type: application/json" -H "Authorization: Bearer ${Bearer_token}" --data @$tmpdir/roles.json -o $tmpdir/role_response.json -w "%{http_code}" $aas_hostname/roles > $tmpdir/role_response-status.json

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

if [ -s $tmpdir/role_response.json ]; then
	role_id=$(jq -r '.role_id' < $tmpdir/role_response.json)
fi

echo "$role_id"
}

create_roles()
{
	local cms_role_id=$( create_user_roles "CMS" "CertApprover" "CN=$CN;SAN=$SAN_LIST;CERTTYPE=TLS" ) #get roleid
	local hvs_role_id=$( create_user_roles "SHVS" "HostRegistration" "" )
	ROLE_ID_TO_MAP=`echo \"$cms_role_id\",\"$hvs_role_id\"`
	echo $ROLE_ID_TO_MAP
}

#Map sgx_agent User to Roles
mapUser_to_role() {
cat >$tmpdir/mapRoles.json <<EOF
{
	"role_ids": [$ROLE_ID_TO_MAP]
}
EOF

curl $CURL_OPTS -X POST -H "Content-Type: application/json" -H "Authorization: Bearer ${Bearer_token}" --data @$tmpdir/mapRoles.json -o $tmpdir/mapRoles_response.json -w "%{http_code}" $aas_hostname/users/$user_id/roles > $tmpdir/mapRoles_response-status.json

local status=$(cat $tmpdir/mapRoles_response-status.json)
if [ $status -ne 201 ]; then
	return 1 
fi
}

SGX_AGENT_SETUP_API="create_sgx_agent_user create_roles mapUser_to_role"

status=
for api in $SGX_AGENT_SETUP_API
do
	echo $api
	eval $api
    	status=$?
	if [ $status -ne 0 ]; then
		echo "SGX_Agent-AAS User/Roles creation failed.: $api"
		break;
	fi
done

if [ $status -eq 0 ]; then
    echo "SGX_AGENT Setup for AAS-CMS complete: No errors"
fi
if [ $status -eq 2 ]; then
    echo "SGX_AGENT Setup for AAS-CMS already exists in AAS Database: No action will be taken"
fi

#Get Token for SGX-Agent USER and configure it in sgx_agent config.
curl $CURL_OPTS -X POST -H "Content-Type: application/json" -H "Accept: application/jwt" --data @$tmpdir/user.json -o $tmpdir/sgx_agent_token-response.json -w "%{http_code}" $aas_hostname/token > $tmpdir/getsgx_agentusertoken-response.status

status=$(cat $tmpdir/getsgx_agentusertoken-response.status)
if [ $status -ne 200 ]; then
	echo "Couldn't get bearer token"
else
	TOKEN=`cat $tmpdir/sgx_agent_token-response.json`
	sed -i "s|BEARER_TOKEN=.*|BEARER_TOKEN=$TOKEN|g" $AGENT_env
	echo $TOKEN
fi

# cleanup
rm -rf $tmpdir
