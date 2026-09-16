.PHONY: lint template deploy

lint:
	helm dependency build
	helm lint .

template:
	helm dependency build
	helm template myapp . --namespace app

deploy:
	helm upgrade --install myapp . --namespace app --create-namespace --wait --timeout 10m
