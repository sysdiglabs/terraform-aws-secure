AWSTemplateFormatVersion: '2010-09-09'
Description: 'Sysdig Response Actions Lambda Functions - Multi-Region Deployment'

Parameters:
  ResourceName:
    Type: String
    Description: Base name for all resources
  TemplateVersion:
    Type: String
    Description: Template version hash to force updates
    Default: "1"
  S3BucketName:
    Type: String
    Description: Name for the regional S3 bucket containing Lambda deployment packages
  ApiBaseUrl:
    Type: String
    Description: API base URL for Lambda functions
  PackageDownloaderRoleArn:
    Type: String
    Description: ARN of the IAM role for package downloader function
  QuarantineUserRoleArn:
    Type: String
    Description: ARN of the IAM role for quarantine user function
  FetchCloudLogsRoleArn:
    Type: String
    Description: ARN of the IAM role for fetch cloud logs function
  RemovePolicyRoleArn:
    Type: String
    Description: ARN of the IAM role for remove policy function
  ConfigureResourceAccessRoleArn:
    Type: String
    Description: ARN of the IAM role for configure resource access function
  CreateVolumeSnapshotsRoleArn:
    Type: String
    Description: ARN of the IAM role for create volume snapshots function
  DeleteVolumeSnapshotsRoleArn:
    Type: String
    Description: ARN of the IAM role for delete volume snapshots function
  QuarantineUserRoleName:
    Type: String
    Description: Name of the IAM role for quarantine user function
  FetchCloudLogsRoleName:
    Type: String
    Description: Name of the IAM role for fetch cloud logs function
  RemovePolicyRoleName:
    Type: String
    Description: Name of the IAM role for remove policy function
  ConfigureResourceAccessRoleName:
    Type: String
    Description: Name of the IAM role for configure resource access function
  CreateVolumeSnapshotsRoleName:
    Type: String
    Description: Name of the IAM role for create volume snapshots function
  DeleteVolumeSnapshotsRoleName:
    Type: String
    Description: Name of the IAM role for delete volume snapshots function
  ResponseActionsVersion:
    Type: String
    Description: Version of response actions packages to download
  LambdaPackagesBaseUrl:
    Type: String
    Description: Base URL for downloading Lambda deployment packages
  EnableQuarantineUser:
    Type: String
    Default: "true"
    AllowedValues: ["true", "false"]
    Description: Enable quarantine user and remove policy lambdas
  EnableFetchCloudLogs:
    Type: String
    Default: "true"
    AllowedValues: ["true", "false"]
    Description: Enable fetch cloud logs lambda
  EnableMakePrivate:
    Type: String
    Default: "true"
    AllowedValues: ["true", "false"]
    Description: Enable configure resource access lambda
  EnableCreateVolumeSnapshot:
    Type: String
    Default: "true"
    AllowedValues: ["true", "false"]
    Description: Enable create and delete volume snapshot lambdas

Conditions:
  CreateQuarantineUserResources: !Equals [!Ref EnableQuarantineUser, "true"]
  CreateFetchCloudLogsResources: !Equals [!Ref EnableFetchCloudLogs, "true"]
  CreateMakePrivateResources: !Equals [!Ref EnableMakePrivate, "true"]
  CreateVolumeSnapshotResources: !Equals [!Ref EnableCreateVolumeSnapshot, "true"]

