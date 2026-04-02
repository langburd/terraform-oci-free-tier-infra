---
name: tf-plan
description: Run terraform init and plan to preview infrastructure changes. Use when validating infra changes before applying.
disable-model-invocation: true
---

Run a Terraform plan in the specified environment directory. Use $ARGUMENTS to determine which environment (ddyyconsulting or langburd). If not specified, ask the user.

1. `cd <environment_dir>`
2. `terraform init` — initialize with backend
3. `terraform plan` — preview changes

Show the plan output and summarize: resources to add, change, and destroy.
