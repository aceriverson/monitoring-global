#!/bin/sh
echo Generating mTLS certificates

openssl genrsa  -out certs/rootCA.generated.key 4096
openssl req -x509 -new -nodes -key certs/rootCA.generated.key -subj "/C=US/ST=NC/O=Red Hat, Inc./CN=Observatorium CA" -sha256 -days 3652 -out certs/rootCA.generated.crt

touch certs/rootCA.generated.srl
echo "03\n04" > certs/rootCA.generated.srl

openssl genrsa -out certs/server-tls.generated.key 2048
openssl genrsa -out certs/client-tls.generated.key 2048
openssl req -new -key rsa:2048 -key certs/server-tls.generated.key -out certs/server-tls.generated.csr -config certs/server_cert.conf
openssl req -new -key rsa:2048 -key certs/client-tls.generated.key -out certs/client-tls.generated.csr -config certs/client_cert.conf -reqexts 'v3_req'
openssl x509 -req -in certs/server-tls.generated.csr  -CA certs/rootCA.generated.crt -CAkey certs/rootCA.generated.key -set_serial 01 -CAserial certs/rootCA.generated.srl -out certs/server-tls.generated.crt -days 730 -sha256 -extfile certs/server_cert.conf -extensions v3_req
openssl x509 -req -in certs/client-tls.generated.csr  -CA certs/rootCA.generated.crt -CAkey certs/rootCA.generated.key -set_serial 02 -CAserial certs/rootCA.generated.srl -out certs/client-tls.generated.crt -days 730 -sha256 -extfile certs/client_cert.conf -extensions v3_req