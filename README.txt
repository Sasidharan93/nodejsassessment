SECURE DEPLOYMENT OF CONTAINERIZED NODE.JS APPLICATION ON GCP USING DEVSECOPS PRINCIPLES
========================================================================================

This repo contains a Node.js REST API backed by PostgreSQL, deployed to Google Cloud Run through a CI/CD pipeline built with GitHub
Actions and Terraform. The main goal of this assignment was not really the app itself but the infrastructure and pipeline around it like
private networking, secret management, IAM with least-privilege, vulnerability scanning, and monitoring/alerting, all provisioned as code.


Structure and File in this Repo:
--------------------------------

app/                    - the Node.js/Express REST API and its Dockerfile
terraform/              - all infrastructure, split into modules network, cloud-sql, secrets, iam, cloud-run,
                          monitoring, and wif
.github/workflows/      - CI and CD pipelines


Architecture
------------

Here's how a deploy flows through the system:

1) Developer pushes to main
    -> GitHub Actions CI
         - lint (ESLint)
         - unit tests (Jest)
         - npm audit + Trivy scans
         - terraform fmt / validate / tflint
    -> (only if CI passes) GitHub Actions CD
         - authenticates to GCP via Workload Identity Federation (no keys)
         - builds Docker image
         - pushes image to Artifact Registry
         - deploys new image to Cloud Run
    -> Cloud Run service (runs under a minimal-privilege service account)
         - connects only through a VPC connector
    -> Cloud SQL PostgreSQL
         - private IP only, lives inside the VPC, no public IP at all

2) Secret Manager holds the DB host/user/password/name and injects them into Cloud Run as environment variables at deploy time - they are never
hardcoded anywhere in the code or the pipeline.

3) Everything except the app code itself (Cloud Run, Cloud SQL, VPC, secrets, IAM, monitoring) is provisioned through Terraform, split into
modules under terraform/modules/.


Setup & Deployment Steps
---------------------------

The order I actually followed:

1. Create a GCP project and enable billing. I used the free trial
   credits for this.

2. Enable the required APIs:

   gcloud services enable run.googleapis.com sqladmin.googleapis.com \
     compute.googleapis.com vpcaccess.googleapis.com \
     secretmanager.googleapis.com artifactregistry.googleapis.com \
     iam.googleapis.com cloudresourcemanager.googleapis.com \
     monitoring.googleapis.com logging.googleapis.com \
     servicenetworking.googleapis.com

I actually forgot this step the first time and my first "terraform apply" failed on half the resources with "API not enabled" errors had to enable them and re-run.

3. Clone the repo and set my project variables in terraform/environments/dev.tfvars (copy from dev.tfvars.example and
   fill in my own project ID, alert email, and Chat webhook URL.

4. Provision the infrastructure:

   cd terraform
   terraform init
   terraform fmt -recursive
   terraform validate
   terraform plan -var-file="environments/dev.tfvars"
   terraform apply -var-file="environments/dev.tfvars"

   This creates the VPC, subnet, VPC connector, Cloud SQL instance, Secret Manager secrets, two IAM service accounts, Artifact Registry repo, Cloud Run service, 
   the Workload Identity Federation pool/provider, and the monitoring alert policies.

5. Set up GitHub Actions. No secrets need to be added manually on the GitHub side for GCP auth - that's the point of Workload Identity
   Federation. The "terraform output workload_identity_provider" and "terraform output deployer_sa_email" values are already hardcoded
   into cd.yml for this specific project/repo pairing.

6. Push to main. This triggers CI (lint, test, security scans, terraform checks). If CI passes, CD automatically triggers, builds the real app image, 
   pushes it to Artifact Registry, and deploys it to Cloud Run, replacing the placeholder.

7. The app creates its own database table on startup (CREATE TABLE IF NOT EXISTS items ... runs when the container boots), so there's no separate manual migration step needed for
   this simple schema.


Security measures taken here
----------------------------

So what I actually did and why: with reason and good practice

1. No public IP on the database. Cloud SQL is provisioned with ipv4_enabled = false and only a private IP inside the VPC. There is genuinely no way to 
reach it from the public internet -  only Cloud Run, through the VPC connector, can get to it. I confirmed this by trying to connect to it directly from Cloud Shell 
(which sits outside the VPC) and it correctly failed - I actually hit this while debugging, which ended up being a good real-world confirmation that the 
isolation works as intended.

2. Two separate service accounts, not one. I split IAM into a runtime identity and a deploy identity instead of using one account (personal account / Owner)

  - nodejs-devsecops-run-sa: used by the actual running container.
    Only has secretmanager.secretAccessor, cloudsql.client,
    artifactregistry.reader, logging.logWriter, and
    monitoring.metricWriter.

  - nodejs-devsecops-deployer: used only by GitHub Actions to
    build/push/deploy. Only has run.admin and artifactregistry.writer,
    plus permission to act as the runtime SA when deploying.

    (No Owner, Editor, or Viewer role is used anywhere in this project)

3. Workload Identity Federation instead of a service account key. GitHub Actions authenticates to GCP using OIDC token exchange (google-github-actions/auth@v2), 
not a downloaded JSON key. The WIF provider's attribute_condition is locked to this exact GitHub repo, so even if someone knew the deployer service account's email, no other
repo could impersonate it.

4. Secrets never touch code, images, or logs. DB host/user/password/name all live in Secret Manager and are injected into Cloud Run as environment variables at 
deploy time via secret_key_ref. They're never in .env files committed to git (.gitignore excludes .env and the Terraform state file, which would otherwise leak 
the DB password in plaintext).

