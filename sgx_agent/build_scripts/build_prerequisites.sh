#!/bin//bash
GO_VERSION=go1.14.2

install_go()
{
	go version > /dev/null 2>&1
	if [ $? -ne 0 ]
	then
		echo "golang not installed. installing now"
		wget -q --delete-after https://dl.google.com/go/$GO_VERSION.linux-amd64.tar.gz -O - | tar -xz || exit 1
		mv -f go /usr/local
		grep -q '/usr/local/go/bin' ~/.bash_profile || echo "export PATH=$PATH:/usr/local/go/bin" >> ~/.bash_profile
		[[ "$PATH" == *"/usr/local/go/bin"* ]] || PATH="${PATH}:/usr/local/go/bin"
	fi
}

install_pre_requisites()
{
	dnf install -y wget tar git gcc-c++ make curl-devel
	dnf localinstall -y https://dl.fedoraproject.org/pub/fedora/linux/releases/30/Everything/x86_64/os/Packages/m/makeself-2.4.0-3.fc30.noarch.rpm
}

install_pre_requisites
install_go
