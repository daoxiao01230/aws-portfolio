// terraform apply の outputs (cognito_user_pool_id / cognito_user_pool_client_id / api_endpoint)
// を .env.local に REACT_APP_ プレフィックス付きで設定する（詳細はREADME参照）
const config = {
  region: process.env.REACT_APP_AWS_REGION || 'ap-northeast-1',
  userPoolId: process.env.REACT_APP_COGNITO_USER_POOL_ID,
  userPoolClientId: process.env.REACT_APP_COGNITO_CLIENT_ID,
  apiEndpoint: process.env.REACT_APP_API_ENDPOINT,
};

export default config;
