#!/bin/sh
echo Generating mTLS certificates

openssl genrsa  -out config/certs/rootCA.generated.key 4096
openssl req -x509 -new -nodes -key config/certs/rootCA.generated.key -subj "/C=US/ST=NC/O=Red Hat, Inc./CN=Observatorium CA" -sha256 -days 3652 -out config/certs/rootCA.generated.crt

touch config/config/certs/rootCA.generated.srl
echo "01\n02\n03" > config/certs/rootCA.generated.srl

openssl genrsa -out config/certs/server-tls.generated.key 2048
openssl genrsa -out config/certs/client-tls.generated.key 2048
openssl genrsa -out config/certs/grafana-tls.generated.key 2048
openssl req -new -key rsa:2048 -key config/certs/server-tls.generated.key -out config/certs/server-tls.generated.csr -config config/certs/server_cert.conf
openssl req -new -key rsa:2048 -key config/certs/client-tls.generated.key -out config/certs/client-tls.generated.csr -config config/certs/client_cert.conf -reqexts 'v3_req'
openssl req -new -key rsa:2048 -key config/certs/grafana-tls.generated.key -out config/certs/grafana-tls.generated.csr -config config/certs/client_cert.conf -reqexts 'v3_req'
openssl x509 -req -in config/certs/server-tls.generated.csr  -CA config/certs/rootCA.generated.crt -CAkey config/certs/rootCA.generated.key -set_serial 01 -CAserial config/certs/rootCA.generated.srl -out config/certs/server-tls.generated.crt -days 730 -sha256 -extfile config/certs/server_cert.conf -extensions v3_req
openssl x509 -req -in config/certs/client-tls.generated.csr  -CA config/certs/rootCA.generated.crt -CAkey config/certs/rootCA.generated.key -set_serial 02 -CAserial config/certs/rootCA.generated.srl -out config/certs/client-tls.generated.crt -days 730 -sha256 -extfile config/certs/client_cert.conf -extensions v3_req
openssl x509 -req -in config/certs/grafana-tls.generated.csr  -CA config/certs/rootCA.generated.crt -CAkey config/certs/rootCA.generated.key -set_serial 03 -CAserial config/certs/rootCA.generated.srl -out config/certs/grafana-tls.generated.crt -days 730 -sha256 -extfile config/certs/client_cert.conf -extensions v3_req

CA=$(sed 's/^/        /g' config/certs/rootCA.generated.crt)
GRAFANA_CERT=$(sed 's/^/        /g' config/certs/grafana-tls.generated.crt)
GRAFANA_KEY=$(sed 's/^/        /g' config/certs/grafana-tls.generated.key)

echo \
"# config file version
apiVersion: 1

# list of datasources to insert/update depending
# what's available in the database
datasources:
  # <string, required> name of the datasource. Required
  - name: Prometheus
    # <string, required> datasource type. Required
    type: prometheus
    # <string, required> access mode. proxy or direct (Server or Browser in the UI). Required
    access: proxy
    # <string> url
    url: https://observatorium.monitoring.svc.cluster.local:8080/api/metrics/v1/test
    # <bool> mark as default datasource. Max one per org
    isDefault: true
    # <map> fields that will be converted to json and stored in jsonData
    jsonData:
      tlsAuth: true
      tlsAuthWithCACert: true
    # <string> json object of data that will be encrypted.
    secureJsonData:
      tlsCACert: |2
"$CA"
      tlsClientCert: |2
"$GRAFANA_CERT"
      tlsClientKey: |2
"$GRAFANA_KEY"
    version: 1" > config/datasource.generated.yaml