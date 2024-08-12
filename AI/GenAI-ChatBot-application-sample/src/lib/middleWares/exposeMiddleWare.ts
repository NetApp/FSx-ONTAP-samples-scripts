import { Middleware } from "@reduxjs/toolkit"
import { AiChatState } from "../store.types";

declare global {
    interface Window {
        __$$expose: AiChatState
    }
}

export const exposeMiddleWare: Middleware = api => next => action => {
    const nextAction = next(action);

    if (typeof window !== "undefined") {
        window.__$$expose = api.getState();
    }

    return nextAction;
}
