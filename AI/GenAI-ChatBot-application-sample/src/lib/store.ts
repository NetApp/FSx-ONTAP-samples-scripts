import { combineReducers, configureStore, Middleware } from '@reduxjs/toolkit'
import notificationsSlice from './slices/notifications.slice';
import { exposeMiddleWare } from './middleWares/exposeMiddleWare';
import chatSlice from './slices/chat.slice';
import { apiSlice } from './api/api.slice';
import authSlice from './slices/auth.slice';
import knowledgeBaseSlice from './slices/KnowledgeBase.slice';
import errorHandelingSlice from './slices/errorHandeling.slice';
import { errorHandelingMiddleware } from './middleWares/errorHandelingMiddleware';

const middlewares: Middleware[] = [
    exposeMiddleWare,
    errorHandelingMiddleware,
    apiSlice.middleware
];

const reducer = () => combineReducers({
    [apiSlice.reducerPath]: apiSlice.reducer,
    [authSlice.name]: authSlice.reducer,
    [notificationsSlice.name]: notificationsSlice.reducer,
    [chatSlice.name]: chatSlice.reducer,
    [knowledgeBaseSlice.name]: knowledgeBaseSlice.reducer,
    [errorHandelingSlice.name]: errorHandelingSlice.reducer
});

export const makeStore = () => {
    return configureStore({
        reducer: reducer(),
        middleware: getDefaultMiddleware =>
            getDefaultMiddleware({
                serializableCheck: false
            }).concat(middlewares)
    });
}

// Infer the type of makeStore
export type AppStore = ReturnType<typeof makeStore>
// Infer the `RootState` and `AppDispatch` types from the store itself
export type RootState = ReturnType<AppStore['getState']>
export type AppDispatch = AppStore['dispatch']