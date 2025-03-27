{
  "AWSTemplateFormatVersion": "2010-09-09",
  "Description": "StackSet to configure S3 bucket and KMS permissions for Sysdig Cloud Logs integration",
  "Parameters": {
    "SysdigRoleArn": {
      "Type": "String",
      "Description": "ARN of the IAM role that needs access to the S3 bucket"
    },
    "BucketAccountId": {
      "Type": "String",
      "Description": "The account id that the bucket resides in"
    },
    "SysdigTrustedIdentity": {
      "Type": "String",
      "Description": "ARN of the Sysdig service that needs to assume the role"
    },
    "SysdigExternalId": {
      "Type": "String",
      "Description": "External ID for secure role assumption by Sysdig"
    }
  },
  "Conditions": {
    "IsBucketAccount": {
      "Fn::Equals": [
        {
          "Ref": "AWS::AccountId"
        },
        {
          "Ref": "BucketAccountId"
        }
      ]
    },
    "HasKMSKeys": {
      "Fn::Not": [
        {
          "Fn::Equals": [
            {
              "Fn::Join": ["", ${jsonencode(kms_key_arns != null ? kms_key_arns : [""])}]
            },
            ""
          ]
        }
      ]
    }
  },
  "Resources": {
    "S3AccessRole": {
      "Type": "AWS::IAM::Role",
      "Condition": "IsBucketAccount",
      "Properties": {
        "RoleName": "sysdig-secure-s3-access-${bucket_name}",
        "AssumeRolePolicyDocument": {
          "Version": "2012-10-17",
          "Statement": [
            {
              "Effect": "Allow",
              "Principal": {
                "AWS": {
                  "Ref": "SysdigRoleArn"
                }
              },
              "Action": "sts:AssumeRole"
            },
            {
              "Effect": "Allow",
              "Principal": {
                "AWS": {
                  "Ref": "SysdigTrustedIdentity"
                }
              },
              "Action": "sts:AssumeRole",
              "Condition": {
                "StringEquals": {
                  "sts:ExternalId": {
                    "Ref": "SysdigExternalId"
                  }
                }
              }
            }
          ]
        },
        "Policies": [
          {
            "PolicyName": "S3BucketAccess",
            "PolicyDocument": {
              "Version": "2012-10-17",
              "Statement": [
                {
                  "Sid": "S3BucketListAccess",
                  "Effect": "Allow",
                  "Action": [
                    "s3:ListBucket",
                    "s3:GetBucketLocation"
                  ],
                  "Resource": [
                    "${bucket_arn}"
                  ]
                },
                {
                  "Sid": "S3ObjectAccess",
                  "Effect": "Allow",
                  "Action": [
                    "s3:GetObject"
                  ],
                  "Resource": [
                    "${bucket_arn}/*"
                  ]
                }
                %{ if kms_key_arns != null }
                ,
                {
                  "Sid": "KMSDecryptAccess",
                  "Effect": "Allow",
                  "Action": "kms:Decrypt",
                  "Resource": ${jsonencode(kms_key_arns)}
                }
                %{ endif }
              ]
            }
          }
        ],
        "Tags": [
          {
            "Key": "Name",
            "Value": "Sysdig Secure CloudTrail Logs Access Role"
          },
          {
            "Key": "Purpose",
            "Value": "Allow Sysdig to access S3 bucket for CloudTrail logs"
          }
        ]
      }
    }
  },
  "Outputs": {
    "S3AccessRoleArn": {
      "Description": "ARN of the IAM role created in the bucket account for S3 access",
      "Condition": "IsBucketAccount",
      "Value": {
        "Fn::GetAtt": [
          "S3AccessRole",
          "Arn"
        ]
      }
    }
  }
}