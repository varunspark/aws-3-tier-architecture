# AWS 3-Tier Architecture — Transaction App

A highly-available 3-tier web application deployed manually on AWS using the Management Console — no Terraform, no Docker, no Jenkins. Built to demonstrate hands-on understanding of core cloud infrastructure: networking, compute, load balancing, and managed databases.

> 🎯 **Goal of this project:** Show practical, ground-up understanding of AWS networking and security — VPC design, subnetting, security groups, IAM, load balancing, and DNS — entirely through manual provisioning.

The application itself is a simple **"Transactions" demo app**: users can add a transaction (amount + description) through a React frontend, which is saved to a MySQL database via a Node.js API, and the full list is displayed back to them.

---

## 🏗️ Architecture

A highly-available, multi-AZ 3-tier architecture spanning two Availability Zones, with separate public-facing and internal load balancers isolating each tier from the next.

```
                              Route 53 (custom domain)
                                       |
                                       v
                     ┌─────────────────────────────────┐
                     │   External ALB (internet-facing)  │
                     └───────────────┬───────────────────┘
                    ┌────────────────┴────────────────┐
                    v                                   v
         AZ1: public-subnet-1                AZ2: public-subnet-2
         EC2 — Web Tier                       EC2 — Web Tier
         (Nginx + React build)                (Nginx + React build)
                    │                                   │
                    └────────────────┬────────────────┘
                                     v
                     ┌─────────────────────────────────┐
                     │   Internal ALB (private)          │
                     └───────────────┬───────────────────┘
                    ┌────────────────┴────────────────┐
                    v                                   v
       AZ1: private-app-subnet-1          AZ2: private-app-subnet-2
       EC2 — App Tier                      EC2 — App Tier
       (Node.js + Express, port 4000)      (Node.js + Express, port 4000)
                    │                                   │
                    └────────────────┬────────────────┘
                                     v
                     ┌─────────────────────────────────┐
                     │        Amazon RDS (MySQL)         │
                     │     private-db-subnet-1 / 2        │
                     └─────────────────────────────────┘
```

**Why two load balancers?** The external ALB spreads internet traffic across the Web Tier in both AZs. The internal ALB sits between Web Tier and App Tier so the App Tier is never directly internet-reachable — only the Web Tier (via the internal ALB) can talk to it.

**Why two Availability Zones?** If an entire AWS data center (AZ) becomes unavailable, the app keeps running from the other AZ — this is what "high availability" means in practice.

**How the frontend talks to the backend:** the React app calls relative paths like `/api/transaction`. Nginx (on the Web Tier) proxies any `/api/` request to the internal ALB, which forwards it to a healthy App Tier instance on port 4000. The browser never talks to the App Tier directly.

See [`docs/architecture.md`](docs/architecture.md) for the full breakdown and design decisions.

---

## 🧰 Tech Stack & AWS Services

| Layer | Service | Purpose |
|---|---|---|
| Presentation Tier | **EC2 (x2, across 2 AZs) + Application Load Balancer** | Nginx serving a built React app, proxying API calls |
| Application Tier | **EC2 (x2, across 2 AZs) + Internal Application Load Balancer** | Node.js + Express REST API (PM2-managed), port 4000 |
| Database Tier | **Amazon RDS (MySQL)** | Stores `transactions` (id, amount, description) |
| Networking | **Amazon VPC** | 2 public + 2 private-app + 2 private-db subnets across 2 AZs |
| Code Distribution | **Amazon S3** | Staging bucket — EC2 instances pull app code via `aws s3 cp` |
| Security | **IAM Roles & Security Groups** | EC2 role grants S3 read access; SGs scoped per tier |
| DNS | **Amazon Route 53** | Custom domain pointed at the external ALB |
| (Optional) | **AWS Certificate Manager** | HTTPS/SSL on the external ALB |

---

## 📋 Application Features

- Add a transaction (amount + description) via a simple web form
- View all transactions in a table
- Delete all transactions
- `/health` endpoint on both Web Tier (Nginx) and App Tier (Node.js) for load balancer health checks

---

## 📂 Repository Structure

```
aws-3-tier-architecture/
├── README.md
├── docs/
│   ├── architecture.md       # Detailed design + security rationale
│   ├── setup-guide.md        # Full step-by-step deployment guide
│   ├── cleanup.md            # How to tear down resources (avoid charges)
│   └── screenshots/          # Console screenshots per phase
├── application-code/
│   ├── app-tier/
│   │   ├── index.js              # Express API (port 4000)
│   │   ├── TransactionService.js # MySQL queries
│   │   ├── package.json
│   │   └── DbConfig.js.template  # Copy to DbConfig.js on EC2, fill in real creds (gitignored)
│   ├── web-tier/                 # React app (Create React App)
│   │   ├── src/
│   │   └── public/
│   ├── nginx.conf                 # With HTTPS redirect (use once ACM cert is set up)
│   └── nginx-Without-SSL.conf     # Plain HTTP (used in this build)
└── database/
    └── schema.sql                 # MySQL table definition (mirrors what's created manually)
```

---

## 🚀 Deployment Summary

Full instructions: [`docs/setup-guide.md`](docs/setup-guide.md)

1. Create a VPC with 2 public, 2 private-app, and 2 private-db subnets across 2 AZs
2. Create an S3 bucket, upload `application-code/`
3. Create an IAM role (S3 read access) and attach it to EC2 instances
4. Launch an RDS MySQL instance in the private-db subnets, create the `webappdb` database and `transactions` table
5. Launch an App Tier EC2 instance, install Node.js, pull code from S3, configure `DbConfig.js`, run with PM2
6. Create an Internal ALB + Target Group for the App Tier
7. Launch a Web Tier EC2 instance, install Node.js + Nginx, build the React app, configure `nginx-Without-SSL.conf` with the internal ALB's DNS name
8. Create an External ALB + Target Group for the Web Tier
9. Point Route 53 at the External ALB
10. Test: visit the domain, add a transaction, confirm it's stored in RDS

---

## 🔒 Security Notes

- RDS sits in **private DB subnets** with no route to the internet — only the App Tier security group can reach it on port 3306.
- App Tier sits in **private subnets** — only the Web Tier security group (via the Internal ALB) can reach it on port 4000.
- Only the Web Tier (public subnets) and the External ALB are internet-facing.
- Database credentials live only in `DbConfig.js` **on the EC2 instance and in the private S3 bucket** — never committed to this repo (see `.gitignore`).
- IAM role attached to EC2 follows least-privilege (S3 read-only on the code bucket).

---

## 🧹 Cleanup

This architecture is **not fully free-tier eligible** (2x ALB, multiple EC2 instances). See [`docs/cleanup.md`](docs/cleanup.md) for the full teardown order — deleting resources in the wrong order can leave orphaned (and billable) resources like Elastic IPs and NAT Gateways behind.

---

## 📜 License

MIT — free to learn from, fork, and adapt.
