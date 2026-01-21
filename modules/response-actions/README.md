For testing, create `provisioning.tf`, with:

```
provider "sysdig" {
  sysdig_secure_url       = "<Sysdig endpoint>"
  sysdig_secure_api_token = "<Sysdig API key>"
}

provider "aws" {
  region              = "us-east-1"
}
```
