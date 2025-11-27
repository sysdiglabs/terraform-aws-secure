Add the following bucket policy in Sysdig S3 storage:
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::<BUCKET_NAME>/response-actions/cloud-lambdas/*"
        }
    ]
}
```

and disable block public access.

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
