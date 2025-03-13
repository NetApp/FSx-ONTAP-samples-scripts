export type Protocol = 'NFS' | 'SMB';
export type ProgressStatus = 'FAILED' | 'DONE' | 'RUNNING';
export type EmbeddingStatus = 'EMBEDDING' | 'EMBEDDED' | 'DONE' | 'FAILED';
export type ChunkingStrategy = 'sentences' | 'words' | 'characters';
export type MessageType = 'ANSWER' | 'ERROR';
export type LoginProvider = 'cognito' | 'clerk';

export interface SignInResultCognito extends SignInResult {
    doLogin: (email?: string, password?: string, externalProviderName?: string) => void,
}

export interface SignInResultClerk extends SignInResult {
    doLogin: (email?: string, password?: string) => void,
}

interface SignInResult {
    isLoading: boolean,
    email?: string,
    password?: string,
    jwtToken?: string,
    error?: string,
    userName?: string
}

export interface ErrorApi {
    data: {
        error: string,
        message: string,
        statusCode: string
    },
    status: string
}

export interface ApiRequest {
    //Prevent the default notification error to popup
    isSelfHandleErrors?: boolean
}

export interface ApiResponse<T> {
    isError: boolean,
    isFetching: boolean,
    isLoading: boolean,
    isSuccess: boolean,
    data?: T[],
    error?: any,
    refetch?: () => void
}

export interface PaginationApiResponse<T> {
    isError: boolean,
    isFetching: boolean,
    isLoading: boolean,
    isSuccess: boolean,
    data?: T,
    error?: any,
    refetch?: () => void
}

export interface Model {
    id: string,
    name: string,
    isSupported: boolean
}

export interface DataSource {
    id: string,
    directoryPath: string,
    volumePath: string,
    fsxName: string,
    volumeName: string,
    fsxId: string,
    ip: string,
    protocol: Protocol,
    lastScanned: number,
    embeddingStatus: EmbeddingStatus,
    embeddingStatusReason: string,
    chunkingStrategy: ChunkingStrategy,
    statistic: {
        size: number,
        chunksEmbedded: number,
        chunksFailed: number,
        filesWereRead: number,
        filesFailedToRead: number
    },
    filterByPermissions: boolean
}

export enum AuthAlgorithm {
    HS256 = 'HS256',
    RS256 = 'RS256',
    PS256 = 'PS256'
}

export interface AuthSetting {
    algorithm: AuthAlgorithm,
    audience: string,
    issuer: string,
    jwks: string
}

export interface KnowledgeBase {
    id: string,
    name: string,
    description?: string,
    conversationStarters: string[]
}

export interface History {
    chatId: string,
    entries: Message[]
}

export interface FileData {
    fileName: string,
    text: string
}

export interface Message {
    date?: number,
    userId?: string,
    question: string,
    answer: string,
    filesData?: FileData[],
    stopReason: null | string,
    type: MessageType
}