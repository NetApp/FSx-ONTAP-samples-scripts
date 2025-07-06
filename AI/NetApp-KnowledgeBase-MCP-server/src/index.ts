import {McpServer} from "@modelcontextprotocol/sdk/server/mcp.js";
import {StdioServerTransport} from "@modelcontextprotocol/sdk/server/stdio.js";
import {z} from "zod";
import {listAllAvailableKnowledgeBases} from "./operations/wlmai-operations";
import {searchKnowledgeBase} from "./lib/netapp/wlmai/wlmai";
import {getLogger} from "./utils/logger";

const logger = getLogger();
const server = new McpServer({
    name: "NetApp Workload Factory GenAI MCP Server",
    version: "1.0.0"
}, {
    instructions: 'This is server that provides access to NetApp GenAI knowledge bases and allows to search them'
});

async function startServer() {
    logger.info('Start server');
    const {knowledgeBases, aiEngineId} = await listAllAvailableKnowledgeBases();
    logger.info('Received knowledge bases', JSON.stringify(knowledgeBases, null, 2) , 'defining tools');
    knowledgeBases.forEach(knowledgeBase => {
        const {id: knowledgeBaseId, name, description} = knowledgeBase;
        const toolName = `search_KB_${name}`.slice(0, 64).replaceAll(/[^a-zA-Z0-9_-]/g,'_'); // MCP tool names should be less than 64 characters
        server.tool(toolName, `Search knowledge base with description ${description}`, {
            question: z.string({description: 'Question to search the answer to in the knowledge base'})
        }, async ({question}) => {
            try {
                const documents = await searchKnowledgeBase(aiEngineId, knowledgeBaseId, question);
                return {
                    content: [{
                        type: 'text',
                        text: `${JSON.stringify(documents.map(document => ({
                            text: document.text,
                            fileName: document.fileName
                        })))}`
                    }]
                }
            } catch (error: any) {
                logger.error('Failed to retrieve AI Engines', error.message);
                return {
                    isError: true,
                    content: [{
                        type: 'text', text: JSON.stringify(error)
                    }]
                }
            }
        })
    });
    const transport = new StdioServerTransport();
    await server.connect(transport);
    logger.info('Server started and connected to transport');
}

startServer();