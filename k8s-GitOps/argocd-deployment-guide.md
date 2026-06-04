# ArgoCD Deployment Guide for Java Spring Boot Microservices

This guide outlines the step-by-step process of deploying the microservices system to a Kubernetes cluster using ArgoCD, with databases migrated to AWS RDS PostgreSQL.

---

## Prerequisites

1. **Kubernetes Cluster:** A running cluster (e.g., EKS, GKE, AKS, or local Minikube/Kind).
2. **ArgoCD Installed:** ArgoCD installed in the `argocd` namespace.
   - If not installed, run:
     ```bash
     kubectl create namespace argocd
     kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
     ```
3. **AWS RDS PostgreSQL Instance:**
   - Active RDS PostgreSQL instance.
   - Network connectivity enabled between your Kubernetes nodes/pods and your AWS RDS instance (specifically PostgreSQL port `5432` allowed in the RDS Security Group).
4. **Git Repository:** A fork or clone of the GitOps repository (e.g., `https://github.com/Varshil8227/java-microservices-DevOps.git`) where ArgoCD will pull changes from.

---

## Step 1: Pre-create Databases on AWS RDS

PostgreSQL instances do not automatically create database schemas for separate microservices. Connect to your RDS PostgreSQL instance using `psql`, `pgAdmin`, or another client, and run the SQL commands from [aws-rds-postgres-init.sql](file:///d:/DevOps-Projects/fully-completed-microservices-Java-Springboot/k8s-GitOps/aws-rds-postgres-init.sql):

```sql
CREATE DATABASE "order";
CREATE DATABASE "payment";
CREATE DATABASE "product";
```

---

## Step 2: Configure DB Host and Port

Open [configmap.yaml](file:///d:/DevOps-Projects/fully-completed-microservices-Java-Springboot/k8s-GitOps/microservices/configmap.yaml) and update `DB_HOST` with your AWS RDS instance endpoint:

```yaml
DB_HOST: "your-rds-endpoint.xxxxxx.us-east-1.rds.amazonaws.com"
DB_PORT: "5432"
```

---

## Step 3: Deploy Secrets Safely

Since plaintext secrets must not be committed to Git, choose **one** of the following options:

### Option A: Manual Secret Creation (Easiest & Quickest)
If you don't want to install extra operators:
1. Open [secrets.yaml](file:///d:/DevOps-Projects/fully-completed-microservices-Java-Springboot/k8s-GitOps/microservices/secrets.yaml) and encode your actual RDS credentials, SMTP settings, and MongoDB URIs into Base64.
   - On Linux/macOS/Git Bash: `echo -n "my-db-password" | base64`
   - On PowerShell: `[System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("my-db-password"))`
2. Update the credentials in `secrets.yaml`:
   ```yaml
   DB_USERNAME: <base64-username>
   DB_PASSWORD: <base64-password>
   ```
3. Apply the secrets directly to the Kubernetes cluster using `kubectl`:
   ```bash
   kubectl apply -f k8s-GitOps/microservices/secrets.yaml
   ```
4. **Important:** Add `k8s-GitOps/microservices/secrets.yaml` to `.gitignore` and delete it from your remote Git repository to ensure it's never committed.
   ```bash
   git rm --cached k8s-GitOps/microservices/secrets.yaml
   echo "k8s-GitOps/microservices/secrets.yaml" >> .gitignore
   git commit -m "Ignore plaintext secrets file"
   ```

### Option B: Sealed Secrets (Pure GitOps)
If you want to keep encrypted secrets in Git:
1. Install Bitnami Sealed Secrets in the cluster:
   ```bash
   helm repo add sealed-secrets https://bitnami-charts.github.io/sealed-secrets
   helm install sealed-secrets-controller sealed-secrets/sealed-secrets -n kube-system
   ```
2. Seal the secret using the `kubeseal` CLI tool:
   ```bash
   kubeseal --controller-namespace=kube-system --format yaml < k8s-GitOps/microservices/secrets.yaml > k8s-GitOps/microservices/sealed-secrets.yaml
   ```
3. Commit and push `sealed-secrets.yaml` to your Git repository. The Sealed Secrets controller inside the cluster will automatically decrypt it and generate standard Kubernetes secrets.

---

## Step 4: Build, Tag, and Push Microservice Images

Kubernetes needs to download your microservice container images. Build and push the images to a container registry (e.g., Docker Hub, AWS ECR, or GitHub Container Registry):

1. **Log in to your registry:**
   ```bash
   docker login
   ```
2. **Build and push each service:**
   For example, for the config-server and product-service:
   ```bash
   # Config Server
   docker build -t your-username/config-server:latest services/config-server
   docker push your-username/config-server:latest

   # Product Service
   docker build -t your-username/product-service:latest services/product
   docker push your-username/product-service:latest
   ```
   *(Repeat this build-and-push process for all 8 folders under the `services/` directory).*

3. **Update image fields in deployments:**
   Go to the `k8s-GitOps/microservices/` directory and modify each `*-deployment.yaml` file to use your pushed images:
   ```yaml
   # Example in product-service-deployment.yaml
   spec:
     containers:
       - name: product-service
         image: your-username/product-service:latest
   ```

---

## Step 5: Register Applications in ArgoCD

1. **Fork/Commit and Push:** Ensure all configuration and image changes (including the updated `configmap.yaml` and deployment files) are committed and pushed to your Git repository on GitHub.
2. **Update Repo URL in ArgoCD manifests:**
   Open the files in `k8s-GitOps/argocd/`:
   - [application-infrastructure.yaml](file:///d:/DevOps-Projects/fully-completed-microservices-Java-Springboot/k8s-GitOps/argocd/application-infrastructure.yaml)
   - [application-microservices.yaml](file:///d:/DevOps-Projects/fully-completed-microservices-Java-Springboot/k8s-GitOps/argocd/application-microservices.yaml)
   Change the `repoURL` value (currently `https://github.com/Varshil8227/java-microservices-DevOps.git`) to your personal Git repository URL.
3. **Apply the ArgoCD Applications:**
   ```bash
   kubectl apply -f k8s-GitOps/argocd/application-infrastructure.yaml
   kubectl apply -f k8s-GitOps/argocd/application-microservices.yaml
   ```

ArgoCD will automatically discover the two applications and start reconciling them:
- **`microservices-infrastructure`:** Deploys Kafka, MongoDB, Maildev, and Zipkin.
- **`microservices-apps`:** Deploys the 8 Spring Boot microservices, reading the database configurations from the updated ConfigMap and pulling sensitive variables from the Kubernetes Secret.

---

## Step 6: Verify and Connect

1. **Check Sync Status:**
   Access the ArgoCD UI dashboard or check sync status via CLI:
   ```bash
   kubectl get pods -n default
   ```
2. **Verify DB Connections (Flyway/Hibernate):**
   Examine the logs of `product-service` to confirm that it successfully connects to AWS RDS and runs Flyway migrations:
   ```bash
   kubectl logs -l app=product-service -n default -c product-service --tail=200
   ```
   You should see logs indicating successful Flyway schema migrations and Spring Boot database connections.

3. **Access API Gateway:**
   Use port-forwarding to route traffic to the API Gateway on your local machine:
   ```bash
   kubectl port-forward svc/gateway-service 8222:8222
   ```
   You can now send requests to `http://localhost:8222/api/v1/...` to interact with the entire microservice suite.
