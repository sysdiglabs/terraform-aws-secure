IMPORTANT: MANUAL ACTION REQUIRED

Please add the following statement to your KMS key policy to allow Sysdig to decrypt logs.
This is necessary when KMS encryption is enabled for your S3 bucket.
Without this policy addition, Sysdig may not be able to read your encrypted logs.

{
  "Sid": "Sysdig-Decrypt",
  "Effect": "Allow",
  "Principal": {
    "AWS": "${role_arn}"
  },
  "Action": "kms:Decrypt",
  "Resource": "*"
}
