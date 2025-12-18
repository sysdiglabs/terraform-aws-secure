AWSTemplateFormatVersion: '2010-09-09'
Description: 'Sysdig Response Actions Delegate Roles - Multi-Account Deployment'

Parameters:
  TemplateVersion:
    Type: String
    Description: Template version hash to force updates
    Default: "1"
  QuarantineUserLambdaRoleArn:
    Type: String
    Description: ARN of the Lambda execution role for quarantine user function
  QuarantineUserRoleName:
    Type: String
    Description: Name for the quarantine user delegate role
  FetchCloudLogsLambdaRoleArn:
    Type: String
    Description: ARN of the Lambda execution role for fetch cloud logs function
  FetchCloudLogsRoleName:
    Type: String
    Description: Name for the fetch cloud logs delegate role
  RemovePolicyLambdaRoleArn:
    Type: String
    Description: ARN of the Lambda execution role for remove policy function
  RemovePolicyRoleName:
    Type: String
    Description: Name for the remove policy delegate role
  ConfigureResourceAccessLambdaRoleArn:
    Type: String
    Description: ARN of the Lambda execution role for configure resource access function
  ConfigureResourceAccessRoleName:
    Type: String
    Description: Name for the configure resource access delegate role
  CreateVolumeSnapshotsLambdaRoleArn:
    Type: String
    Description: ARN of the Lambda execution role for create volume snapshots function
  CreateVolumeSnapshotsRoleName:
    Type: String
    Description: Name for the create volume snapshots delegate role
  DeleteVolumeSnapshotsLambdaRoleArn:
    Type: String
    Description: ARN of the Lambda execution role for delete volume snapshots function
  DeleteVolumeSnapshotsRoleName:
    Type: String
    Description: Name for the delete volume snapshots delegate role
  EnableQuarantineUser:
    Type: String
    Default: "true"
    AllowedValues: ["true", "false"]
    Description: Enable quarantine user and remove policy delegate roles
  EnableFetchCloudLogs:
    Type: String
    Default: "true"
    AllowedValues: ["true", "false"]
    Description: Enable fetch cloud logs delegate role
  EnableMakePrivate:
    Type: String
    Default: "true"
    AllowedValues: ["true", "false"]
    Description: Enable configure resource access delegate role
  EnableCreateVolumeSnapshot:
    Type: String
    Default: "true"
    AllowedValues: ["true", "false"]
    Description: Enable create and delete volume snapshot delegate roles

Conditions:
  CreateQuarantineUserResources: !Equals [!Ref EnableQuarantineUser, "true"]
  CreateFetchCloudLogsResources: !Equals [!Ref EnableFetchCloudLogs, "true"]
  CreateMakePrivateResources: !Equals [!Ref EnableMakePrivate, "true"]
  CreateVolumeSnapshotResources: !Equals [!Ref EnableCreateVolumeSnapshot, "true"]

