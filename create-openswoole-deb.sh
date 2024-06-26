#!/bin/bash

export DEBFULLNAME="Rob Thomas"
export DEBEMAIL="xrobau@gmail.com"

cd src
if [ ! -e dh-make-php ]; then
	git clone https://github.com/Avature/dh-make-php.git
	cd dh-make-php
	sed -i 's/install-man$//' Makefile
	cd ..
fi
if [ ! -e /usr/bin/dh-make-pecl ]; then
	cd dh-make-php
	make install
	sed -i 's/PECL_PKG_REALNAME)-\*)/PECL_PKG_REALNAME)-*[0-9])/' /usr/share/dh-make-php/pecl.template/rules
	cd ..
fi

SRCTGZ="openswoole-${OPENSWOOLE}.tgz"
if [ ! -e "$SRCTGZ" ]; then
	pecl download openswoole-${OPENSWOOLE}
fi

dh-make-pecl $SRCTGZ

cd php-openswoole-${OPENSWOOLE}
find . -name test.jpg -delete
find . -name test.png -delete
find . -name tmp_file.jpg -delete
sed -i 's_./configure_./configure --enable-swoole --enable-sockets --enable-openssl --enable-swoole-json --enable-swoole-curl --enable-http2_' debian/rules
sed -i 's/dh \$@/dh \$@ --parallel/' debian/rules
sed -i 's/priority=20/priority=90/' debian/openswoole.ini
DEB_BUILD_OPTIONS='parallel=4' debuild -us -uc

