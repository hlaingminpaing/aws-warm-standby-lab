# Skills & Operational Routines

This document outlines the technical skills required to manage this repository, as well as specific operational "skills" or routines that human operators or AI agents should use when working with this AWS Warm Standby POC.

## 🛠️ Required Technical Skills
To fully understand and extend this project, the following skills are utilized:
- **HashiCorp Terraform (HCL)**: For declarative infrastructure-as-code management.
- **AWS Architecture**: Deep understanding of VPCs, Application Load Balancers, Auto Scaling Groups, and Route 53 Failover Routing.
- **Amazon Aurora Global Databases**: Understanding of cross-region asynchronous replication, cluster promotion, and read-only replica constraints.
- **Linux System Administration**: Use of `cloud-init` / `user_data` to bootstrap Amazon Linux instances, manage systemd services, and install dependencies.
- **Node.js & Express**: Basic backend web development to maintain the mock test application.

---

## 🤖 Operational Skills (Agent / Operator Routines)

### Skill 1: Deploying the Environment
**Trigger**: When changes are made to `.tf` files or initial setup is requested.
**Routine**:
1. Format code: `terraform fmt`
2. Initialize backend/providers: `terraform init`
3. Validate and review: `terraform plan`
4. Deploy: `terraform apply -auto-approve` (only if thoroughly reviewed)

### Skill 2: Simulating an AZ / Region Failure
**Trigger**: When a disaster recovery test is requested to verify Route 53 Failover.
**Routine**:
1. Navigate to the Primary Region EC2 console.
2. Terminate the active instances running in the `primary-asg` OR update `compute.tf` to set `desired_capacity = 0` for `primary`.
3. Monitor the Route 53 Health Check (attached to the Primary ALB).
4. Verify that within 3 minutes, DNS resolution for the application URL routes traffic to the Standby ALB.

### Skill 3: Promoting the Standby Database
**Trigger**: A true failover has occurred and the Standby region must now accept database writes.
**Routine**:
1. In the AWS RDS Console (or via AWS CLI), navigate to the secondary cluster in the Standby Region.
2. Select **Remove from Global Database**.
3. Once detached, the cluster automatically becomes a standalone, writable Aurora cluster.
4. Update the Standby ASG capacity in `compute.tf` to match production loads (e.g., increase `desired_capacity` from `1` to `2` or higher).

### Skill 4: Local Application Testing
**Trigger**: When UI or backend logic changes are made to `app/server.js`.
**Routine**:
1. Navigate to the app directory: `cd app`
2. Install dependencies: `npm install`
3. Start the local server: `npm run dev`
4. Access via `http://localhost:3000`. *(Note: DB connection will fail locally without an active AWS connection string, but UI will render).*

### Skill 5: Safe Teardown
**Trigger**: When the POC is no longer needed.
**Routine**:
1. Run `terraform destroy`.
2. **Crucial**: Verify in the AWS console that the Aurora Global Database and its associated regional clusters have been fully deleted, as these accrue significant hourly charges.