5. CI fails the build on real vulnerabilities. The pipeline runs npm audit and Trivy (both source-level and against the built Docker image) with exit-code: 1,
meaning a CRITICAL/HIGH finding actually blocks the pipeline instead of just printing a warning. Trivy genuinely caught real CVEs during development:

  - A vulnerable "tar" package pulled in as a transitive dependency
    (fixed with an npm "overrides" entry).


6. Minimal, non-root Docker image. The Dockerfile is a multi-stage build - dev dependencies and build tooling never make it into the final image, it runs as the non-root
"node" user, and it's based on node:22-alpine to keep the base OS surface small.

7. Firewall rules default-deny. The VPC has an explicit rule allowing only internal traffic on the Postgres port between the subnet and the VPC connector range, plus a
lower-priority deny-all-ingress rule as a backstop.


My Assumption in this setup as as good practice
-----------------------------------------------

- Region: everything is deployed in asia-south1 since that's closest to me; there's no technical reason it couldn't be any other region as long as 
  it's consistent across modules.

- Cloud SQL deletion protection is off (deletion_protection = false), and it's a db-f1-micro single-zone instance. That's appropriate for an assignment environment
  where I need to be able to tear things down; in a real production setup I'd flip deletion protection on and likely use a REGIONAL availability type for HA.

- Cloud Run allows unauthenticated public access. I made this choice because the assignment describes a REST API and testing/grading is easier against a public URL. 
  If this were meant to be an internal-only service, I'd remove the public IAM binding and put it behind either Identity-Aware Proxy or restrict ingress to
  internal traffic only.

- The database table is created by the app on startup rather than through a separate migration tool, since the schema here is a single trivial table. 
  For anything beyond this scale I'd use a real migration tool instead of an inline CREATE TABLE IF NOT EXISTS.

- Google Chat webhook - known limitation. Google Chat's incoming webhook feature requires a paid Google Workspace account; my personal Gmail account hit a 
  hard "Webhook management is restricted" wall when I tried to set one up. The google_monitoring_notification_channel resource for Chat is fully implemented in
  terraform/modules/monitoring/main.tf and would work correctly given a real webhook URL from a Workspace account - I used a placeholder URL so Terraform could 
  still provision the channel resource itself. Email alerting is fully implemented and functional, since it only needed a normal email address.


Alerting Setup
---------------

Monitoring is built entirely in Terraform (terraform/modules/monitoring/):

- A log-based metric counts 5xx responses coming from the Cloud Run service, filtered on resource.type = "cloud_run_revision" and httpRequest.status >= 500.

- Four alert policies, one pair each for CPU and memory:

    -> 70% utilization -> routes to the Google Chat notification channel (as a warning)
    -> 80% utilization sustained across consecutive datapoints (I used a 180 second duration window rather than a single spike) -> routes to the email notification 
       channel (as a critical)

I used two separate thresholds so a brief spike doesn't page anyone unnecessarily, but a sustained overload does escalate to something more visible (email) than a
Chat message someone might miss.

One thing worth flagging: while building the alert policies, GCP's Cloud Run CPU/memory utilization metrics turned out to be DELTA/DISTRIBUTION type metrics, 
not simple gauges, so the aligner I first used (ALIGN_MEAN) was actually invalid for this metric type - GCP rejected it outright at terraform apply time. Switched to
ALIGN_PERCENTILE_99, which is the standard aligner for this kind of Cloud Run metric, and that resolved it.


Known issue & Limitations
------------------------------

- Google Chat webhook (explained above) - this is an account-tier limitation, not a gap in the Terraform code.

- This is a single, small environment, not a multi-environment setup. terraform/environments/dev.tfvars is the only environment file. Extending this to 
  multiple environments would mean parameterizing further and probably moving to remote Terraform state (currently state is local, which is fine for an assignment but
  wouldn't be for a team).
