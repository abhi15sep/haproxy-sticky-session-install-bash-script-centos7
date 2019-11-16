#!/bin/bash

#install haproxy software
yum -y install haproxy

#Allow selinux-policy for haproxy
setsebool -P haproxy_connect_any=1

#Update configuration
cat > /etc/haproxy/haproxy.cfg << EOF
global
	maxconn 4096
  	daemon
  	stats socket /tmp/haproxy.sock mode 777
  	stats socket /tmp/haproxy.sock mode 777 level admin
  	maxcomprate 0
  	maxcompcpuusage 50
  	tune.ssl.default-dh-param 2048
  	log 127.0.0.1:29987 local0

defaults
	mode http
	option dontlognull
	retries 3
	option redispatch
	option forwardfor except 127.0.0.0/8
	maxconn 2000
	timeout connect 5000
	timeout client 50000
	timeout server 50000
	option http-server-close
	log global

listen  stats   
	bind :8081
	mode http
	log global
	maxconn 10
	timeout client      100s
	timeout server      100s
	timeout connect      100s
	timeout queue   100s
	stats enable
	stats hide-version
	stats refresh 30s
	stats show-node
	stats auth admin:admin@ooops
	stats uri  /


listen Web-HTTP
	bind :80
	balance source
	maxconn 50000
	mode http
    acl is_hc hdr(host) -i check.test.com
	option httpclose
	option forwardfor except 127.0.0.1/8
	option redispatch
	option httplog
	cookie catchid insert
	http-request set-header X-Client-IP req.hdr_ip([X-Forwarded-For])
	server HTTP1 10.0.0.1:80 check fall 3 rise 5 inter 2000 weight 10
	server HTTP2 10.0.0.2:80 check fall 3 rise 5 inter 2000 weight 10


listen Web-HTTP-NEW
	balance roundrobin
	mode http
	maxconn 50000
	bind :80
	option httpclose
	option forwardfor except 127.0.0.1/8
	#http-request set-header X-Client-IP req.hdr_ip([X-Forwarded-For])
	http-request add-header X-CLIENT-IP %[src]
	option redispatch
	redirect scheme https if !{ ssl_fc }
	cookie catchid  insert
	option httplog


listen Web-HTTPS
	bind :443
	balance leastconn
	stick-table type ip size 200k expire 30m
    stick on src
	maxconn 800
	mode tcp
	option ssl-hello-chk
	option httpclose
	option forwardfor except 127.0.0.0/8
	http-request set-header X-Client-IP req.hdr_ip([X-Forwarded-For])
	option redispatch
	compression algo gzip
	compression type text/plain text/html text/css application/x-javascript text/xml application/xml application/xml+rss text/javascript application/javascript	
	server SSL1 10.0.0.1:443 check fall 3 rise 5 inter 2000 weight 10
	server SSL2 10.0.0.2:443 check fall 3 rise 5 inter 2000 weight 10
EOF


# Disabled firewall to avoid setup issue
setenforce 0
systemctl stop firewalld
systemctl disable firewalld


# start haproxy
systemctl start haproxy
systemctl enable haproxy
