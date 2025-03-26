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