Resources:
  EventBridgeRole:
      Type: AWS::IAM::Role
      Properties:
        RoleName: ${name}
        AssumeRolePolicyDocument:
          Version: "2012-10-17"
          Statement:
            - Effect: Allow
              Principal:
                Service: events.amazonaws.com
              Action: 'sts:AssumeRole'
            - Effect: "Allow"
              Principal:
                AWS: "${trusted_identity}"
              Action: "sts:AssumeRole"
              Condition:
                StringEquals:
                  sts:ExternalId: "${external_id}"
        Policies:
          - PolicyName: ${name}
            PolicyDocument:
              Version: "2012-10-17"
              Statement:
                - Effect: Allow
                  Action: 'events:InvokeApiDestination'
                  Resource: "${arn_prefix}:events:*:*:api-destination/${name}-destination/*"
                - Effect: Allow
                  Action:
                    - "events:DescribeRule"
                    - "events:ListTargetsByRule"
                  Resource: "${arn_prefix}:events:*:*:rule/${name}"
