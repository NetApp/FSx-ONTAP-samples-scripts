import { createSlice, PayloadAction } from "@reduxjs/toolkit";
import { Notification } from "../store.types";

const SLICE_NAME = 'notifications';

export const initialState: Notification[] = [];

const notificationsSlice = createSlice({
    name: SLICE_NAME,
    initialState,
    reducers: {
        addNotification(state, action: PayloadAction<Notification>) {
            const { id, children, type, moreInfo, onClose } = action.payload;
            const exists = state.some(notif => notif.id === id && notif.type === type)
            if (!exists) {
                state.push({
                    id: id,
                    children: children,
                    type: type,
                    moreInfo: moreInfo,
                    onClose: onClose,
                });
            }
        },
        removeNotification(state, action: PayloadAction<string | undefined>) {
            const id = action.payload;
            const index = state.findIndex(notification => notification.id === id);
            const notifications = state.splice(index, 1);
            console.log(`Notification removed:`, notifications);
            if (notifications[0] && notifications[0]?.onClose) {
                notifications[0].onClose();
            }
        },
        clearNotifications(state) {
            return state.filter(notification => notification.persist);
        }
    }
});

export const { addNotification, removeNotification, clearNotifications } = notificationsSlice.actions;

export default notificationsSlice;
