# NetApp Workload Factory GenAI sample application

## Introduction
The NetApp Workload Factory GenAI sample application enables external application developers to test authentication and retrieval from a published NetApp Workload Factory knowledge base by interacting directly with it in a web-based chatbot application. Its features are similar to the chatbot interface within the NetApp Workload Factory UI, and it uses the same Workload Factory API for conversations. As a developer, you can use this sample application to test published knowledge bases and see API examples that can help you develop your own chatbot application.

## Application components
The NetApp Workload Factory GenAI sample application is a [Next.js](https://nextjs.org/) project bootstrapped with [`create-next-app`](https://github.com/vercel/next.js/tree/canary/packages/create-next-app).

The sample application uses [Redux Toolkit](https://redux-toolkit.js.org) with [RTK Query](https://redux-toolkit.js.org/tutorials/rtk-query) for data fetching.

## Requirements
- [Node.js](https://nodejs.org/) 18.17 or later stable version.
- The NetApp Workload Factory GenAI sample application relies on one of the following login providers:
    - [Amazon Cognito](https://aws.amazon.com/cognito/) + [Amazon Amplify Framework](https://aws-amplify.github.io/docs/js/start)
    - [Clerk](https://clerk.com/)
- You need a knowledge base created with NetApp Workload Factory GenAI that is configured for active authentication and published:
    - [Activate external authentication for a knowledge base](https://docs.netapp.com/us-en/workload-genai/activate-authentication.html)
    - [Publish a knowledge base](https://docs.netapp.com/us-en/workload-genai/publish-knowledgebase.html)
- You need the ID of the published knowledge base. You can find the knowledge base ID on the **Knowledge bases > Manage knowledge base** page in Workload Factory GenAI, or you can work with the person that created the knowledge base.

## Set up login providers
To get started, you need to configure one of the supported login providers. Configure the same login provider (issuer) that is used by the knowledge base that will integrate with the sample chatbot application.

### Set up AWS Cognito
1. Follow the [Create user pool](https://www.cognitobuilders.training/20-lab1/20-setup-and-explore/10-create-userpool/) instructions to create a Cognito user pool.
2. Use the Amazon Cognito documentation to find your user pool ID and user web client ID:
    1. [Find your user pool ID](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/cognito-idp/list-user-pools.html).  
    For example: `aws cognito-idp list-user-pools --max-results=60 --output=table`
    2. [Find your web client ID](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/cognito-idp/list-user-pool-clients.html).  
    For example: `aws cognito-idp list-user-pool-clients --user-pool-id  $(USER_POOL_ID) --output=table`        
3. Download and unpack the Workload Factory GenAI sample application source package.
4. In the Workload Factory GenAI sample application source, rename the `.env.local.sample` file to `.env.local`.
5. In the `.env.local` file, uncomment the corresponding section for the login provider you plan to use, and make sure the section for the other provider is commented out. 
6. In the `.env.local` file, change the following variables in the appropriate provider section to match your environment. Replace `YOUR_KNOWLEDGE_BASE_ID` with the knowledge base ID from Workload Factory:
    - NEXT_PUBLIC_LOGIN_PROVIDER=cognito
    - NEXT_PUBLIC_KNOWLEDGE_BASE_ID=YOUR_KNOWLEDGE_BASE_ID
    - NEXT_PUBLIC_AWS_USER_POOLS_ID=YOUR_AWS_USER_POOLS_ID
    - NEXT_PUBLIC_AWS_USER_WEB_CLIENT_ID=YOUR_AWS_USER_WEB_CLIENT_ID

### Set up Clerk
1. Follow the [Sign up](https://dashboard.clerk.com/sign-in?redirect_url=https%3A%2F%2Fdashboard.clerk.com%2F) instructions to sign up for a Clerk account. 
2. Download and unpack the Workload Factory GenAI sample application source package.
3. In the Workload Factory GenAI sample application source, rename the `.env.local.sample` file to `.env.local`.
4. In the `.env.local` file, uncomment the corresponding section for the login provider you plan to use, and make sure the section for the other provider is commented out. 
5. In the `.env.local` file, change the following variables in the appropriate provider section to match your environment. Replace `YOUR_KNOWLEDGE_BASE_ID` with the knowledge base ID from Workload Factory:
    - NEXT_PUBLIC_LOGIN_PROVIDER=clerk
    - NEXT_PUBLIC_KNOWLEDGE_BASE_ID=YOUR_KNOWLEDGE_BASE_ID
    - NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=YOUR_NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY
    - CLERK_SECRET_KEY=YOUR_CLERK_SECRET_KEY
    - NEXT_PUBLIC_CLERK_TEMPLATE=YOUR_CLERK_TEMPLATE

## Download the application
To download the application, clone the GitHub repository. Then, change to the sample application directory so that you can build or run it:

1. 
    ```bash
    git clone https://github.com/NetApp/FSx-ONTAP-samples-scripts
    ```

2. 
    ```bash
    cd FSx-ONTAP-samples-scripts/AI/GenAI-ChatBot-application-sample
    ```

## Install dependencies
To install dependencies for the sample application, run the following command:

```bash
npm install
```

## Run the application 
1. To run the application locally, run the following command:

    ```bash
    npm run dev
    ```

2. Open [http://localhost:9091](http://localhost:9091) with your browser to log in to the application.

## Build the application
To build bundle.js, run the following command:

```bash
npm run build
```

## Learn More

- Learn more about [BlueXP Workload Factory for AWS](https://docs.netapp.com/us-en/workload-genai/index.html).
- Learn more about the APIs used in this sample application by visiting the [Workload Factory API documentation](https://console.workloads.netapp.com/api-doc).
- To learn more about Next.js, take a look at the following resources:
    - [Next.js documentation](https://nextjs.org/docs) - learn about Next.js features and API.
    - [Learn Next.js](https://nextjs.org/learn) - an interactive Next.js tutorial.

## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSx-ONTAP-samples-scripts/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License
is distributed on an _"AS IS"_ basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

© 2024 NetApp, Inc. All Rights Reserved.
