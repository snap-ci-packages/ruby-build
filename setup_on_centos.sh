#!/usr/bin/env bash

yum install -y ruby rubygems ruby-devel rpm-build rpmdevtools readline-devel ncurses-devel gdbm-devel tcl-devel openssl-devel db4-devel byacc gcc libffi-devel libffi libxml2-devel libxslt-devel
gem install bundler rake --no-ri --no-rdoc
bundle install --path .bundle
