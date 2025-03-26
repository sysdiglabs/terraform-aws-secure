{
  "AWSTemplateFormatVersion": "2010-09-09",
  "Description": "StackSet to configure S3 bucket and KMS permissions for Sysdig Cloud Logs integration",
  "Parameters": {
    "TrustedIdentity": {
      "Type": "String",
      "Description": "ARN of the Sysdig service that needs to assume the role"
    },
    "ExternalId": {
      "Type": "String",
      "Description": "External ID for secure role assumption"
    },
    "BucketAccountId": {
      "Type": "String",
      "Description": "The account id that the bucket resides in"
    },
    "RoleName": {
      "Type": "String",
      "Description": "Name of the role to create in the bucket account"
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
        "RoleName": {
          "Ref": "RoleName"
        },
        "AssumeRolePolicyDocument": {
          "Version": "2012-10-17",
          "Statement": [
            {
              "Effect": "Allow",
              "Principal": {
                "AWS": {
                  "Ref": "TrustedIdentity"
                }
              },
              "Action": "sts:AssumeRole",
              "Condition": {
                "StringEquals": {
                  "sts:ExternalId": {
                    "Ref": "ExternalId"
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
                  "Effect": "Allow",
                  "Action": [
                    "s3:GetObject",
                    "s3:ListBucket"
                  ],
                  "Resource": [
                    "${bucket_arn}",
                    "${bucket_arn}/*"
                  ]
                }
                %{ if kms_key_arns != null }
                ,
                {
                  "Effect": "Allow",
                  "Action": "kms:Decrypt",
                  "Resource": ${jsonencode(kms_key_arns)}
                }
                %{ endif }
              ]
            }
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