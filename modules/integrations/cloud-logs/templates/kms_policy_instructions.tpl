{
  "Sid": "Sysdig-Decrypt",
  "Effect": "Allow",
  "Principal": {
    "AWS": "${role_arn}"
  },
  "Action": "kms:Decrypt",
  "Resource": "*"
}
