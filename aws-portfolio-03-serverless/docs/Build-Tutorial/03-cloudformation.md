[目次](./README.md) | 前へ: [Part 1 — 全体像](./01-overview.md) | 次へ: [Part 4 — フロントエンド(まず動かす)](./04-frontend-quickstart.md)

---

# Part 3 — CloudFormationで作る

Part 2と全く同じアーキテクチャ（Cognito・DynamoDB・Lambda・API Gateway・
S3+CloudFront+ACM+Route53）を、Terraformの代わりにAWS純正のIaCツールである
**CloudFormation**で構築する。考え方はPart 2と同じなので、「なぜこの設計か」の
説明は繰り返さない。ここでは「CloudFormationならではの書き方・進め方」に絞る。

> ⚠️ このリポジトリの`infrastructure/cloudformation/`には、これから説明する
> 9つのテンプレートが**既に完成した状態で置いてある**（実際にはデプロイされて
> いない参照実装。理由はPart 3-9で説明する）。この章は「その9ファイルを
> 自分でゼロから書けるようになる」ための解説であり、既存ファイルをコピーする
> だけなら`infrastructure/cloudformation/*.yaml`を直接見ればよい。

### 3-1. TerraformとCloudFormationの考え方の違い

| | Terraform | CloudFormation |
|---|---|---|
| ファイルの単位 | フォルダ内の全`.tf`が1つの設定として扱われる | 1つの`.yaml`（または`.json`）が1つの「スタック」として独立してデプロイされる |
| リソース間の依存 | 同じフォルダ内なら自動で解決してくれる | スタックをまたぐ依存は、片方のOutputsをもう片方のParametersに**手動で**渡す必要がある |
| 実行コマンド | `terraform apply`（フォルダ全体を1回で適用） | `aws cloudformation deploy`をスタックの数だけ実行 |
| 状態の保存場所 | `terraform.tfstate`（ローカルまたはS3等） | AWS側がスタックとして管理（ローカルに状態ファイルを持たない） |

このため、CloudFormationでは「依存関係の順番にスタックをデプロイし、
前のスタックのOutputsを次のスタックのパラメータとして手渡す」という
作業が発生する。これがCloudFormation版が複数ファイルに分かれている理由。

### 3-2. デプロイ順序を先に把握する

```
dynamodb.yaml ─┐
cognito.yaml ──┼─→ lambda.yaml ─→ api-gateway.yaml
               │
s3-frontend.yaml ─→ cloudfront.yaml ─→ route53.yaml
acm.yaml (us-east-1) ──────────────↗
                                     │
              lambda.yaml + s3-frontend.yaml + cloudfront.yaml のoutputs
                                     ↓
                              iam-cicd.yaml（最後）
```

矢印の元にあるスタックのOutputsを、矢印の先のスタックのパラメータとして渡す。

### 3-3. dynamodb.yaml — 台帳を作る

```bash
mkdir -p aws-portfolio-03-serverless/infrastructure/cloudformation
cd aws-portfolio-03-serverless/infrastructure/cloudformation
```

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Portfolio 03 - DynamoDB entries table'

Parameters:
  ProjectName:
    Type: String
    Default: aws-portfolio-03-serverless

Resources:
  EntriesTable:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: !Sub '${ProjectName}-entries'
      BillingMode: PAY_PER_REQUEST
      AttributeDefinitions:
        - AttributeName: userId
          AttributeType: S
        - AttributeName: entryId
          AttributeType: S
      KeySchema:
        - AttributeName: userId
          KeyType: HASH
        - AttributeName: entryId
          KeyType: RANGE
      Tags:
        - Key: Project
          Value: !Ref ProjectName

Outputs:
  TableName:
    Value: !Ref EntriesTable
  TableArn:
    Value: !GetAtt EntriesTable.Arn
```

> 💡 CloudFormationの`Type: AWS::DynamoDB::Table`は、Terraformの
> `resource "aws_dynamodb_table"`と1対1で対応する（プロパティ名の
> キャメルケース/スネークケースが違うだけ）。`Outputs`ブロックが、
> 次のスタックに渡す値をエクスポートする場所。

デプロイして確認する:
```bash
aws cloudformation deploy \
  --template-file dynamodb.yaml \
  --stack-name portfolio-03-dynamodb

