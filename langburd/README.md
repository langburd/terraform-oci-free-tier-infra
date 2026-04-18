# Oracle Free-Tier Infrastructure

This repository contains OpenTofu code to provision resources on the Oracle Cloud Free Tier.
The tenancy is called `langburd` and is located in `eu-frankfurt-1` region.
You can change it using `local.profile_name`.
The resources include a Virtual Cloud Network (VCN), subnets, route tables, security lists, and a compute instance/s.

## Prerequisites

- An Oracle Cloud account with access to the Free Tier
- Oracle Access Key/Secret Key pair that is used for authentication with the Object Storage Service’s Amazon S3 compatible API. Could be [generated](https://docs.oracle.com/en-us/iaas/tools/oci-cli/3.49.3/oci_cli_docs/cmdref/iam/customer-secret-key/create.html) via OCI CLI.
- OpenTofu installed on your local machine

### Generate Oracle Access Key/Secret Key pair

```bash
export OCI_CLI_PROFILE=langburd
oci iam customer-secret-key create \
  --display-name avi@langburd.com \
  --user-id ocid1.user.oc1..aaaaaaaasyvx7c4gqyqvn44uot2vikmx2qzcsrlwq5nqwdennrq5wa5gcgua
```

Get your namespace with the command:

```bash
oci os ns get
```

You will need it to configure the remote backend in the `providers.tf` file.

### Installing OpenTofu

To install OpenTofu:

Visit the official OpenTofu [installation page](https://opentofu.org/docs/intro/install/) and choose the appropriate instruction for your operating system.

Example for Homebrew (Linux or macOS) installation:

```bash
brew update
brew install opentofu
```

Verify the installation by running:

```bash
tofu -version
```

## Usage

1. Clone this repository to your local machine.
2. Navigate to the repository directory.
3. Run `tofu init` to initialize the OpenTofu working directory.
4. Run `tofu plan` to preview the changes that OpenTofu will make.
5. Run `tofu apply` to create the resources on Oracle Cloud.

## Cleanup

To remove the resources created by this OpenTofu configuration, run `tofu destroy`.
