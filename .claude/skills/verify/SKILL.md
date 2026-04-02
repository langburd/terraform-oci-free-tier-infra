---
name: verify
description: Run Terraform formatting check, validation, and docs generation to verify changes are correct. Use before committing or when asked to check work.
---

Run the following verification steps in the current environment directory (ddyyconsulting/ or langburd/):

1. `terraform fmt -check -recursive` — check formatting (fix with `terraform fmt -recursive` if needed)
2. `terraform init -backend=false` — initialize without backend (if .terraform doesn't exist)
3. `terraform validate` — validate configuration
4. `pre-commit run terraform_docs --all-files` — regenerate docs

Report results as a table: step, status (pass/fail), and any error details.
