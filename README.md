# Cloud-Native Distributed E-Commerce Microservices Architecture

---

## 🚀 1. Project Description & Core Workflow

This project is an enterprise-grade, highly scalable distributed E-Commerce platform built using a **Java Spring Cloud microservices ecosystem**. The entire continuous delivery pipeline is managed declaratively via **GitOps (ArgoCD)** inside a multi-node **Kubernetes (Kind)** cluster running on an **AWS EC2** instance. 

As your scale and needs run on **EKS cluster** or the use **kubeadm** as needs and configure

The architecture leverages a hybrid communication model: **Synchronous REST communication** via **OpenFeign Clients** for real-time transactions and profile data validation, combined with **Asynchronous Event-Driven Messaging** via **Apache Kafka** to handle notifications and transaction logs reliably without slowing down user interactions.


```

[User Client] ───(HTTPS / Port 443)───> [NGINX Ingress Controller]
│
▼ (Host: ecommerce-microservices.local)
[Gateway Service] (Port 8222)
│
┌─────────────────────────────┼─────────────────────────────┐
▼                             ▼                             ▼
[Customer Service: 8060]      [Order Service: 8090]         [Product Service: 8050]
(MongoDB Atlas)              (AWS RDS Postgres)            (AWS RDS Postgres)
│
▼ (Async Messaging)
[Kafka Broker] (Port 9092)
│
▼
[Notification Service]

```

### ⚙️ Core Technical Workflow:
1. **User Request Routing:** The client submits a secure transaction to `your-domain.com`. The **NGINX Ingress Controller** decrypts the TLS layer and hands it over to the **API Gateway Service**.
   **#** if the user can test also use this command where the gateway-service run **kubectl port-forward svc/gateway-service 8222:8222 --address 0.0.0.0** and also use this and the test on http://EC2_public-IP/8222/api/v1/**any-service**
2. **Order Lifecycle Execution:** The `order-service` validates whether the buyer profile is active by triggering a internal Feign Client fetch to the `customer-service`. Simultaneously, it contacts the `product-service` to check inventory availability.
3. **Event Stream Distribution:** Once the validation returns a success code, the transaction status is updated inside the relational datastore, and a metadata payload event is thrown onto the transactional topic inside **Apache Kafka**.
4. **Asynchronous Processing:** The decoupled `notification-service` acts as a consumer instance on the shared event pipeline, extracting incoming updates to run logging workflows without putting load on main operational execution threads.

---

## 🛠️ 2. Comprehensive Tools & Technologies Inventory

* **Application Framework:** Spring Boot 3.x, Spring Cloud (Gateway, Config Server, Eureka Service Discovery, OpenFeign Clients)
* **Data Layer Architectures:** AWS RDS (PostgreSQL Engine), MongoDB Atlas (NoSQL Document Store)
* **Asynchronous Messaging Hub:** Apache Kafka, Zookeeper
* **Infrastructure as Code (IaC):** Terraform CLI (v1.x)
* **Containerization & Clustering:** Docker Engine, Kind CLI (Kubernetes-in-Docker Cluster Engine)
* **Continuous Delivery Automation (GitOps):** ArgoCD Engine, Helm Package Manager (v3)
* **Security & Secret Vaulting:** Bitnami Sealed Secrets Engine (`kubeseal` CLI), Cert-Manager Controller (Self-Signed TLS Generation)

---

## 📁 3. Repository Directory Structure

