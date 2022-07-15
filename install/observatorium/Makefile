SHELL=bash
export OBSERVATORIUM_APPS_URL := $(shell oc get --namespace openshift-ingress-operator ingresscontrollers/default --output jsonpath='{.status.domain}{"\n"}')
export DEX_TOKEN_URL := dex-dex.$(OBSERVATORIUM_APPS_URL)
export OBSERVATORIUM_ROUTE_HOST ?=observatorium-observatorium.$(OBSERVATORIUM_APPS_URL)
export GATEWAY_URL := https://$(OBSERVATORIUM_ROUTE_HOST)
export DEX_NAMESPACE?=dex
export MINIO_NAMESPACE?=observatorium-minio
export OBSERVATORIUM_NAMESPACE?=observatorium


ifndef observatorium_env
	export observatorium_env :=dev
endif

ifeq (,$(and $(shell which vault),$(shell vault print token)))
export DEX_TENANT_CLIENT_SECRET?="ZXhhbXBsZS1hcHAtc2VjcmV0"
export DEX_ADMIN_PASS?="password"
else ifeq ($(observatorium_env),stage)
export DEX_TENANT_CLIENT_SECRET?="stage"
else ifeq ($(observatorium_env),prod)
export DEX_TENANT_CLIENT_SECRET:=$(shell vault kv get -field=dex_tenant_client_secret -address=https://vault.xxx.net blah/blah)
export DEX_ADMIN_PASS?=$(shell vault kv get -field=dex_password -address=https://vault.xxx.net blah/blah-key)
else ifeq ($(observatorium_env),dev)
export DEX_TENANT_CLIENT_SECRET?="blah"
endif


# List all environment variables for debugging purposes
.PHONY: env
env:
	$(foreach var,$(.VARIABLES),$(info $(var) = $($(var))))


# Deploy dex IDP based on environment type
.PHONY: create/dex
create/dex:
ifeq ($(observatorium_env),dev)
create/dex: create/dex/dev
endif


#Deploy Dex for Dev environment uzing kustomize. 
.PHONY: create/dex/dev
	@echo "Create dex in: $(DEX_NAMESPACE) for Dev environment"
	@echo "$(DEX_TOKEN_URL)"
	@cp config/certs/tls.generated.crt config/certs/tls.generated.key config/certs/rootCA.generated.crt config/dex/dev
	@cat config/dex/dev/config.yaml |\
	sed -e "s/<dex_issuer_url>/https\:\/\/$(DEX_TOKEN_URL)\/dex/g;s/<dex_tenant_client_secret>/$(DEX_TENANT_CLIENT_SECRET)/g"|sed 's/<dex_admin_pass_hash>/\"$(shell htpasswd -bnBC 10 "admin"  $(DEX_ADMIN_PASS) | cut -d ":" -f 2 | sed "s/2y/2a/;s/\\$$/\\\\$$/g;s/\./\\\\./g;s#\/#\\\/#g")\"/g'\
	 > config/dex/dev/config.generated.yaml
	@oc kustomize config/dex/dev |sed 's/<namespace>/$(DEX_NAMESPACE)/g' |oc apply -f -

.PHONY: create/certs/dev
create/certs/dev:
	@echo "Generating certificate"
	@cat config/certs/cert_req.conf |\
	sed -e "s/<dex_issuer_url>/$(DEX_TOKEN_URL)/g;s/<observatorium_host_url>/$(OBSERVATORIUM_ROUTE_HOST)/g"	> config/certs/cert_req.generated.conf
	@openssl genrsa  -out config/certs/rootCA.generated.key 4096
	@openssl req -x509 -new -nodes -key config/certs/rootCA.generated.key -subj "/C=US/ST=NC/O=Red Hat, Inc./CN=Observatorium" -sha256 -days 3652 -out config/certs/rootCA.generated.crt
	@openssl genrsa -out config/certs/tls.generated.key 2048
	@openssl req -new -key rsa:2048 -key config/certs/tls.generated.key -out config/certs/tls.generated.csr -config config/certs/cert_req.generated.conf -reqexts 'v3_req'
	@openssl req -in config/certs/tls.generated.csr -text -noout
	@openssl x509  -req -in config/certs/tls.generated.csr  -CA config/certs/rootCA.generated.crt -CAkey config/certs/rootCA.generated.key -CAcreateserial -out config/certs/tls.generated.crt -days 730 -sha256 -extfile config/certs/cert_req.generated.conf -extensions v3_req
	@openssl x509 -in config/certs/tls.generated.crt -text -noout

.PHONY: create/certs/mTLS/dev
create/certs/mTLS/dev:
	@openssl genrsa -out config/certs/client-tls.generated.key 2048
	@openssl req -new -key rsa:2048 -key config/certs/client-tls.generated.key -out config/certs/client-tls.generated.csr -config config/certs/mtls_cert_req.conf -reqexts 'v3_req'
	@openssl req -in config/certs/client-tls.generated.csr -text -noout
	@openssl x509 -req -in config/certs/client-tls.generated.csr  -CA config/certs/rootCA.generated.crt -CAkey config/certs/rootCA.generated.key -CAcreateserial -out config/certs/client-tls.generated.crt -days 730 -sha256 -extfile config/certs/mtls_cert_req.conf -extensions v3_req
	@openssl x509 -in config/certs/client-tls.generated.crt -text -noout

# Deploy MINIO to different environments
.PHONY: create/minio
create/minio:
ifeq ($(observatorium_env),dev)
create/minio: create/minio/dev
endif
# ifeq ($(observatorium_env),stage)
# create/minio: create/minio/stage
# endif

.PHONY: create/minio/dev
create/minio/dev:
	@echo "create minio in: $(MINIO_NAMESPACE) for Dev environment"
	@oc kustomize config/minio/dev |sed 's/<namespace>/$(MINIO_NAMESPACE)/g' |oc apply -f -


.PHONY: create/crds
create/crds:
	@oc apply -f ./crd.yaml
	@echo "Waiting for Observatorium CRD to be created"
	@for i in {1..12}; do oc get crd observatoria.core.observatorium.io && break || sleep 5; done

.PHONY: create/operator
create/operator:
	@echo "Create observatorium operator in: $(OBSERVATORIUM_NAMESPACE)"
	@oc kustomize config/operator/bases |sed 's/<namespace>/$(OBSERVATORIUM_NAMESPACE)/g' |oc apply -f -
	@ for i in {1..12}; do oc -n $(OBSERVATORIUM_NAMESPACE) get pod -l control-plane=observatorium-operator -o name | grep "pod/observatorium-operator" && break || sleep 5; done


# Deploy Observatorium 
.PHONY: create/observatorium
create/observatorium:
ifeq ($(observatorium_env),dev)
create/observatorium: create/observatorium/dev
endif
# ifeq ($(observatorium_env),stage)
# create/observatorium: create/observatorium/stage
# endif
# ifeq ($(observatorium_env),prod)
# create/observatorium: create/observatorium/prod
# endif


.PHONY: create/observatorium/dev
create/observatorium/dev:
	@echo "create observatorium in: $(OBSERVATORIUM_NAMESPACE) for Dev Environment"
	@cp config/certs/tls.generated.crt config/certs/tls.generated.key config/certs/rootCA.generated.crt config/observatorium/dev
	cat config/observatorium/dev/thanos.yaml  > config/observatorium/dev/thanos.generated.yaml
	oc kustomize config/observatorium/dev |sed 's/<dex_issuer_url>/$(DEX_TOKEN_URL)/g;s/<namespace>/$(OBSERVATORIUM_NAMESPACE)/g;s/<hosturl>/$(OBSERVATORIUM_ROUTE_HOST)/g' |oc apply -f -

.PHONY: create/observatorium/mTLS/dev
create/observatorium/mTLS/dev:
	@echo "create observatorium in: $(OBSERVATORIUM_NAMESPACE) for Dev Environment"
	@cp config/certs/tls.generated.crt config/certs/tls.generated.key config/certs/rootCA.generated.crt config/certs/client-tls.generated.crt config/certs/client-tls.generated.key config/observatorium/dev
	cat config/observatorium/dev/thanos.yaml  > config/observatorium/dev/thanos.generated.yaml
	oc kustomize config/observatorium/dev |sed 's/<dex_issuer_url>/$(DEX_TOKEN_URL)/g;s/<namespace>/$(OBSERVATORIUM_NAMESPACE)/g;s/<hosturl>/$(OBSERVATORIUM_ROUTE_HOST)/g' |oc apply -f -

.PHONY: create/observatorium-up
create/observatorium-up:
	@echo "create observatorium-up job in: $(OBSERVATORIUM_NAMESPACE) for Dev Environment"
	oc kustomize config/observatorium-up/bases |sed 's/<namespace>/$(OBSERVATORIUM_NAMESPACE)/g' |oc apply -f -

.PHONY: delete/observatorium-up
delete/observatorium-up:
	@echo "Delete observatorium-up job in: $(OBSERVATORIUM_NAMESPACE) for Dev Environment"
	oc delete job observatorium-up-metrics-tls -n $(OBSERVATORIUM_NAMESPACE)

.PHONY: create/observatorium-up/mtls
create/observatorium-up/mtls: create/certs/mTLS/dev
	@echo "create observatorium-up mTLS job in: $(OBSERVATORIUM_NAMESPACE) for Dev Environment"
	oc kustomize config/observatorium-up/mtls |sed 's/<namespace>/$(OBSERVATORIUM_NAMESPACE)/g' |oc apply -f -

.PHONY: delete/observatorium-up/mtls
delete/observatorium-up/mtls:
	@echo "Delete observatorium-up mTLS job in: $(OBSERVATORIUM_NAMESPACE) for Dev Environment"
	oc delete job observatorium-up-metrics-mtls -n $(OBSERVATORIUM_NAMESPACE)


.PHONY: create/cr
create/cr:
	@echo "create observatorium in: $(OBSERVATORIUM_NAMESPACE)"
	@sed 's/<namespace>/$(OBSERVATORIUM_NAMESPACE)/g' ./observatorium.yaml | cat | oc apply -f -

# .PHONY: create/cr-multitenant
# create/cr-multitenant:
# 	@echo "create multitenant observatorium in: $(OBSERVATORIUM_NAMESPACE)"
# 	@sed 's/<namespace>/$(OBSERVATORIUM_NAMESPACE)/g' ./observatorium-multitenant.yaml | cat | oc apply -f -

# .PHONY: create/dex-multitenant-secret
# create/dex-multitenant-secret:
# 	@echo "Updating dex config secret in:  $(DEX_NAMESPACE) for multitenancy"
# 	oc delete secret dex -n $(DEX_NAMESPACE);oc create secret generic dex --from-file=config.yaml=./config-multitenant.yaml -n $(DEX_NAMESPACE) --dry-run -o yaml|oc apply -f -
# 	oc delete pod -l app.kubernetes.io/name=dex -n $(DEX_NAMESPACE)

.PHONY: create/route
create/route:
	@echo "create route $(OBSERVATORIUM_ROUTE_HOST) in $(OBSERVATORIUM_NAMESPACE) namespace"
	@sed 's/<namespace>/$(OBSERVATORIUM_NAMESPACE)/g;s/<hosturl>/$(OBSERVATORIUM_ROUTE_HOST)/g' ./route.yaml | cat | oc apply -f -



#all-dev: create/dex create/minio create/crds create/operator create/observatorium
clean:
	@oc delete namespace $(DEX_NAMESPACE)
	@oc delete namespace $(MINIO_NAMESPACE)
	@oc delete namespace $(OBSERVATORIUM_NAMESPACE)
	@echo "Done uninstalling observatorium"
#	@find ./config -type f -name "*.generated.*" -exec rm {} \;


all: create/certs/dev create/dex create/minio create/crds create/operator create/observatorium
	@echo "Done installing observatorium"


.PHONEY: all/mtls
all/mtls: create/certs/dev create/certs/mTLS/dev create/dex create/minio create/crds create/operator create/observatorium/mTLS/dev
	@echo "Done installing observatorium with mTLS"