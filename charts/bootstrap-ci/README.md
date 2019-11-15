When gatekeeper cannot be removed, we need to manually remove the finalizer:

    kubectl proxy &
    kubectl get namespace gatekeeper-system -o json |jq '.spec = {"finalizers":[]}' >temp.json
    curl -k -H "Content-Type: application/json" -X PUT --data-binary @temp.json 127.0.0.1:8001/api/v1/namespaces/gatekeeper-system/finalize