```text
java-microservices-DevOps/
├── terraform/                         # Infrastructure as Code (IaC) Layer
│   ├── provider.tf                    # AWS Infrastructure provider configurations
│   ├── variables.tf                   # Declared environment configuration parameters 
│   └── main.tf                        # Master script constructing Security Groups, Key Pairs, & EC2
│   ├── userdata.sh                    # Install all needed tools that requires and configure this
│   ├── terraform.tfvars               # Write real environment configuration parameters 
│   └── outputs.tf                     # output block to give the EC2 public ip and domain
│
├── k8s-GitOps/                        # Continuous Delivery Layer
│   └── microservices/                 # Orchestrated Deployment Components
│       ├── configmap.yaml             # Universal application environment configuration variables
│       ├── secrets.yaml               # Decrypted fallback local credentials (Ignored in Production)
│       ├── sealed-secrets.yaml        # Asymmetrically encrypted cloud secrets safe for Public Git GitOps
│       ├── ingress.yaml               # NGINX reverse routing mapping with integrated local TLS block
│       ├── cluster-issuer.yaml        # Cert-Manager engine configuration tracking self-signed rules
│       ├── config-server.yaml         # Central Spring Configuration Deployment & ClusterIP Service
│       ├── discovery-service.yaml     # Eureka Registry Server Deployment & Service Interface
│       ├── gateway-service.yaml       # Central Edge Router Edge Router Deployment & Service Port 8222
│       ├── customer-service.yaml      # User Accounts Management Pods & Cluster IP
│       ├── product-service.yaml       # Product Inventory Engine Pods & Cluster IP
│       ├── order-service.yaml         # Main Ordering Business Engine Pods & Cluster IP
│       ├── payment-service.yaml       # Transactional Validation Pods & Cluster IP
│       ├── notification-service.yaml  # Asynchronous Kafka Subscriber Operational Consumer Pods
│       └── kafka-zookeeper.yaml       # Native Internal Event Pipeline Pod Engine Manifests
└── README.md                          # Production Operations Documentation

```


## 🗄️ 5. Persistent Databases Provisioning & Cluster Setup

### 🍃 A. MongoDB Atlas Cloud Integration (Customer Service Store)

1. Authenticate into your **MongoDB Atlas Cloud Dashboard** and initiate a shared cluster instance tier.
2. Navigate to **Network Access**, choose **Add IP Address**, and select `0.0.0.0/0` (Allow Access from Anywhere) for testing.
3. Access **Database Access**, set up a user account containing read/write roles, and extract your final connection string payload:
`mongodb+srv://<db_user>:<db_password>@cluster0.example.mongodb.net/customer_db?retryWrites=true&w=majority`
4. This generated string target routing must be updated directly inside your baseline `secrets.yaml` configuration profile prior to executing the sealing sequence.

### 🐘 B. Manual AWS RDS PostgreSQL Provisioning (Product, Order, & Payment Stores)

To avoid manual UI clicks, run this automated AWS CLI command from an authorized terminal to provision a publicly accessible relational database instance:

```bash
aws rds create-db-instance \
    --db-instance-identifier microservices-rds-db \
    --db-instance-class db.t3.micro \
    --engine postgres \
    --allocated-storage 20 \
    --master-username postgres \
    --master-user-password "Ts28bZX8h4pNBdvX" \
    --publicly-accessible \
    --region us-east-1 \
    --no-multi-az

```

#### 🛠️ Executing Schema Database Construction via CLI Client:

Wait approximately 5 minutes for the AWS RDS instance allocation loops to stabilize. Once ready, grab the assigned RDS DB Endpoint from the console and use the native `postgresql-client` to access the master cluster engine:

after manual open the aws rdsa nd the **connectivity & security** tab also use code sniipest after the choose the enviroment for linux windows and macos etc.. and firts download the certificates using given the under 3 commands in linux and the start the postgress db inside you

*Provide Master Password:* `Ts28bZX8h4pNBdvX`

Once authenticated into the interactive shell console prompt interface, execute the following specific relational SQL DDL commands to construct the sub-databases required by the services:

```sql
CREATE DATABASE product;
CREATE DATABASE "order";
CREATE DATABASE payment;

```

*(Note: The `order` keyword represents an internal database system keyword. It must be explicitly wrapped in double quotes to execute without syntax parsing failures).*

---

## 🏗️ 6. Infrastructure Deployment via Terraform

