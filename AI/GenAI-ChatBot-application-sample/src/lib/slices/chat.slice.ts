import { createSlice, PayloadAction } from "@reduxjs/toolkit";
import { Chat, ChatMessage } from "../store.types";

const SLICE_NAME = 'chat';

export const initialState: Chat = {
    chatId: Date.now().toString(),
    messages: []
}

const chatSlice = createSlice({
    name: SLICE_NAME,
    initialState,
    reducers: {
        setMessage(state, action: PayloadAction<ChatMessage>) {
            const lastMessage = state.messages[state.messages.length - 1];
            const { payload } = action;
            state.messages.push({
                ...payload,
                date: payload.date || Date.now(),
                index: (lastMessage?.index || 0) + 1
            });
        },
        setChatId(state, action: PayloadAction<string>) {
            state.chatId = action.payload;
        },
        resetMessages(state) {
            state.messages = [];
        },
        resetChat(state) {
            return {
                ...initialState,
                chatId: Date.now().toString()
            }
        }
    }
})

export const { setMessage, resetChat, setChatId, resetMessages } = chatSlice.actions;

export default chatSlice;