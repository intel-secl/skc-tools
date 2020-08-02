# SKC Quick Start Guide

## SKC Key Components and Services

1. Authorization and Authentication Service
2. Certificate Management Service
3. SGX Host Verification Service
4. SGX Caching Service
5. SGX hub
6. Key Broker Service
7. SGX Quote Verification Service
8. SGX Agent
9. SKC Library

## System Requirements

**SKC Services**

**Recommended HW**

​	1 vCPUs 
​	RAM: 2 GB 
​	10 GB 
​	One network interface with network access to all Intel® SecL-DC services 

**Operating System**

​	RHEL8.1 with root account access (All SKC Services run as root)

**Disable Firewall**

​	systemctl stop firewalld

**SGX Agent & SKC Library**

**Hardware**

​	SGX Enabled ICX Whitley System

**Operating System**

​	RHEL 8.1

**Disable Firewall**

​	systemctl stop firewalld

## Access Requirements & Configuration

- Get access to SKC git repositories in gitlab

- create ssh key using following command

  - ssh-keygen

- copy the content of ~/.ssh/id_rsa.pub to the Gitlab

  - https://gitlab.devtools.intel.com/sst/isecl (UserProfile->Settings->SSH Keys->Add Key)

- create ~/.gitconfig file and copy the following content in it:

  [user]            

  ​	email = <intel mail id>

  ​	name = <username>    

  [color]            

  ​	ui = true    

  [url "ssh://git@gitlab.devtools.intel.com:29418/"]            

  ​	insteadOf = https://gitlab.devtools.intel.com/    

  [core]

  ​	filemode = false Save and close

## Building & Deployment of Services

**Build SKC Services**

- pull sgx-tools repo (https://gitlab.devtools.intel.com/sst/isecl/sgx-tools) to workspace using git clone command 
- cd into skc_scripts
- run build_skc.sh
  - It will download and install required pre-requisites.
  - The source code will be checked out to ~/skc folder and built binaries will be available in ~/skc/bin
- Authentication and Authorization Service (AAS)
- Certificate Management Service (CMS)
- SGX Caching Service (SCS)
- SGX Quote Verification Service (SQVS)
- SGX Host Verification Service (SHVS)
- SGX Hub Service (SHUB)

**Deploy SKC Service**

- Update the skc.conf with the IP address of the VM where services will be deployed
- run install_skc.sh
  - It will update all the required configuration files and install all the services
- Check Service Status
  - netstat -ntlp
  - Using services
    - cms status
    - authservice status
    - scs status
    - sqvs status
    - shvs status
    - shub status
    - kms status
- Turn off Firewall service or ensure that these services can be accessed from the machine where SGX Agent/SKC_Library is running # systemctl stop firewalld

## Building & Deployment SGX Agent & SKC Library

**Build SGX_Agent**

pull sgx-tools repo to workspace using git clone command.

cd into sgx_agent/build_scripts folder

Follow the instructions in README.build file

https://gitlab.devtools.intel.com/sst/isecl/sgx-tools/-/blob/v14+next-major/sgx_agent/build_scripts/README.build

**Deploy SGX Agent**

cd into sgx_agent/deploy_scripts folder

Follow the instructions in README.build file

https://gitlab.devtools.intel.com/sst/isecl/sgx-tools/-/blob/v14+next-major/sgx_agent/deploy_scripts/README.install

**Build SKC Library**

cd into sgx_agent/build_scripts folder

Follow the instructions in README.build file

https://gitlab.devtools.intel.com/sst/isecl/sgx-tools/-/blob/v14+next-major/skc_library/build_scripts/README.build

**Deploy SKC Library**

cd into sgx_agent/deploy_scripts folder

Follow the instructions in README.build file

https://gitlab.devtools.intel.com/sst/isecl/sgx-tools/-/blob/v14+next-major/skc_library/deploy_scripts/README.install

## Creating AES and RSA Keys in Key Broker Service

**Configuration Update to create Keys in KBS**

​	cd into kbs_scripts folder

​	Update Key Transfer Input Parameters transfer_policy_request.json (SGX Measurement and Type SGX)

​	Update KBS and AAS IP address in ./run.sh

**Create AES Key**

​	Execute the command

​	./run.sh

**Create RSA Key**

​	Execute the command

​	./run.sh reg

- copy the generated cert file to sgx machine where skc_library is deployed. Also copy the key id generated

## Configuration for NGINX testing

**Note:** OpenSSL and NGINX base configuration updates are completed as part of deployment script.

**OpenSSL**

[openssl_def]
engines = engine_section

[engine_section]
pkcs11 = pkcs11_section

[pkcs11_section]
engine_id = pkcs11

dynamic_path =/usr/lib64/engines-1.1/pkcs11.so

MODULE_PATH =/opt/skc/lib/libpkcs11-api.so

init = 0

**Nginx**

user root;

ssl_engine pkcs11;

Update the location of certificate with the loaction where it was copied into the skc_library machine. 

ssl_certificate "/root/nginx/nginxcert.pem"; 

Update the KeyID with the KeyID received when RSA key was generated in KBS

ssl_certificate_key "engine:pkcs11:pkcs11:token=KMS;id=164b41ae-be61-4c7c-a027-4a2ab1e5e4c4;object=RSAKEY;type=private;pin-value=1234";

**SKC Configuration**

​ Create keys.txt in any folder. The keyID should match the keyID of RSA key created in KBS. Other contents should 	match with nginx.conf. File location should match on pkcs11-apimodule.ini; 

​	pkcs11:token=KMS;id=164b41ae-be61-4c7c-a027-4a2ab1e5e4c4;object=RSAKEY;type=private;pin-value=1234";

​	**Note:** Content of this file should match with the nginx conf file

​	**/opt/skc/etc/pkcs11-apimodule.ini**

​	**[core]**
​	preload_keys=/tmp/keys.txt
​	keyagent_conf=/opt/skc/etc/key-agent.ini
​	mode=SGX
​	debug=true
​	**[SW]**
​	module=/usr/lib64/pkcs11/libsofthsm2.so
​	**[SGX]**
​	module=/opt/intel/cryptoapitoolkit/lib/libp11sgx.so

**Appendix**

**Product Guide**

https://gitlab.devtools.intel.com/sst/isecl/sgx-tools/-/blob/v14+next-major/SKC_Product_Guide.md

**Release Notes**

https://gitlab.devtools.intel.com/sst/isecl/sgx-tools/-/blob/v14+next-major/ReleaseNotes