The `terraform/` structural block automates the provisioning of our underlying compute capacity, handling structural firewall security definitions and automated networking routing paths cleanly.

### Execution Plan & Provisioning Commands:

Navigate inside the dedicated infrastructure folder path:

```bash
cd terraform/

```
1. download aws cli in your local pc 
2. First of all go to the aws iam create user also use existing use and the access cli also get the accesskey and secretkey 
3. login to aws cli **aws configure** and the accesskeys and secret keys give and login successfully

Execute initialization to parse cloud components, retrieve remote registry provider blocks, and synchronize internal system variable constraints:

```bash
terraform init

```

Generate an execution output deployment footprint manifest to check configured resource metrics manually:

```bash
terraform plan

```

Instantiate provisioning tasks to launch the network interfaces and virtualize computing instances directly inside your live AWS dashboard workspace:

```bash
terraform apply -auto-approve

```

---

## 🚢 7. Declarative GitOps Deployments Folder Anatomy

The operational scripts located within `k8s-GitOps/microservices/` dictate the complete desired state parameters for our Kubernetes application architecture.

* **`configmap.yaml` & `sealed-secrets.yaml`:** Act as the unified foundational parameter tier initialized before the deployment of any core service containers.
* **Core Microservices Infrastructure (`*-service.yaml`):** Each custom deployment specifies declarative pod constructs containing isolated readiness probes, customized port configuration slots, and unified tracking labels that tie backend systems seamlessly with internal headless cluster routing engines.
* **`kafka-zookeeper.yaml`:** Standard localized message transit system executing without external physical drive attachments, handling ephemeral cluster routing directly over memory resources safely.

---



## 🚀 8. Post-EC2 Provisioning Operational Commands

When the EC2 target compute engine spins up, the embedded automated user-data initialization file constructs the runtime environment layout. Run these specific structural steps inside your operational server space immediately after boot:

### 🎪 A. ArgoCD System Initialization & Admin Dashboard Recovery

ArgoCD is dynamically forwarded over port `8081`. To recover the auto-generated control user password, process this secret decompression command query string:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

```

Navigate your browser to: `http://<YOUR_AWS_EC2_PUBLIC_IP>:8081`

* **Default Username:** `admin`
* **Default Decoded Password:** *(Use the output recovered via the command string above)*

### 🔐 B. Local Asymmetric Encryption Workflow via Kubeseal

To lock environment values safely inside public Git spaces without accidental leakage, execute the `kubeseal` asymmetric compilation command utilizing the public key certificate fetched automatically at boot:

```bash
kubeseal --cert /home/ubuntu/my-cluster-key.pem --format yaml < k8s-GitOps/microservices/secrets.yaml > k8s-GitOps/microservices/sealed-secrets.yaml

```

### 🔒 C. Local DNS Host Mapping & Self-Signed TLS Testing Setup

Because we deploy a local staging environment domain footprint (`ecommerce-microservices.local`), you must append a direct route routing rule targeting your public interface system configuration layout.

Open your local workstation hosts redirection configuration ledger (**Windows:** `C:\Windows\System32\drivers\etc\hosts` | **Linux & macOS:** `/etc/hosts`) and add this mapping line:

```text
<YOUR_AWS_EC2_PUBLIC_IP> ecommerce-microservices.local

```

> **🚨 CRITICAL POSTMAN TESTING CONFIGURATION:** Because this pipeline initializes an automated localized Self-Signed `ClusterIssuer` configuration routine loop to secure communication lines via TLS, you **MUST** navigate to **Postman -> Settings -> General** and explicitly set **`SSL certificate verification`** to **`OFF`**.

#### 👥 1. Create a Customer Profile (POST Request)

* **URL:** `https://ecommerce-microservices.local/api/v1/customers`
* **Headers:** `Content-Type: application/json`
* **JSON Request Payload:**