aws cloudformation describe-stacks \
  --stack-name portfolio-03-dynamodb \
  --query "Stacks[0].Outputs"
# TableName / TableArn の値をメモしておく
```

### 3-4. cognito.yaml — 会員証発行窓口を作る

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Portfolio 03 - Cognito User Pool + App Client'

Parameters:
  ProjectName:
    Type: String
    Default: aws-portfolio-03-serverless

Resources:
  UserPool:
    Type: AWS::Cognito::UserPool
    Properties:
      UserPoolName: !Sub '${ProjectName}-users'
      UsernameAttributes:
        - email
      AutoVerifiedAttributes:
        - email
      Policies:
        PasswordPolicy:
          MinimumLength: 8
          RequireLowercase: true
          RequireUppercase: true
          RequireNumbers: true
          RequireSymbols: false
      UserPoolTags:
        Project: !Ref ProjectName

  UserPoolClient:
    Type: AWS::Cognito::UserPoolClient
    Properties:
      ClientName: !Sub '${ProjectName}-spa-client'
      UserPoolId: !Ref UserPool
      GenerateSecret: false
      ExplicitAuthFlows:
        - ALLOW_USER_SRP_AUTH
        - ALLOW_REFRESH_TOKEN_AUTH

Outputs:
  UserPoolId:
    Value: !Ref UserPool
  UserPoolClientId:
    Value: !Ref UserPoolClient
  UserPoolArn:
    Value: !GetAtt UserPool.Arn
```

```bash
aws cloudformation deploy \
  --template-file cognito.yaml \
  --stack-name portfolio-03-cognito

aws cloudformation describe-stacks \
  --stack-name portfolio-03-cognito \
  --query "Stacks[0].Outputs"
```

### 3-5. lambda.yaml — Lambda関数を作る（コードはインライン埋め込み）

CloudFormationにはTerraformの`archive`プロバイダのような「フォルダをzip化する」
機能がない。かわりに、コードが数KB程度と小さい場合は`ZipFile`プロパティに
Pythonコードをそのまま書き込める（4KB弱まで）。

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Portfolio 03 - Lambda execution role + 4 functions'

Parameters:
  ProjectName:
    Type: String
    Default: aws-portfolio-03-serverless
  TableName:
    Type: String
  TableArn:
    Type: String

Resources:
  LambdaExecutionRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Sub '${ProjectName}-lambda-exec'
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: lambda.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
      Policies:
        - PolicyName: !Sub '${ProjectName}-lambda-dynamodb'
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - dynamodb:PutItem
                  - dynamodb:GetItem
                  - dynamodb:Query
                  - dynamodb:UpdateItem
                  - dynamodb:DeleteItem
                Resource: !Ref TableArn

  CreateEntryFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub '${ProjectName}-create-entry'
      Role: !GetAtt LambdaExecutionRole.Arn
      Handler: index.lambda_handler
      Runtime: python3.12
      Timeout: 3
      Environment:
        Variables:
          TABLE_NAME: !Ref TableName
      Code:
        ZipFile: |
          import json, os, uuid
          from datetime import datetime, timezone
          import boto3
          table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])

          def lambda_handler(event, context):
              user_id = event["requestContext"]["authorizer"]["jwt"]["claims"]["sub"]
              body = json.loads(event.get("body") or "{}")
              content = body.get("content", "").strip()
              entry_type = body.get("entryType", "gratitude")
              if not content:
                  return {"statusCode": 400, "body": json.dumps({"message": "content is required"})}
              now = datetime.now(timezone.utc).isoformat()
              entry = {
                  "userId": user_id,
                  "entryId": f"{now}#{uuid.uuid4()}",
                  "content": content,
                  "entryType": entry_type,
                  "createdAt": now,
                  "updatedAt": now,
              }
              table.put_item(Item=entry)
              return {"statusCode": 201, "body": json.dumps(entry)}

  # list_entries / update_entry / delete_entry も同じパターンで3つ追加する
  # （完全なコードは infrastructure/cloudformation/lambda.yaml を参照）

