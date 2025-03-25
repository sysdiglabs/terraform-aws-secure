Resources:
  ApiConnection:
    Type: AWS::Events::Connection
    Properties:
      Name: ${name}-connection
      AuthorizationType: API_KEY
      AuthParameters:
        ApiKeyAuthParameters:
          ApiKeyName: X-Api-Key
          ApiKeyValue: ${api_key}

  ApiDestination:
    Type: AWS::Events::ApiDestination
    Properties:
      Name: ${name}-destination
      ConnectionArn: !GetAtt ApiConnection.Arn
      InvocationEndpoint: ${endpoint_url}
      HttpMethod: POST
      InvocationRateLimitPerSecond: ${rate_limit}

  EventBridgeRule:
    Type: AWS::Events::Rule
    Properties:
      Name: ${name}
      Description: Forwards events to Sysdig via API Destination
      EventPattern: ${event_pattern}
      State: ${rule_state}
      Targets:
        - Id: SysdigApiDestination
          Arn: !GetAtt ApiDestination.Arn
          RoleArn: !Sub "${arn_prefix}:iam::$${AWS::AccountId}:role/${name}"