Resources:
  # S3 Bucket for Lambda packages (Regional)
  LambdaPackagesBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub '${S3BucketName}-${AWS::Region}'
      PublicAccessBlockConfiguration:
        BlockPublicAcls: true
        BlockPublicPolicy: true
        IgnorePublicAcls: true
        RestrictPublicBuckets: true
      Tags:
        - Key: 'sysdig.com/response-actions/resource-name'
          Value: 'lambda-packages-bucket'

  # Package Downloader Lambda (per region)
  PackageDownloaderLogGroup:
    Type: AWS::Logs::LogGroup
    DeletionPolicy: Retain
    Properties:
      LogGroupName: !Sub '/aws/lambda/${ResourceName}-package-downloader'
      RetentionInDays: 7
      Tags:
        - Key: 'sysdig.com/response-actions/resource-name'
          Value: 'package-downloader-log-group'

  PackageDownloaderFunction:
    Type: AWS::Lambda::Function
    DependsOn: PackageDownloaderLogGroup
    Properties:
      FunctionName: !Sub '${ResourceName}-package-downloader'
      Runtime: python3.12
      Handler: index.handler
      Role: !Ref PackageDownloaderRoleArn
      Timeout: 300
      MemorySize: 256
      Code:
        ZipFile: |
          import json
          import urllib.request
          import boto3
          import cfnresponse

          def handler(event, context):
              try:
                  print(f"Event: {json.dumps(event)}")

                  if event['RequestType'] == 'Delete':
                      # Clean up S3 object on delete
                      bucket = event['ResourceProperties']['Bucket']
                      key = event['ResourceProperties']['Key']
                      s3 = boto3.client('s3')
                      try:
                          s3.delete_object(Bucket=bucket, Key=key)
                          print(f"Deleted s3://{bucket}/{key}")
                      except Exception as e:
                          print(f"Error deleting object (may not exist): {e}")
                      cfnresponse.send(event, context, cfnresponse.SUCCESS, {})
                      return

                  if event['RequestType'] in ['Create', 'Update']:
                      url = event['ResourceProperties']['Url']
                      bucket = event['ResourceProperties']['Bucket']
                      key = event['ResourceProperties']['Key']

                      print(f"Downloading from {url}")
                      print(f"Target: s3://{bucket}/{key}")

                      # Download from URL
                      try:
                          req = urllib.request.Request(url)
                          with urllib.request.urlopen(req, timeout=60) as response:
                              content = response.read()
                              print(f"Downloaded {len(content)} bytes, status: {response.status}")
                      except urllib.error.HTTPError as e:
                          error_msg = f"HTTP {e.code} downloading {url}: {e.reason}"
                          print(error_msg)
                          cfnresponse.send(event, context, cfnresponse.FAILED, {'Error': error_msg})
                          return
                      except urllib.error.URLError as e:
                          error_msg = f"URL error downloading {url}: {str(e.reason)}"
                          print(error_msg)
                          cfnresponse.send(event, context, cfnresponse.FAILED, {'Error': error_msg})
                          return

                      # Upload to S3
                      try:
                          s3 = boto3.client('s3')
                          s3.put_object(Bucket=bucket, Key=key, Body=content)
                          print(f"Uploaded to s3://{bucket}/{key}")
                      except Exception as e:
                          error_msg = f"S3 upload error: {str(e)}"
                          print(error_msg)
                          cfnresponse.send(event, context, cfnresponse.FAILED, {'Error': error_msg})
                          return

                      cfnresponse.send(event, context, cfnresponse.SUCCESS, {
                          'Bucket': bucket,
                          'Key': key,
                          'Size': len(content)
                      })
                  else:
                      cfnresponse.send(event, context, cfnresponse.SUCCESS, {})

              except Exception as e:
                  import traceback
                  error_msg = f"Unexpected error: {str(e)}\n{traceback.format_exc()}"
                  print(error_msg)
                  cfnresponse.send(event, context, cfnresponse.FAILED, {
                      'Error': str(e)
                  })
      Tags:
        - Key: 'sysdig.com/response-actions/resource-name'
          Value: 'package-downloader-lambda'

  # Custom Resources to download Lambda packages
  QuarantineUserPackage:
    Type: Custom::LambdaPackage
    Condition: CreateQuarantineUserResources
    Properties:
      ServiceToken: !GetAtt PackageDownloaderFunction.Arn
      Url: !Sub '${LambdaPackagesBaseUrl}/v${ResponseActionsVersion}/quarantine_user.zip'
      Bucket: !Ref LambdaPackagesBucket
      Key: !Sub '${ResponseActionsVersion}/quarantine_user.zip'

  FetchCloudLogsPackage:
    Type: Custom::LambdaPackage
    Condition: CreateFetchCloudLogsResources
    Properties:
      ServiceToken: !GetAtt PackageDownloaderFunction.Arn
      Url: !Sub '${LambdaPackagesBaseUrl}/v${ResponseActionsVersion}/fetch_cloud_logs.zip'
      Bucket: !Ref LambdaPackagesBucket
      Key: !Sub '${ResponseActionsVersion}/fetch_cloud_logs.zip'

  RemovePolicyPackage:
    Type: Custom::LambdaPackage
    Condition: CreateQuarantineUserResources
    Properties:
      ServiceToken: !GetAtt PackageDownloaderFunction.Arn
      Url: !Sub '${LambdaPackagesBaseUrl}/v${ResponseActionsVersion}/remove_policy.zip'
      Bucket: !Ref LambdaPackagesBucket
      Key: !Sub '${ResponseActionsVersion}/remove_policy.zip'

  ConfigureResourceAccessPackage:
    Type: Custom::LambdaPackage
    Condition: CreateMakePrivateResources
    Properties:
      ServiceToken: !GetAtt PackageDownloaderFunction.Arn
      Url: !Sub '${LambdaPackagesBaseUrl}/v${ResponseActionsVersion}/configure_resource_access.zip'
      Bucket: !Ref LambdaPackagesBucket
      Key: !Sub '${ResponseActionsVersion}/configure_resource_access.zip'

  CreateVolumeSnapshotsPackage:
    Type: Custom::LambdaPackage
    Condition: CreateVolumeSnapshotResources
    Properties:
      ServiceToken: !GetAtt PackageDownloaderFunction.Arn
      Url: !Sub '${LambdaPackagesBaseUrl}/v${ResponseActionsVersion}/create_volume_snapshots.zip'
      Bucket: !Ref LambdaPackagesBucket
      Key: !Sub '${ResponseActionsVersion}/create_volume_snapshots.zip'

  DeleteVolumeSnapshotsPackage:
    Type: Custom::LambdaPackage
    Condition: CreateVolumeSnapshotResources
    Properties:
      ServiceToken: !GetAtt PackageDownloaderFunction.Arn
      Url: !Sub '${LambdaPackagesBaseUrl}/v${ResponseActionsVersion}/delete_volume_snapshots.zip'
      Bucket: !Ref LambdaPackagesBucket
      Key: !Sub '${ResponseActionsVersion}/delete_volume_snapshots.zip'

  # CloudWatch Log Groups (Regional Resources)
  QuarantineUserLogGroup:
    Type: AWS::Logs::LogGroup
    Condition: CreateQuarantineUserResources
    Properties:
      LogGroupName: !Sub '/aws/lambda/${ResourceName}-quarantine-user'
      RetentionInDays: 7
      Tags:
        - Key: 'sysdig.com/response-actions/resource-name'
          Value: 'quarantine-user-log-group'

  FetchCloudLogsLogGroup:
    Type: AWS::Logs::LogGroup
    Condition: CreateFetchCloudLogsResources
    Properties:
      LogGroupName: !Sub '/aws/lambda/${ResourceName}-fetch-cloud-logs'
      RetentionInDays: 7
      Tags:
        - Key: 'sysdig.com/response-actions/resource-name'
          Value: 'fetch-cloud-logs-log-group'

  RemovePolicyLogGroup:
    Type: AWS::Logs::LogGroup
    Condition: CreateQuarantineUserResources
    Properties:
      LogGroupName: !Sub '/aws/lambda/${ResourceName}-remove-policy'
      RetentionInDays: 7
      Tags:
        - Key: 'sysdig.com/response-actions/resource-name'
          Value: 'remove-policy-log-group'

  ConfigureResourceAccessLogGroup:
    Type: AWS::Logs::LogGroup
    Condition: CreateMakePrivateResources
    Properties:
      LogGroupName: !Sub '/aws/lambda/${ResourceName}-configure-resource-access'
      RetentionInDays: 7
      Tags:
        - Key: 'sysdig.com/response-actions/resource-name'
          Value: 'configure-resource-access-log-group'

  CreateVolumeSnapshotsLogGroup:
    Type: AWS::Logs::LogGroup
    Condition: CreateVolumeSnapshotResources
    Properties:
      LogGroupName: !Sub '/aws/lambda/${ResourceName}-create-volume-snapshots'
      RetentionInDays: 7
      Tags:
        - Key: 'sysdig.com/response-actions/resource-name'
          Value: 'create-volume-snapshots-log-group'

  DeleteVolumeSnapshotsLogGroup:
    Type: AWS::Logs::LogGroup
    Condition: CreateVolumeSnapshotResources
    Properties:
      LogGroupName: !Sub '/aws/lambda/${ResourceName}-delete-volume-snapshots'
      RetentionInDays: 7
      Tags:
        - Key: 'sysdig.com/response-actions/resource-name'
          Value: 'delete-volume-snapshots-log-group'

  # Lambda Functions (Regional Resources)
  QuarantineUserFunction:
    Type: AWS::Lambda::Function
    Condition: CreateQuarantineUserResources
    DependsOn:
      - QuarantineUserLogGroup
      - QuarantineUserPackage
    Properties:
      FunctionName: !Sub '${ResourceName}-quarantine-user'
      Runtime: python3.12
      Handler: app.index.handler
      Role: !Ref QuarantineUserRoleArn
      Code:
        S3Bucket: !Ref LambdaPackagesBucket
        S3Key: !Sub '${ResponseActionsVersion}/quarantine_user.zip'
      Timeout: 300
      MemorySize: 128
      Environment:
        Variables:
          API_BASE_URL: !Ref ApiBaseUrl
          DELEGATE_ROLE_NAME: !Ref QuarantineUserRoleName
      Tags:
        - Key: Name
          Value: !Sub '${ResourceName}-quarantine-user'
        - Key: 'sysdig.com/response-actions/cloud-actions'
          Value: 'true'
        - Key: 'sysdig.com/response-actions/resource-name'
          Value: 'quarantine-user-lambda'

  FetchCloudLogsFunction:
    Type: AWS::Lambda::Function
    Condition: CreateFetchCloudLogsResources
    DependsOn:
      - FetchCloudLogsLogGroup
      - FetchCloudLogsPackage
    Properties:
      FunctionName: !Sub '${ResourceName}-fetch-cloud-logs'
      Runtime: python3.12
      Handler: app.index.handler
      Role: !Ref FetchCloudLogsRoleArn
      Code:
        S3Bucket: !Ref LambdaPackagesBucket
        S3Key: !Sub '${ResponseActionsVersion}/fetch_cloud_logs.zip'
      Timeout: 300
      MemorySize: 128
      Environment:
        Variables:
          API_BASE_URL: !Ref ApiBaseUrl
          DELEGATE_ROLE_NAME: !Ref FetchCloudLogsRoleName
      Tags:
        - Key: Name
          Value: !Sub '${ResourceName}-fetch-cloud-logs'
        - Key: 'sysdig.com/response-actions/cloud-actions'
          Value: 'true'
        - Key: 'sysdig.com/response-actions/resource-name'
          Value: 'fetch-cloud-logs-lambda'

  RemovePolicyFunction:
    Type: AWS::Lambda::Function
    Condition: CreateQuarantineUserResources
    DependsOn:
      - RemovePolicyLogGroup
      - RemovePolicyPackage
    Properties:
      FunctionName: !Sub '${ResourceName}-remove-policy'
      Runtime: python3.12
      Handler: app.index.handler
      Role: !Ref RemovePolicyRoleArn
      Code:
        S3Bucket: !Ref LambdaPackagesBucket
        S3Key: !Sub '${ResponseActionsVersion}/remove_policy.zip'
      Timeout: 300
      MemorySize: 128
      Environment:
        Variables:
          API_BASE_URL: !Ref ApiBaseUrl
          DELEGATE_ROLE_NAME: !Ref RemovePolicyRoleName
      Tags:
        - Key: Name
          Value: !Sub '${ResourceName}-remove-policy'
        - Key: 'sysdig.com/response-actions/cloud-actions'
          Value: 'true'
        - Key: 'sysdig.com/response-actions/resource-name'
          Value: 'remove-policy-lambda'

  ConfigureResourceAccessFunction:
    Type: AWS::Lambda::Function
    Condition: CreateMakePrivateResources
    DependsOn:
      - ConfigureResourceAccessLogGroup
      - ConfigureResourceAccessPackage
    Properties:
      FunctionName: !Sub '${ResourceName}-configure-resource-access'
      Runtime: python3.12
      Handler: app.index.handler
      Role: !Ref ConfigureResourceAccessRoleArn
      Code:
        S3Bucket: !Ref LambdaPackagesBucket
        S3Key: !Sub '${ResponseActionsVersion}/configure_resource_access.zip'
      Timeout: 300
      MemorySize: 128
      Environment:
        Variables:
          API_BASE_URL: !Ref ApiBaseUrl
          DELEGATE_ROLE_NAME: !Ref ConfigureResourceAccessRoleName
      Tags:
        - Key: Name
          Value: !Sub '${ResourceName}-configure-resource-access'
        - Key: 'sysdig.com/response-actions/cloud-actions'
          Value: 'true'
        - Key: 'sysdig.com/response-actions/resource-name'
          Value: 'configure-resource-access-lambda'

  CreateVolumeSnapshotsFunction:
    Type: AWS::Lambda::Function
    Condition: CreateVolumeSnapshotResources
    DependsOn:
      - CreateVolumeSnapshotsLogGroup
      - CreateVolumeSnapshotsPackage
    Properties:
      FunctionName: !Sub '${ResourceName}-create-volume-snapshots'
      Runtime: python3.12
      Handler: app.index.handler
      Role: !Ref CreateVolumeSnapshotsRoleArn
      Code:
        S3Bucket: !Ref LambdaPackagesBucket
        S3Key: !Sub '${ResponseActionsVersion}/create_volume_snapshots.zip'
      Timeout: 300
      MemorySize: 128
      Environment:
        Variables:
          API_BASE_URL: !Ref ApiBaseUrl
          DELEGATE_ROLE_NAME: !Ref CreateVolumeSnapshotsRoleName
      Tags:
        - Key: Name
          Value: !Sub '${ResourceName}-create-volume-snapshots'
        - Key: 'sysdig.com/response-actions/cloud-actions'
          Value: 'true'
        - Key: 'sysdig.com/response-actions/resource-name'
          Value: 'create-volume-snapshots-lambda'

  DeleteVolumeSnapshotsFunction:
    Type: AWS::Lambda::Function
    Condition: CreateVolumeSnapshotResources
    DependsOn:
      - DeleteVolumeSnapshotsLogGroup
      - DeleteVolumeSnapshotsPackage
    Properties:
      FunctionName: !Sub '${ResourceName}-delete-volume-snapshots'
      Runtime: python3.12
      Handler: app.index.handler
      Role: !Ref DeleteVolumeSnapshotsRoleArn
      Code:
        S3Bucket: !Ref LambdaPackagesBucket
        S3Key: !Sub '${ResponseActionsVersion}/delete_volume_snapshots.zip'
      Timeout: 300
      MemorySize: 128
      Environment:
        Variables:
          API_BASE_URL: !Ref ApiBaseUrl
          DELEGATE_ROLE_NAME: !Ref DeleteVolumeSnapshotsRoleName
      Tags:
        - Key: Name
          Value: !Sub '${ResourceName}-delete-volume-snapshots'
        - Key: 'sysdig.com/response-actions/cloud-actions'
          Value: 'true'
        - Key: 'sysdig.com/response-actions/resource-name'
          Value: 'delete-volume-snapshots-lambda'

Outputs:
  QuarantineUserFunctionArn:
    Condition: CreateQuarantineUserResources
    Value: !GetAtt QuarantineUserFunction.Arn
  FetchCloudLogsFunctionArn:
    Condition: CreateFetchCloudLogsResources
    Value: !GetAtt FetchCloudLogsFunction.Arn
  RemovePolicyFunctionArn:
    Condition: CreateQuarantineUserResources
    Value: !GetAtt RemovePolicyFunction.Arn
  ConfigureResourceAccessFunctionArn:
    Condition: CreateMakePrivateResources
    Value: !GetAtt ConfigureResourceAccessFunction.Arn
  CreateVolumeSnapshotsFunctionArn:
    Condition: CreateVolumeSnapshotResources
    Value: !GetAtt CreateVolumeSnapshotsFunction.Arn
  DeleteVolumeSnapshotsFunctionArn:
    Condition: CreateVolumeSnapshotResources
    Value: !GetAtt DeleteVolumeSnapshotsFunction.Arn
