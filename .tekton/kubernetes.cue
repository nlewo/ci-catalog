package config

_ci revision : *"master" | string
_ci namespace : *"default" | string
_ci repository branch : *"master" | string

_host: {
    base: "helm-serve-84-39-53-90.nip.io" 
    if (_ci.repository.branch != "master") {address : "ns--" + _ci.namespace + "--" + base}
    if (_ci.repository.branch == "master") {address : base}
}

probe = {
	httpGet: {
		path: "/"
		port: "helm"
	}
	initialDelaySeconds: 3
	periodSeconds:       5
}

deployment = {
	apiVersion: "extensions/v1beta1"
	kind:       "Deployment"
	metadata name: "helm-serve"
	spec template: {
		metadata labels app: "helm-serve"
		spec containers: [{
			name:  "helm-serve"
			image: "nixery.dev/shell/kubernetes-helm/git"
			ports: [{
				containerPort: 8879
				name:          "helm"
			}]
			livenessProbe:  probe
			readinessProbe: probe
			command: ["bash"]
			args: [
				"-c",
				"""
                                  set -e
                                  echo "Cloning https://github.com/nlewo/ci-catalog"
                                  git -c http.sslVerify=false clone https://github.com/nlewo/ci-catalog
                                  cd ci-catalog
                                  git checkout "\(_ci.revision)"
                                  echo "Generating packages"
                                  ls -l
                                  ls -l charts
                                  cd charts
                                  # See Error: stat /home/lewo/.helm/repository/local: no such file or directory
                                  helm init --client-only
                                  helm package *
                                  echo "Serving packages"
                                  helm serve --address 0.0.0.0:8879 --url http://"\(_host.address)"
                                """,
			]
		}]
	}
}

service = {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		name: "helm-serve"
		labels app: "helm-serve"
	}
	spec: {
		ports: [{
			port:       8879
			protocol:   "TCP"
			targetPort: 8879
		}]
		selector app: "helm-serve"
	}
}

ingress = {
	apiVersion: "networking.k8s.io/v1beta1"
	kind:       "Ingress"
	metadata: {
		name: "test-ingress"
		annotations "kubernetes.io/ingress.class": "nginx"
	}
	spec rules: [{
                host: _host.address
		http paths: [{
			backend: {
				serviceName: "helm-serve"
				servicePort: 8879
			}
			path: "/"
		}]
	}]
}

{
	apiVersion: "v1"
	kind:       "List"
	items:
	[
		deployment,
		service,
		ingress,
	]
}