Resources:
  # Delegate Role: Configure Resource Access
  ConfigureAccessDelegateRole:
    Type: AWS::IAM::Role
    Condition: CreateMakePrivateResources
    Properties:
      RoleName: !Ref ConfigureResourceAccessRoleName
      Description: Delegate role for configuring resource access
      MaxSessionDuration: 3600
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              AWS: !Ref ConfigureResourceAccessLambdaRoleArn
            Action: 'sts:AssumeRole'
      Policies:
        - PolicyName: response-actions-configure-resource-access
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - 's3:GetBucketLocation'
                  - 's3:GetBucketPublicAccessBlock'
                  - 's3:PutBucketPublicAccessBlock'
                  - 's3:ListAllMyBuckets'
                Resource: '*'
              - Effect: Allow
                Action:
                  - 'rds:DescribeDBInstances'
                  - 'rds:ModifyDBInstance'
                  - 'sts:GetCallerIdentity'
                Resource: '*'
      Tags:
        - Key: ManagedBy
          Value: Terraform
        - Key: Purpose
          Value: ResponseActions
        - Key: 'sysdig.com/response-actions/resource-name'
          Value: 'configure-resource-access-delegate-role'

  # Delegate Role: Create Volume Snapshot
  CreateVolumeSnapshotDelegateRole:
    Type: AWS::IAM::Role
    Condition: CreateVolumeSnapshotResources
    Properties:
      RoleName: !Ref CreateVolumeSnapshotsRoleName
      Description: Delegate role for creating volume snapshots
      MaxSessionDuration: 3600
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              AWS: !Ref CreateVolumeSnapshotsLambdaRoleArn
            Action: 'sts:AssumeRole'
      Policies:
        - PolicyName: response-actions-create-volume-snapshot
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - 'logs:CreateLogGroup'
                  - 'logs:CreateLogStream'
                  - 'logs:PutLogEvents'
                Resource: 'arn:aws:logs:*:*:*'
              - Effect: Allow
                Action:
                  - 'ec2:DescribeInstances'
                  - 'ec2:DescribeVolumes'
                  - 'ec2:DescribeSnapshots'
                  - 'ec2:CreateSnapshot'
                  - 'ec2:CreateTags'
                  - 'sts:GetCallerIdentity'
                Resource: '*'
              - Effect: Allow
                Action:
                  - 'ec2:CreateTags'
                Resource:
                  - 'arn:aws:ec2:*:*:snapshot/*'
      Tags:
        - Key: ManagedBy
          Value: Terraform
        - Key: Purpose
          Value: ResponseActions
        - Key: 'sysdig.com/response-actions/resource-name'
          Value: 'create-volume-snapshot-delegate-role'

  # Delegate Role: Delete Volume Snapshot
  DeleteVolumeSnapshotDelegateRole:
    Type: AWS::IAM::Role
    Condition: CreateVolumeSnapshotResources
    Properties:
      RoleName: !Ref DeleteVolumeSnapshotsRoleName
      Description: Delegate role for deleting volume snapshots
      MaxSessionDuration: 3600
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              AWS: !Ref DeleteVolumeSnapshotsLambdaRoleArn
            Action: 'sts:AssumeRole'
      Policies:
        - PolicyName: response-actions-delete-volume-snapshots
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - 'logs:CreateLogGroup'
                  - 'logs:CreateLogStream'
                  - 'logs:PutLogEvents'
                Resource: 'arn:aws:logs:*:*:*'
              - Effect: Allow
                Action:
                  - 'ec2:DescribeSnapshots'
                  - 'ec2:DeleteSnapshot'
                  - 'sts:GetCallerIdentity'
                Resource: '*'
      Tags:
        - Key: ManagedBy
          Value: Terraform
        - Key: Purpose
          Value: ResponseActions
        - Key: 'sysdig.com/response-actions/resource-name'
          Value: 'delete-volume-snapshot-delegate-role'

  # Delegate Role: Fetch Cloud Logs
  FetchCloudLogsDelegateRole:
    Type: AWS::IAM::Role
    Condition: CreateFetchCloudLogsResources
    Properties:
      RoleName: !Ref FetchCloudLogsRoleName
      Description: Delegate role for fetching cloud logs
      MaxSessionDuration: 3600
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              AWS: !Ref FetchCloudLogsLambdaRoleArn
            Action: 'sts:AssumeRole'
      Policies:
        - PolicyName: response-actions-fetch-cloud-logs
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - 'cloudtrail:LookupEvents'
                  - 'sts:GetCallerIdentity'
                Resource: '*'
      Tags:
        - Key: ManagedBy
          Value: Terraform
        - Key: Purpose
          Value: ResponseActions
        - Key: 'sysdig.com/response-actions/resource-name'
          Value: 'fetch-cloud-logs-delegate-role'

  # Delegate Role: Quarantine User
  QuarantineUserRoleDelegateRole:
    Type: AWS::IAM::Role
    Condition: CreateQuarantineUserResources
    Properties:
      RoleName: !Ref QuarantineUserRoleName
      Description: Delegate role for quarantining users
      MaxSessionDuration: 3600
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              AWS: !Ref QuarantineUserLambdaRoleArn
            Action: 'sts:AssumeRole'
      Policies:
        - PolicyName: response-actions-quarantine-user
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - 'iam:AttachUserPolicy'
                  - 'iam:DetachUserPolicy'
                  - 'iam:PutUserPolicy'
                  - 'iam:DeleteUserPolicy'
                  - 'iam:ListUserPolicies'
                  - 'iam:ListAttachedUserPolicies'
                  - 'iam:GetUser'
                  - 'iam:GetUserPolicy'
                  - 'iam:TagUser'
                  - 'iam:UntagUser'
                  - 'iam:ListUserTags'
                  - 'iam:AttachRolePolicy'
                  - 'iam:DetachRolePolicy'
                  - 'iam:GetRole'
                  - 'iam:ListRolePolicies'
                  - 'iam:ListAttachedRolePolicies'
                  - 'iam:GetPolicy'
                  - 'iam:CreatePolicy'
                  - 'sts:GetCallerIdentity'
                Resource: '*'
      Tags:
        - Key: ManagedBy
          Value: Terraform
        - Key: Purpose
          Value: ResponseActions
        - Key: 'sysdig.com/response-actions/resource-name'
          Value: 'quarantine-user-delegate-role'

  # Delegate Role: Remove Policy
  RemovePolicyDelegateRole:
    Type: AWS::IAM::Role
    Condition: CreateQuarantineUserResources
    Properties:
      RoleName: !Ref RemovePolicyRoleName
      Description: Delegate role for removing policies
      MaxSessionDuration: 3600
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              AWS: !Ref RemovePolicyLambdaRoleArn
            Action: 'sts:AssumeRole'
      Policies:
        - PolicyName: response-actions-remove-policy
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - 'iam:DetachUserPolicy'
                  - 'iam:DetachRolePolicy'
                  - 'iam:ListAttachedUserPolicies'
                  - 'iam:ListAttachedRolePolicies'
                  - 'iam:GetUser'
                  - 'iam:GetRole'
                  - 'sts:GetCallerIdentity'
                Resource: '*'
      Tags:
        - Key: ManagedBy
          Value: Terraform
        - Key: Purpose
          Value: ResponseActions
        - Key: 'sysdig.com/response-actions/resource-name'
          Value: 'remove-policy-delegate-role'

Outputs:
  ConfigureAccessDelegateRoleName:
    Condition: CreateMakePrivateResources
    Value: !Ref ConfigureAccessDelegateRole
    Description: Name of the configure resource access delegate role
  CreateVolumeSnapshotDelegateRoleName:
    Condition: CreateVolumeSnapshotResources
    Value: !Ref CreateVolumeSnapshotDelegateRole
    Description: Name of the create volume snapshot delegate role
  DeleteVolumeSnapshotDelegateRoleName:
    Condition: CreateVolumeSnapshotResources
    Value: !Ref DeleteVolumeSnapshotDelegateRole
    Description: Name of the delete volume snapshot delegate role
  FetchCloudLogsDelegateRoleName:
    Condition: CreateFetchCloudLogsResources
    Value: !Ref FetchCloudLogsDelegateRole
    Description: Name of the fetch cloud logs delegate role
  QuarantineUserRoleDelegateRoleName:
    Condition: CreateQuarantineUserResources
    Value: !Ref QuarantineUserRoleDelegateRole
    Description: Name of the quarantine user delegate role
  RemovePolicyDelegateRoleName:
    Condition: CreateQuarantineUserResources
    Value: !Ref RemovePolicyDelegateRole
    Description: Name of the remove policy delegate role
