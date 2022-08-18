deploy:
	sh config/certs/gencerts.sh
	oc apply -k .
	oc project monitoring
	oc apply -f metricgen
	oc apply -f prometheus
	oc apply -f thanos-query
	oc apply -f thanos-receive
	oc apply -f thanos-store
	oc apply -f minio
	oc apply -f observatorium
	oc apply -f grafana