Outputs:
  CreateEntryFunctionArn:
    Value: !GetAtt CreateEntryFunction.Arn
  CreateEntryFunctionName:
    Value: !Ref CreateEntryFunction
  # 他3関数分のArn/Nameも同様にOutputsへ
```

> 💡 `Handler: index.lambda_handler`の`index`という名前は固定。CloudFormationの
> `ZipFile`でインラインコードを書くと、AWSが自動的に`index.py`というファイル名で
> zip化するため、実際のファイル名に関わらず必ず`index`を指定する。
> 完全な4関数分のコードは`infrastructure/cloudformation/lambda.yaml`に
> すでに書いてあるので、実際に手を動かす際はそちらをコピーするとよい
> （このチュートリアルでは1つ目だけ示し、パターンの繰り返しは省略した）。

```bash
aws cloudformation deploy \
  --template-file lambda.yaml \
  --stack-name portfolio-03-lambda \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    TableName=<dynamodbスタックのTableName> \
    TableArn=<dynamodbスタックのTableArn>
```

> 💡 `--capabilities CAPABILITY_NAMED_IAM`が必要な理由: このテンプレートは
> `AWS::IAM::Role`という「名前付きの」IAMリソースを作る。CloudFormationは
> IAMリソースを勝手に作られると困る場合があるため、デプロイする人が
> 「IAMリソースが作られることを理解して承認した」ことを示すため、
> このフラグを明示的に付ける必要がある。

### 3-6. api-gateway.yaml — 受付カウンターを作る

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Portfolio 03 - HTTP API + JWT Authorizer + routes'

Parameters:
  ProjectName:
    Type: String
    Default: aws-portfolio-03-serverless
  AwsRegion:
    Type: String
    Default: ap-northeast-1
  CognitoUserPoolId:
    Type: String
  CognitoUserPoolClientId:
    Type: String
  CreateEntryFunctionArn:
    Type: String
  CreateEntryFunctionName:
    Type: String
  # list/update/delete 分も同様に4組ずつパラメータを用意する

Resources:
  HttpApi:
    Type: AWS::ApiGatewayV2::Api
    Properties:
      Name: !Sub '${ProjectName}-api'
      ProtocolType: HTTP
      CorsConfiguration:
        AllowOrigins: ['*']
        AllowMethods: [GET, POST, PUT, DELETE, OPTIONS]
        AllowHeaders: [content-type, authorization]

  DefaultStage:
    Type: AWS::ApiGatewayV2::Stage
    Properties:
      ApiId: !Ref HttpApi
      StageName: '$default'
      AutoDeploy: true

  CognitoAuthorizer:
    Type: AWS::ApiGatewayV2::Authorizer
    Properties:
      ApiId: !Ref HttpApi
      Name: !Sub '${ProjectName}-cognito-authorizer'
      AuthorizerType: JWT
      IdentitySource:
        - '$request.header.Authorization'
      JwtConfiguration:
        Audience:
          - !Ref CognitoUserPoolClientId
        Issuer: !Sub 'https://cognito-idp.${AwsRegion}.amazonaws.com/${CognitoUserPoolId}'

  CreateEntryIntegration:
    Type: AWS::ApiGatewayV2::Integration
    Properties:
      ApiId: !Ref HttpApi
      IntegrationType: AWS_PROXY
      IntegrationUri: !Ref CreateEntryFunctionArn
      PayloadFormatVersion: '2.0'

  CreateEntryRoute:
    Type: AWS::ApiGatewayV2::Route
    Properties:
      ApiId: !Ref HttpApi
      RouteKey: 'POST /entries'
      Target: !Sub 'integrations/${CreateEntryIntegration}'
      AuthorizationType: JWT
      AuthorizerId: !Ref CognitoAuthorizer

  CreateEntryPermission:
    Type: AWS::Lambda::Permission
    Properties:
      Action: lambda:InvokeFunction
      FunctionName: !Ref CreateEntryFunctionName
      Principal: apigateway.amazonaws.com
      SourceArn: !Sub 'arn:aws:execute-api:${AwsRegion}:${AWS::AccountId}:${HttpApi}/*/*'

  # GET /entries, PUT /entries/{id}, DELETE /entries/{id} も
  # 同じ3点セット（Integration/Route/Permission）を繰り返す
  # 完全版は infrastructure/cloudformation/api-gateway.yaml 参照

Outputs:
  ApiEndpoint:
    Value: !Sub 'https://${HttpApi}.execute-api.${AwsRegion}.amazonaws.com/'
```

