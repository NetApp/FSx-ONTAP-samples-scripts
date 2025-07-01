import got from 'got';
import {WLMAI_URL} from "../../../utils/consts";
import {getToken} from "../../../utils/service-token-utils";
export interface Deployment {
    id:string,
    stackId:string,
    credentialsId:string,
    creationDate:number,
    placement:{
        awsAccountId:string,
        regionInfo:{
            code:string,
            name:string
        },
        subnetId:string,
        vpceId:string
        keyPair:string
        instanceType:string
        instanceId:string
    },
    status:{
        ssm:{status:string},
        instance:{status:string},
        server:{statusCode:number}
    }
}

export interface Document {
    text:string, fileName:string
}

export interface KnowledgeBase {
    id: string,
    name: string,
    description?: string,
    isPublished: boolean,
    isClassificationEnabled: boolean,
    embeddingModelInfo: {
        id: string,
        name?: string
    },
    rerankingModelInfo: {
        id: string,
        name?: string
    },
    chatModelInfo: {
        id: string,
        name?: string
    },
    conversationStartersMode: string,
    date: number,
    conversationStarters: string[],
    authSetting: {},
    volumeName: string,
    fsxId: string,
    fsxName?: string,
    fsxSvmId: string,
    fsxSvmName?: string,
    volumeId: string,
    scheduleScan: boolean,
    nextScan: number,
    lastScanned?: number,
    dataSourcesSummary: { embedding: number, embedded: number, failed: number }
}
export async function getAiEngines(){
    console.log(`${WLMAI_URL}/accounts/${process.env.ACCOUNT_ID}/wlmai/v1/deployments`);
    const {deployments = []} = await got.get(`${WLMAI_URL}/accounts/${process.env.ACCOUNT_ID}/wlmai/v1/deployments`, {
        headers:{
            authorization: await getToken()
        }
    }).json<{deployments:Deployment[]}>();
    return deployments;
}

export async function getKnowledgeBases( deploymentId:string){
    const {knowledgeBases = [], nextToken}  = await got.get(`${WLMAI_URL}/accounts/${process.env.ACCOUNT_ID}/wlmai/v2/deployments/${deploymentId}/knowledge-bases`, {
        headers:{
            authorization: await getToken()
        }
    }).json<{knowledgeBases:KnowledgeBase[], nextToken?:string}>()
    return {knowledgeBases, nextToken};
}

export async function searchKnowledgeBase(aiEngineId:string, knowledgeBaseId:string, question:string){
    const {documents = []}  = await got.post(`${WLMAI_URL}/accounts/${process.env.ACCOUNT_ID}/wlmai/v1/deployments/${aiEngineId}/knowledge-bases/${knowledgeBaseId}/search`, {
        headers:{
            authorization: await getToken()
        },
        json:{
            question
        }
    }).json<{documents:Document[]}>();
    return documents;
}
