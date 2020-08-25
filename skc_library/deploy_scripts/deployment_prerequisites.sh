#!/bin//bash
install_pre_requisites()
{
	dnf localinstall -y https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/e/epel-release-8-8.el8.noarch.rpm
	dnf localinstall -y https://dl.fedoraproject.org/pub/fedora/linux/releases/30/Everything/x86_64/os/Packages/s/softhsm-2.5.0-3.fc30.1.x86_64.rpm
	dnf localinstall -y https://dl.fedoraproject.org/pub/fedora/linux/releases/30/Everything/x86_64/os/Packages/l/libgda-5.2.8-4.fc30.x86_64.rpm
	dnf localinstall -y https://dl.fedoraproject.org/pub/fedora/linux/releases/30/Everything/x86_64/os/Packages/l/libgda-sqlite-5.2.8-4.fc30.x86_64.rpm

	dnf install -y yum-utils tar wget gcc-c++ kernel-devel kernel-headers dkms make jq protobuf jsoncpp jsoncpp-devel opensc nginx
	cp -rpf bin/pkcs11.so /usr/lib64/engines-1.1/
	ln -sf /usr/lib64/engines-1.1/pkcs11.so /usr/lib64/engines-1.1/libpkcs11.so
        ln -sf /usr/lib64/libjsoncpp.so /usr/lib64/libjsoncpp.so.0
}

install_pre_requisites
