import { KnowledgeBase } from "../api/api.types";
import { AiChatState, Auth, Chat, Notification } from "../store.types";

const rootSelector = {
    auth(state: AiChatState): Auth {
        return state.auth
    },
    notifications(state: AiChatState): Notification[] {
        return state.notifications;
    },
    chat(state: AiChatState): Chat {
        return state.chat;
    },
    knowledgeBase(state: AiChatState): KnowledgeBase {
        return state.knowledgeBase
    }
}

export default rootSelector;