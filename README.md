# AWS Warm Standby Lab POC

This repository contains a simple, automated lab environment using Terraform to provision an AWS Warm Standby architecture, matching the provided architectural diagram.

## Architecture Overview

The "Warm Standby" architecture ensures a scaled-down but fully functional version of your environment is always running in a secondary region. When a disaster occurs, the secondary region is scaled up to handle production traffic.

### Components Built by this POC:

1. **Two AWS Regions**: 
   - Primary (Active): Full capacity.
   - Secondary (Inactive/Standby): Minimal running instances.
2. **Route 53**: Active-Passive Failover routing. Traffic routes to the Active region unless the health check fails, at which point it automatically flips to the Inactive region.
3. **Elastic Load Balancing (ALB)**: Application Load Balancers distributed in public subnets of both regions.
4. **Auto Scaling Groups**: 
   - **Primary**: Runs with `desired_capacity = 2` to handle standard production loads.
   - **Standby**: Runs with `desired_capacity = 1` as a "warm" component, ready to be scaled out if traffic fails over.
5. **Amazon Aurora Global Database**:
   - Spans both regions.
   - Asynchronous Cross-Region Replication keeps the standby database updated continuously.
   - The primary region accepts reads and writes, while the standby database handles asynchronous read replicas.
6. **Node.js Test Application**:
   - Deployed dynamically to the EC2 instances via `user_data`.
   - Connects to the local region's Aurora Database endpoint.
   - Displays whether it is running in the Primary or Standby region and allows you to test reading and writing to the database.

## Lab Setup

### Prerequisites
- AWS CLI configured with credentials (`aws configure`).
- Terraform installed (>= v1.5.0).
- An existing Route 53 Public Hosted Zone for your domain (e.g., `example.com`). *If you don't have one, you can comment out the `route53.tf` file or change the routing configuration to just test via the ALB URLs.*

### Steps to Deploy

1. Initialize Terraform:
   ```bash
   terraform init
   ```

2. Review the plan:
   ```bash
   terraform plan
   ```

3. Apply the configuration:
   ```bash
   terraform apply
   ```

### Simulating a Failover

1. Open your browser and navigate to `app.yourdomain.com`. You will see the response from the **Primary Region**.
2. Go to the AWS EC2 Console in your primary region and terminate the instances, or manually scale the primary Auto Scaling group down to 0 to simulate a failure.
3. Wait for the Route 53 health check to detect the failure (approx. 2-3 minutes).
4. Refresh your browser at `app.yourdomain.com`. You should now see the response from the **Standby Region**.
5. Once the failover completes, you can manually update the Standby ASG to increase the `desired_capacity` to match production loads. For the Aurora Database, you would detach the secondary cluster from the global cluster and promote it to an independent cluster to accept writes.

## Cleanup

To avoid ongoing charges (especially for the Aurora Global Database and ALBs):

```bash
terraform destroy
```

---

## 🛠️ Manual Deployment Guide (AWS Console)

If you prefer to build this architecture manually without Terraform to better understand the AWS Management Console, follow these steps corresponding to the architectural diagram:

### Step 1: Networking Setup (Both Regions)
1. Navigate to the **VPC Console** in your Primary Region.
2. Click **Create VPC** and select "VPC and more" to easily generate Public and Private subnets across 2 Availability Zones. Include a NAT Gateway.
3. Switch to your Standby Region and repeat the process to create an identical network.

### Step 2: Aurora Global Database
1. Navigate to the **RDS Console** in your Primary Region.
2. Click **Create database**, select **Amazon Aurora** (MySQL or PostgreSQL compatibility).
3. Under the "Availability and durability" section, select **Global database** and create a primary cluster.
4. Once the primary cluster is active, select it in the RDS dashboard, click **Actions**, and choose **Add region**.
5. Select your Standby Region to create the secondary read-only cluster. AWS will handle the asynchronous cross-region replication automatically.

### Step 3: Application Load Balancers (ALBs)
1. Navigate to the **EC2 Console > Load Balancers** in your Primary Region.
2. Create an **Application Load Balancer** facing the internet (Public Subnets). 
3. Create a Target Group (HTTP on Port 80) and attach it to the ALB Listener.
4. Switch to your Standby Region and repeat this process.

### Step 4: Auto Scaling Groups & Compute
1. Navigate to **EC2 Console > Launch Templates**.
2. Create a Launch Template using Amazon Linux. In the **Advanced details > User data** field, copy and paste the Node.js setup script (similar to the logic in `app_userdata.sh.tpl`), ensuring you pass the correct Database Endpoint as environment variables.
3. Navigate to **Auto Scaling Groups** in the Primary Region:
   - Create an ASG using your Launch Template.
   - Set **Desired Capacity = 2** and **Min = 2**.
   - Attach it to the Primary Target Group.
4. Switch to your Standby Region and create an ASG:
   - Set **Desired Capacity = 1** and **Min = 1** (this represents your scaled-down "Warm Standby").
   - Attach it to the Standby Target Group.

### Step 5: Route 53 Active-Passive Failover
1. Navigate to **Route 53 > Health checks**.
2. Create a health check pointing to the DNS name of your Primary ALB.
3. Navigate to **Hosted zones**, select your domain, and click **Create record**.
4. Create the Primary Record:
   - Name: `app.yourdomain.com`
   - Record type: `A - Routes traffic to an IPv4 address`
   - Toggle **Alias** to ON and point it to your **Primary Region ALB**.
   - Routing policy: **Failover**
   - Failover record type: **Primary**
   - Health check ID: Select the health check you created.
5. Create the Secondary Record:
   - Use the exact same name (`app.yourdomain.com`).
   - Toggle **Alias** to ON and point it to your **Standby Region ALB**.
   - Routing policy: **Failover**
   - Failover record type: **Secondary**

You now have a fully functioning manual Warm Standby environment!