```json
{
  "id": "cust_001",
  "firstname": "danish",
  "lastname": "Sojitra",
  "email": "danish@example.com",
  "address": {
    "street": "123 Cloud Street",
    "houseNumber": "45-A",
    "zipCode": "360370"
  }
}

```

#### 📦 2. Inject a New Product into Inventory (POST Request)

* **URL:** `https://ecommerce-microservices.local/api/v1/products`
* **JSON Request Payload:**

```json
{
  "name": "DevOps Masterclass Laptop",
  "description": "High performance laptop for Kubernetes & Cloud engineering",
  "availableQuantity": 100,
  "price": 1200.00,
  "categoryId": 1
}

```

# 🌐 Production Domain Configuration

If you are using a real domain name instead of the local testing domain (`ecommerce-microservices.local`), update the Kubernetes Ingress configuration and DNS records accordingly.

---

# 1. Configure DNS

Point your domain or subdomain to your AWS EC2 Public IP or LoadBalancer IP.

Example DNS Record:

| Type | Host                  | Value                 |
| ---- | --------------------- | --------------------- |
| A    | ecommerce.example.com | `<AWS_EC2_PUBLIC_IP>` |

Example:

```text
ecommerce.example.com -> 13.233.xxx.xxx
```

---

# 2. Verify Ingress

```bash
kubectl get ingress
```

Expected Output:

```text
NAME                  HOSTS                    ADDRESS
ecommerce-ingress     ecommerce.example.com    xx.xx.xx.xx
```

---

# 3. Verify HTTPS/TLS

If cert-manager and Let's Encrypt are configured correctly, HTTPS certificates will automatically be issued.

Check certificate:

```bash
kubectl get certificate
```

---

# 4. Production API Testing

## Create Customer

### URL

```text
https://ecommerce.example.com/api/v1/customers
```

### JSON Payload

```json
{
  "id": "cust_001",
  "firstname": "danish",
  "lastname": "Sojitra",
  "email": "danish@example.com",
  "address": {
    "street": "123 Cloud Street",
    "houseNumber": "45-A",
    "zipCode": "360370"
  }
}
```

---

## Create Product

### URL

```text
https://ecommerce.example.com/api/v1/products
```

### JSON Payload

```json
{
  "name": "DevOps Masterclass Laptop",
  "description": "High performance laptop for Kubernetes & Cloud engineering",
  "availableQuantity": 100,
  "price": 1200.00,
  "categoryId": 1
}
```

---

# 5. Important Notes

* No hosts file modification is required for real domains.
* No Postman SSL disable configuration is required if using valid Let's Encrypt certificates.
* Ensure ports `80` and `443` are open in the EC2 Security Group.
* Ensure the domain DNS is fully propagated before testing.


## 🔍 9. Production-Level Monitoring & Diagnostics Playbook

Keep track of system behaviors, state transformations, and operational performance metrics using this diagnostic playbook command list:

* **Real-time Deployment Status Tracking:**
Monitor live health transformations and configuration execution states of your cluster deployments visually:
```bash
kubectl get pods -A -w

```


* **Verify Ingress Traffic Management & Port Bindings:**
Ensure the external reverse-proxy system is bound securely to localized host paths without state conflicts:
```bash
kubectl describe ingress microservices-ingress

```


* **Trace Live Event Bus Pipeline Logs:**
Confirm that messages are flowing properly through the stream processing engine by reading the asynchronous transactional data logs directly:
```bash
kubectl logs -f deployment/notification-service --tail=50

```


* **Diagnose Routing Faults Behind API Gateway:**
Inspect runtime application logs across active core systems if intermediate connection errors occur:
```bash
kubectl logs -f deployment/gateway-service --tail=100

```


* **Force Global App State Sync (GitOps Re-sync):**
If localized resources desynchronize or cache stale configuration metrics, push an immediate deployment reconciliation loop:
```bash
kubectl rollout restart deployment order-service customer-service product-service

```

