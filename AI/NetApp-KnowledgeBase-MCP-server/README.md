# NetApp Workload Factory GenAI MCP server

The NetApp BlueXP Workload Factory for GenAI Model Context Protocol (MCP) server enables MCP-based AI agents to interact with Workload Factory for GenAI knowledge bases.

## Requirements

- [Node.js](https://nodejs.org/) 23 or later (stable version).
- You need a tenancy account in NetApp BlueXP.
- You need a service account created in your BlueXP tenancy account.
    - You can create a service account from the **Identity & access management** area in the BlueXP console.
- You need to note the following from the service account:
    - Account ID
    - Client ID (available in the **Service account credentials** area in the BlueXP console)
    - Client Secret (available in the **Service account credentials** area in the BlueXP console)
- You need a knowledge base created with BlueXP Workload Factory for GenAI that is configured for active authentication and published:
    - The knowledge base name must be 53 characters or less in length.
    - You need to note the description of the BlueXP Workload Factory for GenAI knowledge base. This description will be used by the MCP client to access the GenAI knowledge base with the MCP server.
    - [Activate external authentication for a knowledge base](https://docs.netapp.com/us-en/workload-genai/knowledge-base/activate-authentication.html)
    - [Publish a knowledge base](https://docs.netapp.com/us-en/workload-genai/knowledge-base/publish-knowledgebase.html)

- You need the ID of the published knowledge base. You can find the knowledge base ID on the **Knowledge bases > Manage knowledge base** page in BlueXP Workload Factory for GenAI, or you can work with the person that created the knowledge base.

## Configure the MCP server
Update the following variables in the MCP server `config/config.env` file with values from your environment:
```
ACCOUNT_ID=<service_account_ID>
CLIENT_ID=<service_account_client_ID>
CLIENT_SECRET=<service_account_client_secret>
```

## Install the server
To install the MCP server, run the following command:

```bash
npm install
```

## Build the server
To build the MCP server, run the following command:

```bash
npm run build
```

## Configure an MCP client to connect to the server
As an example, you can configure Claude Desktop to connect to the GenAI MCP server.
 
1. Open the `claude-desktop-config.json` file and add the following, replacing content in brackets <> with the path to the GenAI MCP server package:
    ```json
    {
      "mcpServers": {
        "workload-factory-gen-ai": {
          "command": "node.exe",
          "args": [
            "--env-file=<path_to_the_mcp_server_package>/config/config.env",
            "<path_to_the_mcp_server_package>/build/index.js"
          ]
        }
      }
    }
    ```
2. Provide the client with the following command string to invoke the MCP server:
    ```
    node --env-file=<path_to_mcp_server_package>/config/config.env <path_to_mcp_server_package>/build/index.js
    ```

3. Completely exit Claude Desktop using the `File` menu. 
4. Start Claude Desktop to make the new configuration active.


## Learn More

Learn more about [BlueXP Workload Factory for GenAI](https://docs.netapp.com/us-en/workload-genai/index.html).
