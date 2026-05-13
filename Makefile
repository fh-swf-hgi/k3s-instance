.PHONY: bootstrap reset kubeconfig test argocd-install argocd-wait argocd-app argocd-test

SSH_HOST ?= gaming
K8S_HOST ?= 172.17.204.135
USER ?= hgi
KUBECONFIG ?= ./kubeconfig

bootstrap:
	./bootstrap.sh bootstrap $(SSH_HOST) $(USER)

reset:
	./bootstrap.sh reset $(SSH_HOST) $(USER)

kubeconfig:
	ssh $(USER)@$(SSH_HOST) 'sudo cat /etc/rancher/k3s/k3s.yaml' \
	| sed 's/127.0.0.1/$(K8S_HOST)/' > kubeconfig

test:
	KUBECONFIG=$(KUBECONFIG) kubectl get nodes -o wide

argocd-install:
	KUBECONFIG=$(KUBECONFIG) kubectl create namespace argocd --dry-run=client -o yaml | KUBECONFIG=$(KUBECONFIG) kubectl apply -f -
	KUBECONFIG=$(KUBECONFIG) kubectl apply --server-side --force-conflicts -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

argocd-wait:
	KUBECONFIG=$(KUBECONFIG) kubectl -n argocd wait --for=condition=available deployment/argocd-server --timeout=180s

argocd-app:
	KUBECONFIG=$(KUBECONFIG) kubectl apply -f argocd/demo-nginx.yaml

argocd-test:
	KUBECONFIG=$(KUBECONFIG) kubectl get applications -n argocd
	KUBECONFIG=$(KUBECONFIG) kubectl get pods -n demo
	KUBECONFIG=$(KUBECONFIG) kubectl get svc -n demo

argocd-bootstrap: argocd-install argocd-wait argocd-app argocd-test
