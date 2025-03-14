import { NotificationProps } from "@/app/[locale]/components/dsComponents/Notification";
import notificationsSlice from "./slices/notifications.slice";
import chatSlice from "./slices/chat.slice";
import authSlice from "./slices/auth.slice";
import knowledgeBaseSlice from "./slices/KnowledgeBase.slice";
import { KnowledgeBase } from "./api/api.types";
import errorHandelingSlice from "./slices/errorHandeling.slice";

export type MessageType = 'ANSWER' | 'ERROR';

export interface AiChatState {
    [authSlice.name]: Auth,
    [notificationsSlice.name]: Notification[],
    [chatSlice.name]: Chat,
    [knowledgeBaseSlice.name]: KnowledgeBase,
    [errorHandelingSlice.name]: ErrorHandeling
}

export interface ErrorHandeling {
    selfeHandleErrorRequestIds: string[]
}

export interface Auth {
    isSuccess: boolean,
    accessToken?: string,
    error?: { needLogin: any } | string,
    userName?: string
}

export interface Notification extends NotificationProps {
    id: string | undefined,
    onClose?: () => void,
    persist?: boolean
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

export interface ChatMessage extends Message {
    index?: number
    chatId: string
}

export interface Chat {
    messages: ChatMessage[]
    chatId: string
}