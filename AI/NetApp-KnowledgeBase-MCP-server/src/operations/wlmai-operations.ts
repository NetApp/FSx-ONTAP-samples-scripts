import {getAiEngines, getKnowledgeBases} from "../lib/netapp/wlmai/wlmai";

async function* getKnowledgeBasesGenerator(aiEngineId:string){
    let { knowledgeBases, nextToken } = await getKnowledgeBases(aiEngineId);
    yield knowledgeBases;
    while (nextToken) {
        ({ knowledgeBases, nextToken } = await getKnowledgeBases(aiEngineId));
        yield knowledgeBases;
    }

}

async function listAllKnowledgeBases(aiEngineId:string){
    const knowledgeBases = [];
    for await (const knowledgeBasesPage of getKnowledgeBasesGenerator(aiEngineId)){
        knowledgeBases.push(...knowledgeBasesPage);
    }
    return knowledgeBases;
}

export async function listAllAvailableKnowledgeBases() {
    const [deployment,] = await getAiEngines(); // only one ai engine per tenancy account
    if (deployment){
        const {id,status} = deployment;
        if (status.server){
            const {server:{statusCode:serverStatusCode}} = status;
            if (serverStatusCode===200){
                const knowledgeBases = await listAllKnowledgeBases(id);
                return { aiEngineId: id,
                    knowledgeBases};
            }
        }
    }
    throw new Error('No Active AI-Engine found');
}