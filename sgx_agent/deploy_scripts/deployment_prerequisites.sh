#!/bin//bash
install_pre_requisites()
{
	dnf localinstall -y https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/e/epel-release-8-8.el8.noarch.rpm
	dnf install -y yum-utils dkms tar make jq || exit 1
}

install_pre_requisites
