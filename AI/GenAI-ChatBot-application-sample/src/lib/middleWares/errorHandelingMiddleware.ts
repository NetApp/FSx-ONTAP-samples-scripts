import { isRejectedWithValue } from '@reduxjs/toolkit'
import type { MiddlewareAPI, Middleware } from '@reduxjs/toolkit'
import { addNotification } from "../slices/notifications.slice";
import { AiChatState } from '../store.types';
import { removeSelfeHandleErrorRequestId } from '../slices/errorHandeling.slice';

export const errorHandelingMiddleware: Middleware = (api: MiddlewareAPI) => (next) => (action) => {
    const { dispatch, getState } = api;
    const { errorHandeling: { selfeHandleErrorRequestIds } } = getState() as AiChatState;


    if (isRejectedWithValue(action)) {
        const { requestId } = action.meta;

        if (selfeHandleErrorRequestIds.indexOf(requestId) > -1) {
            dispatch(removeSelfeHandleErrorRequestId(requestId));
        } else {
            const { error, data, status, originalStatus } = action.payload || {} as any;

            const original = originalStatus ? `${originalStatus} - ` : ''
            let message = data?.message || error;
            let moreInfo = null;
            if ((message && message.length > 214)) {
                moreInfo = message;
                message = 'General error';
            } else if (status === 'FETCH_ERROR') {
                moreInfo = message;
                message = 'Failed to connect';
            }

            dispatch(addNotification({
                children: JSON.stringify(message),
                id: status || originalStatus || requestId,
                type: 'error',
                moreInfo: moreInfo ? `${original} ${moreInfo}` : null
            }));
        }
    }

    return next(action)
}