```bash
aws cloudformation deploy \
  --template-file api-gateway.yaml \
  --stack-name portfolio-03-api \
  --parameter-overrides \
    CognitoUserPoolId=<cognitoスタックのUserPoolId> \
    CognitoUserPoolClientId=<cognitoスタックのUserPoolClientId> \
    CreateEntryFunctionArn=<lambdaスタックの値> \
    CreateEntryFunctionName=<lambdaスタックの値> \
    ListEntriesFunctionArn=<...> ListEntriesFunctionName=<...> \
    UpdateEntryFunctionArn=<...> UpdateEntryFunctionName=<...> \
    DeleteEntryFunctionArn=<...> DeleteEntryFunctionName=<...>
```

デプロイ後の動作確認はPart 2-9と同じ（`curl`で401確認、`aws lambda invoke`で
直接動作確認）。

### 3-7. s3-frontend.yaml — Reactのビルド成果物を置く倉庫

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Portfolio 03 - S3 bucket for frontend hosting'

Parameters:
  BucketName:
    Type: String

Resources:
  FrontendBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Ref BucketName
      PublicAccessBlockConfiguration:
        BlockPublicAcls: true
        BlockPublicPolicy: true
        IgnorePublicAcls: true
        RestrictPublicBuckets: true

Outputs:
  BucketName:
    Value: !Ref FrontendBucket
  BucketArn:
    Value: !GetAtt FrontendBucket.Arn
  BucketRegionalDomainName:
    Value: !GetAtt FrontendBucket.RegionalDomainName
```

```bash
aws cloudformation deploy \
  --template-file s3-frontend.yaml \
  --stack-name portfolio-03-s3 \
  --parameter-overrides BucketName=portfolio-03-serverless-frontend-$(aws sts get-caller-identity --query Account --output text)
```

### 3-8. acm.yaml — HTTPS証明書を発行する（us-east-1固定）

独自ドメインなしならこのステップとroute53.yamlはスキップ。

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Portfolio 03 - ACM Certificate for journal.daoxiao.org'

Parameters:
  DomainName:
    Type: String
    Default: journal.daoxiao.org
  HostedZoneId:
    Type: String

Resources:
  Certificate:
    Type: AWS::CertificateManager::Certificate
    Properties:
      DomainName: !Ref DomainName
      ValidationMethod: DNS
      DomainValidationOptions:
        - DomainName: !Ref DomainName
          HostedZoneId: !Ref HostedZoneId

Outputs:
  CertificateArn:
    Value: !Ref Certificate
```

```bash
# 必ず us-east-1 でデプロイする（CloudFrontの証明書はここでしか発行できない）
aws cloudformation deploy \
  --template-file acm.yaml \
  --stack-name portfolio-03-acm \
  --region us-east-1 \
  --parameter-overrides HostedZoneId=<自分のRoute53ホストゾーンID>
```

### 3-9. cloudfront.yaml — 配送センターを作る

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Portfolio 03 - CloudFront + BucketPolicy'

Parameters:
  BucketName:
    Type: String
  BucketArn:
    Type: String
  BucketRegionalDomainName:
    Type: String
  AcmCertificateArn:
    Type: String
  DomainName:
    Type: String
    Default: journal.daoxiao.org

