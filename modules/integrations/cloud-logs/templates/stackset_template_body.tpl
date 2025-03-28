{
  "AWSTemplateFormatVersion": "2010-09-09",
  "Description": "StackSet to configure S3 bucket and KMS permissions for Sysdig Cloud Logs integration",
  "Parameters": {
    "RoleName": {
      "Type": "String",
      "Description": "Name of the role to be created in the bucket account"
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
    },
    "KmsKeyArn": {
      "Type": "String",
      "Description": "ARN of the KMS key used for encryption"
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
    "HasKMSKey": {
      "Fn::Not": [
        {
          "Fn::Equals": [
            {
              "Ref": "KmsKeyArn"
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
                %{ if kms_key_arn != null && kms_key_arn != "" }
                ,
                {
                  "Sid": "KMSDecryptAccess",
                  "Effect": "Allow",
                  "Action": "kms:Decrypt",
                  "Resource": "${kms_key_arn}"
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
