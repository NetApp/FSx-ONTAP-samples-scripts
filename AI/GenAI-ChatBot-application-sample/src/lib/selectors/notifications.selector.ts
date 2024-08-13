import { AiChatState } from "../store.types";
import rootSelector from "./root.selector";

const getNotifications = rootSelector.notifications;

export const notificationsSelector = {
    getNotificationById(state: AiChatState, id: string) {
        return getNotifications(state).find(notification => notification.id === id);
    }
}