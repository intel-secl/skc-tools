#!/bin/bash
verify_checksum()
{
	sha256sum -c skc_library.sha2 > /dev/null 2>&1
	if [ $? -ne 0 ]
	then
		echo "checksum verification failed"
		exit 1
	fi
	tar -xf skc_library.tar
	echo "skc_library untar completed."
	echo "Please update the skc_library.conf and then run ./deploy_skc_library.sh"
}

verify_checksum
