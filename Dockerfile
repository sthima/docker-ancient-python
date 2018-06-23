FROM alpine:3.7

# ensure local python is preferred over distribution python
ENV PATH /usr/local/bin:$PATH

# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG C.UTF-8
# https://github.com/docker-library/python/issues/147
ENV PYTHONIOENCODING UTF-8

# install ca-certificates so that HTTPS works consistently
# the other runtime dependencies for Python are installed later
RUN apk add --no-cache ca-certificates

ENV PYTHON_VERSION 2.5.6

RUN set -ex \
	&& apk add --no-cache --virtual .fetch-deps \
		openssl \
		tar \
		sed \
		gzip \
	\
	&& wget -O python.tgz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tgz" \
	&& mkdir -p /usr/src/python \
	&& tar -xzC /usr/src/python --strip-components=1 -f python.tgz \
  && sed -i -r "s/\<posix_close\>/posix_closex/" /usr/src/python/Modules/posixmodule.c \
	&& rm python.tgz \
	\
	&& apk add --no-cache --virtual .build-deps  \
		bzip2-dev \
		coreutils \
		dpkg-dev dpkg \
		gcc \
		gdbm-dev \
		libc-dev \
		libnsl-dev \
		openssl \
		openssl-dev \
		libtirpc-dev \
		linux-headers \
		make \
		ncurses-dev \
		pax-utils \
		readline-dev \
		sqlite-dev \
		tcl-dev \
		tk \
		tk-dev \
		zlib-dev \
# add build deps before removing fetch deps in case there's overlap
	&& apk del .fetch-deps \
	\
	&& cd /usr/src/python \
	&& gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
	&& ./configure \
		--build="$gnuArch" \
		--enable-shared \
		--enable-unicode=ucs4 \
	&& make -j "$(nproc)" \
# set thread stack size to 1MB so we don't segfault before we hit sys.getrecursionlimit()
# https://github.com/alpinelinux/aports/commit/2026e1259422d4e0cf92391ca2d3844356c649d0
		EXTRA_CFLAGS="-DTHREAD_STACK_SIZE=0x100000" \
	&& make install \
	\
	&& runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
			| tr ',' '\n' \
			| sort -u \
			| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)" \
	&& apk add --virtual .python-rundeps $runDeps \
	&& apk del .build-deps \
	\
	&& find /usr/local -depth \
		\( \
			\( -type d -a \( -name test -o -name tests \) \) \
			-o \
			\( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
		\) -exec rm -rf '{}' + \
	&& rm -rf /usr/src/python

# if this is called "PIP_VERSION", pip explodes with "ValueError: invalid truth value '<VERSION>'"
ENV PYTHON_PIP_VERSION 1.3.1

RUN set -ex; \
	\
	apk add --no-cache --virtual .fetch-deps openssl; \
	\
	wget -O setuptools.tar.gz 'https://pypi.python.org/packages/source/s/setuptools/setuptools-1.4.2.tar.gz'; \
	mkdir -p /usr/src/setuptools; \
	tar -xzC /usr/src/setuptools --strip-components=1 -f setuptools.tar.gz; \
	rm setuptools.tar.gz; \
	cd /usr/src/setuptools && python setup.py install;\
	cd / \
  rm -rf /usr/src/setuptools; \
	\
	wget -O pip.tar.gz 'https://pypi.python.org/packages/source/p/pip/pip-1.3.1.tar.gz'; \
	mkdir -p /usr/src/pip; \
	tar -xzC /usr/src/pip --strip-components=1 -f pip.tar.gz; \
	rm pip.tar.gz; \
	cd /usr/src/pip && python setup.py install;\
	cd / \
  rm -rf /usr/src/pip; \
	\
	apk del .fetch-deps; \
	\
	pip --version;

CMD ["python2"]
