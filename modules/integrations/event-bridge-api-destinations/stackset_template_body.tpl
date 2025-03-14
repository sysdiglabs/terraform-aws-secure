Resources:
  EventBridgeRule:
    Type: AWS::Events::Rule
    Properties:
      Name: ${name}
      Description: Forwards events to Sysdig via API Destination
      EventPattern: ${event_pattern}
      State: ${rule_state}
      Targets:
        - Id: SysdigApiDestination
          Arn: !Sub "${arn_prefix}:events:${AWS::Region}:${AWS::AccountId}:api-destination/${name}-destination"
          RoleArn: !Sub "${arn_prefix}:iam::${AWS::AccountId}:role/${name}"
