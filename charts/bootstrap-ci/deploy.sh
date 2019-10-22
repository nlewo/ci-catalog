#!/bin/bash

set -e

helm template --values values.yaml . | kapp deploy -a tekton -y -f -

echo ""
echo "CI is now deployed"
echo ""
echo -n "Dashboard is available at: "
echo "http://$(kubectl -n tekton-pipelines get ingress dashboard-ci-ingress -o="jsonpath={.spec.rules[0].host}")"
echo ""
echo -n "You can add the following webhook on your github projects: "
echo "http://$(kubectl -n tekton-pipelines get ingress el-ci-ingress -o="jsonpath={.spec.rules[0].host}")"
echo -n "With the secret: "
echo "$(kubectl -n tekton-pipelines get secret gh-webhook-secret -o="jsonpath={.data.secret}" | base64 -d)"