Resources:
  CloudFrontOAC:
    Type: AWS::CloudFront::OriginAccessControl
    Properties:
      OriginAccessControlConfig:
        Name: !Sub '${BucketName}-oac'
        OriginAccessControlOriginType: s3
        SigningBehavior: always
        SigningProtocol: sigv4

  CloudFrontDistribution:
    Type: AWS::CloudFront::Distribution
    Properties:
      DistributionConfig:
        Enabled: true
        HttpVersion: http2
        IPV6Enabled: true
        DefaultRootObject: index.html
        Aliases:
          - !Ref DomainName
        Origins:
          - Id: !Sub 'S3-${BucketName}'
            DomainName: !Ref BucketRegionalDomainName
            OriginAccessControlId: !GetAtt CloudFrontOAC.Id
            S3OriginConfig:
              OriginAccessIdentity: ''
        DefaultCacheBehavior:
          TargetOriginId: !Sub 'S3-${BucketName}'
          ViewerProtocolPolicy: redirect-to-https
          AllowedMethods: [GET, HEAD]
          CachedMethods: [GET, HEAD]
          Compress: true
          ForwardedValues:
            QueryString: false
            Cookies:
              Forward: none
          MinTTL: 0
          DefaultTTL: 3600
          MaxTTL: 86400
        CustomErrorResponses:
          - ErrorCode: 403
            ResponseCode: 200
            ResponsePagePath: /index.html
          - ErrorCode: 404
            ResponseCode: 200
            ResponsePagePath: /index.html
        ViewerCertificate:
          AcmCertificateArn: !Ref AcmCertificateArn
          SslSupportMethod: sni-only
          MinimumProtocolVersion: TLSv1.2_2021
        Restrictions:
          GeoRestriction:
            RestrictionType: none

  BucketPolicy:
    Type: AWS::S3::BucketPolicy
    Properties:
      Bucket: !Ref BucketName
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Sid: AllowCloudFrontServicePrincipal
            Effect: Allow
            Principal:
              Service: cloudfront.amazonaws.com
            Action: s3:GetObject
            Resource: !Sub '${BucketArn}/*'
            Condition:
              StringEquals:
                AWS:SourceArn: !Sub 'arn:aws:cloudfront::${AWS::AccountId}:distribution/${CloudFrontDistribution}'

Outputs:
  SiteUrl:
    Value: !Sub 'https://${DomainName}/'
  CloudFrontDomainName:
    Value: !GetAtt CloudFrontDistribution.DomainName
  CloudFrontDistributionId:
    Value: !Ref CloudFrontDistribution
  CloudFrontDistributionArn:
    Value: !Sub 'arn:aws:cloudfront::${AWS::AccountId}:distribution/${CloudFrontDistribution}'
```

```bash
aws cloudformation deploy \
  --template-file cloudfront.yaml \
  --stack-name portfolio-03-cloudfront \
  --parameter-overrides \
    BucketName=<s3スタックのBucketName> \
    BucketArn=<s3スタックのBucketArn> \
    BucketRegionalDomainName=<s3スタックのBucketRegionalDomainName> \
    AcmCertificateArn=<acmスタックのCertificateArn（us-east-1で取得したもの）>
```

### 3-10. route53.yaml — ドメイン名をCloudFrontに向ける

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Portfolio 03 - Route 53 DNS record'

Parameters:
  HostedZoneId:
    Type: String
  DomainName:
    Type: String
    Default: journal.daoxiao.org
  CloudFrontDomainName:
    Type: String

Resources:
  DNSRecord:
    Type: AWS::Route53::RecordSet
    Properties:
      HostedZoneId: !Ref HostedZoneId
      Name: !Ref DomainName
      Type: A
      AliasTarget:
        # CloudFront専用の固定Hosted Zone ID（アカウントによらず常にこの値）
        HostedZoneId: Z2FDTNDATAQYW2
        DNSName: !Ref CloudFrontDomainName
        EvaluateTargetHealth: false

Outputs:
  URL:
    Value: !Sub 'https://${DomainName}'
```

```bash
aws cloudformation deploy \
  --template-file route53.yaml \
  --stack-name portfolio-03-route53 \
  --parameter-overrides \
    HostedZoneId=<自分のホストゾーンID> \
    CloudFrontDomainName=<cloudfrontスタックのCloudFrontDomainName>
```

