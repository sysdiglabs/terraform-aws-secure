IMPORTANT: MANUAL ACTION REQUIRED

Add the following statement to the KMS key policy used by CloudTrail
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
