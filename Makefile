PASSENGER_VERSION := 5.0.21
NGINX_VERSION := 1.9.7
MORE_HEADERS_VERSION := 0.28

NGINX_TARBALL := nginx-$(NGINX_VERSION).tar.gz
NGINX_URL := http://nginx.org/download/$(NGINX_TARBALL)
NGINX_DIR := nginx-$(NGINX_VERSION)

PASSENGER_TARBALL := passenger-$(PASSENGER_VERSION).tar.gz
PASSENGER_URL := https://s3.amazonaws.com/phusion-passenger/releases/$(PASSENGER_TARBALL)
PASSENGER_DIR := passenger-$(PASSENGER_VERSION)

MORE_HEADERS_TARBALL := more-headers-$(MORE_HEADERS_VERSION).tar.gz
MORE_HEADERS_URL := https://github.com/openresty/headers-more-nginx-module/archive/v${MORE_HEADERS_VERSION}.tar.gz
MORE_HEADERS_DIR := headers-more-nginx-module-$(MORE_HEADERS_VERSION)

UNTAR := tar -zxf
CURL := curl -LSs

all: build

$(NGINX_TARBALL):
	$(CURL) -o "$@" "$(NGINX_URL)"

$(NGINX_DIR): $(NGINX_TARBALL)
	$(UNTAR) "$<"

$(PASSENGER_TARBALL):
	$(CURL) -o "$@" "$(PASSENGER_URL)"

$(PASSENGER_DIR): $(PASSENGER_TARBALL)
	$(UNTAR) "$<"

$(MORE_HEADERS_TARBALL):
	$(CURL) -o "$@" "$(MORE_HEADERS_URL)"

$(MORE_HEADERS_DIR): $(MORE_HEADERS_TARBALL)
	$(UNTAR) "$<"

build: | $(NGINX_DIR) $(PASSENGER_DIR) $(MORE_HEADERS_DIR)
	update-alternatives --install /usr/bin/gem gem /usr/bin/gem2.0 100
	if [ -z "$(which bundle)" ]; then gem install bundler; fi
	if [ -z "$(which rake)" ]; then gem install rake; fi
	cd "$(NGINX_DIR)" && \
		./configure \
			--conf-path=/etc/nginx/nginx.conf \
			--error-log-path=/var/log/nginx/error.log \
			--pid-path=/var/run/nginx.pid \
			--lock-path=/var/lock/nginx.lock \
			--http-log-path=/var/log/nginx/access.log \
			--http-client-body-temp-path=/var/lib/nginx/body \
			--http-proxy-temp-path=/var/lib/nginx/proxy \
			--without-http_fastcgi_module \
			--without-http_uwsgi_module \
			--with-http_stub_status_module \
			--with-http_gzip_static_module \
			--with-http_realip_module \
			--add-module=$(CURDIR)/$(PASSENGER_DIR)/src/nginx_module \
			--add-module=$(CURDIR)/$(MORE_HEADERS_DIR) && \
		$(MAKE)
	bundle install --deployment

install:
	cd "$(NGINX_DIR)" && $(MAKE) install
	mkdir -p /etc/nginx/modules/passenger
	cp -R $(PASSENGER_DIR)/* /etc/nginx/modules/passenger
	cp -R "$(CURDIR)/etc" /
	cp -R "$(CURDIR)/lib" /
	cp -R "$(CURDIR)/var" /
	cp -R "$(CURDIR)/usr" /
	ln -s /usr/local/nginx/sbin/nginx /usr/sbin
	cp -R Gemfile /etc/nginx/modules/passenger
	cp -R Gemfile.lock /etc/nginx/modules/passenger
	cp -R vendor /etc/nginx/modules/passenger
	cp -R .bundle /etc/nginx/modules/passenger
	mkdir -p /etc/nginx/sites-enabled/
	touch /etc/nginx/sites-enable/.dir