### 3-11. iam-cicd.yaml — CI/CD用の限定権限を既存ユーザーに追加する（最後）

このスタックは新しいIAMユーザーを作らず、Part 6で使う既存のGitHub Actions用
ユーザーに「Lambdaコードの更新」「S3への書き込み」「CloudFrontのキャッシュ削除」
だけを許可するポリシーを追加する。すべてのリソースが揃った後、一番最後にデプロイする。

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Portfolio 03 - Scoped CI/CD policies on the existing GitHub Actions IAM user'

Parameters:
  ExistingIamUserName:
    Type: String
    Default: github-actions-portfolio-01
  CreateEntryFunctionArn:
    Type: String
  ListEntriesFunctionArn:
    Type: String
  UpdateEntryFunctionArn:
    Type: String
  DeleteEntryFunctionArn:
    Type: String
  FrontendBucketArn:
    Type: String
  CloudFrontDistributionArn:
    Type: String

Resources:
  LambdaDeployPolicy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: portfolio-03-lambda-deploy-policy
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Action:
              - lambda:UpdateFunctionCode
            Resource:
              - !Ref CreateEntryFunctionArn
              - !Ref ListEntriesFunctionArn
              - !Ref UpdateEntryFunctionArn
              - !Ref DeleteEntryFunctionArn
      Users:
        - !Ref ExistingIamUserName

  FrontendDeployPolicy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: portfolio-03-frontend-deploy-policy
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Action:
              - s3:PutObject
              - s3:DeleteObject
              - s3:GetObject
              - s3:ListBucket
            Resource:
              - !Ref FrontendBucketArn
              - !Sub '${FrontendBucketArn}/*'
          - Effect: Allow
            Action:
              - cloudfront:CreateInvalidation
            Resource:
              - !Ref CloudFrontDistributionArn
      Users:
        - !Ref ExistingIamUserName
```

> 💡 `Users: [!Ref ExistingIamUserName]`が、このテンプレートの一番重要な部分。
> 通常`AWS::IAM::Policy`は「新しく作ったユーザー」に付けることが多いが、
> ここでは`AWS::IAM::User`リソースを作らず、**既にAWSに存在するユーザー名を
> 文字列パラメータとして受け取り**、そのユーザーにポリシーを追加している。
> 新しいIAMユーザー（と、それに紐づくGitHub Secrets）を増やしたくない場合の
> 定番パターン。

```bash
aws cloudformation deploy \
  --template-file iam-cicd.yaml \
  --stack-name portfolio-03-iam-cicd \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    CreateEntryFunctionArn=<...> ListEntriesFunctionArn=<...> \
    UpdateEntryFunctionArn=<...> DeleteEntryFunctionArn=<...> \
    FrontendBucketArn=<s3スタックの値> \
    CloudFrontDistributionArn=<cloudfrontスタックの値>
```

### 3-12. なぜこのCloudFormation版は実際にはデプロイしない設定なのか

このリポジトリでは、Part 2（Terraform）で作ったインフラが既に本番で稼働中。
もしこのPart 3のテンプレート群をそのまま同じAWSアカウントにデプロイすると、
**同じ名前・同じ役割のリソースが2セット**（Cognitoプールが2つ、Lambda関数が
8個、等）できてしまい、コストの二重発生や名前衝突を招く。そのため、この
リポジトリの`infrastructure/cloudformation/`にあるテンプレートは
「参照実装として置いてあるだけで、実際にはデプロイしていない」。

自分の環境で試す場合は、Part 2（Terraform）かPart 3（CloudFormation）の
**どちらか一方だけ**を選んでデプロイすること。両方同時にデプロイしたい場合は、
`ProjectName`パラメータを変える等してリソース名を衝突させない工夫が必要になる。

CloudFormation版はここまで。Part 4またはPart 5に進んでフロントエンドを作る。

---

[目次](./README.md) | 前へ: [Part 1 — 全体像](./01-overview.md) | 次へ: [Part 4 — フロントエンド(まず動かす)](./04-frontend-quickstart.md)
