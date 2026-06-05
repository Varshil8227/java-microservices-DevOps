#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "================ STARTING DEVOPS AUTOMATION INFRASTRUCTURE ================"
apt-get update -y && apt-get upgrade -y

# ૧. ઇન્સ્ટોલ કરો જરૂરી ડિપેન્ડન્સીસ અને Docker
apt-get install -y git curl wget ca-certificates apt-transport-https gnupg lsb-release docker.io postgresql-client postgresql-contrib

systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu

# ૨. Kubectl, Kind, Helm, અને Kubeseal ઇન્સ્ટોલ કરો
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && mv kubectl /usr/local/bin/

curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.24.0/kind-linux-amd64
chmod +x ./kind && mv ./kind /usr/local/bin/kind

wget https://get.helm.sh/helm-v3.14.4-linux-amd64.tar.gz
tar -zxvf helm-v3.14.4-linux-amd64.tar.gz && mv linux-amd64/helm /usr/local/bin/helm && chmod +x /usr/local/bin/helm

curl -LO https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.26.0/kubeseal-0.26.0-linux-amd64.tar.gz
tar -xvzf kubeseal-0.26.0-linux-amd64.tar.gz && install -m 755 kubeseal /usr/local/bin/kubeseal

# ⚠️ કાઇન્ડ ક્લસ્ટર કનેક્શન માટે પરમેનન્ટ એન્વાયરમેન્ટ સેટ કરો
export KUBECONFIG=/root/.kube/config

# ૩. ક્રિએટ કરો KIND Cluster વિથ ઇનબાઉન્ડ પોર્ટ મેપિંગ (ઇન્ગ્રેસ માટે આ કમ્પલસરી છે)
cat <<EOF > /root/kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  image: kindest/node:v1.30.0
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
  image: kindest/node:v1.30.0
- role: worker
  image: kindest/node:v1.30.0
EOF

echo "Creating Kind Cluster..."
kind create cluster --config /root/kind-config.yaml --kubeconfig /root/.kube/config

# કન્ફિગરેશન કોપી કરો યુઝર હોમમાં પણ
mkdir -p /home/ubuntu/.kube
cp /root/.kube/config /home/ubuntu/.kube/config
chown -R ubuntu:ubuntu /home/ubuntu/.kube

# ૪. ક્લસ્ટર કંટ્રોલ પ્લેન રેડી થવાની રાહ જુઓ
echo "Waiting for core cluster components..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# ૫. NGINX Ingress Controller (Kind Specific) ડિપ્લોય કરો
echo "Deploying Kind-Optimized NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# ૬. ArgoCD ઇન્સ્ટોલેશન અને ઓટોમેશન
echo "Deploying ArgoCD..."
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for ArgoCD Server to be ready..."
kubectl wait --namespace argocd --for=condition=ready pod -l app.kubernetes.io/name=argocd-server --timeout=300s

# ArgoCD ઇન્ગ્રેસ હેલ્થ પેચ (જે કમાન્ડ તેં રન કર્યો હતો તે કાયમ માટે સેટ કરો)
kubectl patch cm argocd-cm -n argocd --type merge -p "$(cat <<EOF
{
  "data": {
    "resource.customizations.health.networking.k8s.io_Ingress": "hs = {}\nif obj.status ~= nil and obj.status.loadBalancer ~= nil then\n  hs.status = \"Healthy\"\n  hs.message = \"Ingress is Healthy\"\n  return hs\nend\nhs.status = \"Healthy\"\nreturn hs"
  }
}
EOF
)"

# ArgoCD એક્સપોઝ કરો પોર્ટ 8081 પર
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'
nohup kubectl port-forward -n argocd service/argocd-server 8081:443 --address=0.0.0.0 > /dev/null 2>&1 &

# ૭. Sealed Secrets કંટ્રોલર અને સર્ટિફિકેટ જનરેશન ઓટોમેશન
echo "Deploying Sealed Secrets..."
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm repo update
helm install sealed-secrets-controller sealed-secrets/sealed-secrets -n kube-system

echo "Waiting for Sealed Secrets Controller..."
kubectl wait --namespace kube-system --for=condition=ready pod -l app.kubernetes.io/name=sealed-secrets --timeout=120s

# ક્લસ્ટરમાંથી પબ્લિક સર્ટિફિકેટ ઓટોમેટિક ખેંચીને ફાઇલ બનાવો
kubeseal --controller-name=sealed-secrets-controller --controller-namespace=kube-system --fetch-cert > /root/my-cluster-key.pem
cp /root/my-cluster-key.pem /home/ubuntu/my-cluster-key.pem
chown ubuntu:ubuntu /home/ubuntu/my-cluster-key.pem

