kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo

to save key in my-cluster-key.pem


kubeseal --controller-namespace=kube-system --fetch-cert > my-cluster-key.pem
cat my-kubeseal --cert my-cluster-key.pem --format yaml < k8s-GitOps/microservices/secrets.yaml > k8s-GitOps/microservices/sealed-secrets.yaml
cluster-key.pem

helm repo update
helm install sealed-secrets-controller sealed-secrets/sealed-secrets -n kube-system
kubeseal --controller-namespace=kube-system --fetch-cert > my-cluster-key.pem


helm repo add sealed-secrets https://bitnami-charts.github.io/sealed-secrets
helm repo update
helm install sealed-secrets-controller sealed-secrets/sealed-secrets -n kube-system