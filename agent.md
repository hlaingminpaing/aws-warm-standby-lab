# AI Agent Instructions for `aws-warm-standby` Repository

## Project Overview
This repository contains a Proof of Concept (POC) for an **AWS Warm Standby** disaster recovery architecture, deployed via Terraform. 
The architecture simulates an active-passive failover scenario using:
- **Two Regions**: Primary (Active) and Standby (Inactive).
- **Route 53**: Active-Passive failover routing with health checks on ALBs.
- **Auto Scaling Groups (ASG)**: 
  - Primary ASG scales to normal load (desired capacity 2).
  - Standby ASG acts as the "warm standby", scaled down (desired capacity 1).
- **Aurora Global Database (MySQL)**: Cross-region asynchronous replication. Standby is a read-only replica until promoted.

## Repository Structure
- **`providers.tf` / `variables.tf`**: Basic configuration, credentials, and dual-region aliases (`primary` and `standby`).
- **`network.tf`**: VPC infrastructure using the AWS VPC module.
- **`database.tf`**: Aurora Global Database provisioning (`db.t4g.medium` instance classes to save cost).
- **`compute.tf`**: ALBs, Target Groups, Launch Templates, and Auto Scaling Groups.
- **`route53.tf`**: Failover DNS and Health Check routing.
- **`app_userdata.sh.tpl`**: Cloud-init template used by the Launch Templates to bootstrap the EC2 instances. It provisions Node.js, dynamically injects the app code, configures environment variables mapping to the local region's DB endpoint, and starts the systemd service.
- **`app/`**: A mock Node.js Express application that renders a visual UI and interacts with the database to prove connectivity, region awareness, and test read/write database constraints.

## Constraints & Rules for AI Agents
1. **Cost Optimization**: Do not increase instance sizes. The database instances are `db.t4g.medium` because it is the smallest and cheapest instance type supported by Aurora MySQL 3.0 Global Databases. Do not change them to smaller types like `t3.small` as the AWS API will reject them.
2. **Architecture Diagram Adherence**: The user has based this on an AWS diagram. The frontend and application tiers were combined into a single ASG layer to keep the POC "simple". If expanding the architecture, note this intentional combination.
3. **Database States**: The app (`app/server.js`) expects the Standby database to be Read-Only. Do not alter the app to try and force writes on the standby DB unless providing steps to detach/promote the standby database.
4. **Terraform**: Ensure `terraform fmt` is executed after altering `.tf` files.
