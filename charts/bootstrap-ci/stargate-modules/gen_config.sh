#!/bin/sh

set -e

opa test -v .

kubectl create configmap --from-file=webhooks.rego --from-file=gk.rego --namespace=tekton-pipelines stargate-modules --dry-run -o yaml > ../templates/ci-stargate-config.yaml
