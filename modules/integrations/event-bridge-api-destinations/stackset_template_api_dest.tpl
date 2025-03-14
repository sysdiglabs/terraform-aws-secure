Resources:
  ApiConnection:
    Type: AWS::Events::Connection
    Properties:
      Name: ${name}-connection
      AuthorizationType: API_KEY
      AuthParameters:
        ApiKey:
          Key: X-Api-Key
          Value: ${api_key}

  ApiDestination:
    Type: AWS::Events::ApiDestination
    Properties:
      Name: ${name}-destination
      ConnectionArn: !GetAtt ApiConnection.Arn
      InvocationEndpoint: ${endpoint_url}
      HttpMethod: POST
      InvocationRateLimitPerSecond: ${rate_limit}