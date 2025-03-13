const awsConfig = {
    aws_app_analytics: 'enable',
    aws_user_pools: 'enable',
    aws_user_pools_id: process.env.NEXT_PUBLIC_AWS_USER_POOLS_ID,
    aws_user_pools_mfa_type: 'OFF',
    aws_user_pools_web_client_id: process.env.NEXT_PUBLIC_AWS_USER_WEB_CLIENT_ID,
    aws_user_settings: 'enable',
    oauth: process.env.NEXT_PUBLIC_AWS_OAUTH
};

export default awsConfig
