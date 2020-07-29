#!/bin//bash
install_pre_requisites()
{
	dnf install -y bc wget tar git gcc-c++ make automake autoconf libtool yum-utils p11-kit-devel cppunit-devel openssl-devel
}

install_pre_requisites
