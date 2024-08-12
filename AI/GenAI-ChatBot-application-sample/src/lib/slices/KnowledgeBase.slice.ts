import { createSlice, PayloadAction } from "@reduxjs/toolkit";
import { KnowledgeBase } from "../api/api.types";

const SLICE_NAME = 'knowledgeBase';

const initialState: KnowledgeBase = {
    id: '',
    name: '',
    description: "",
    conversationStarters: []
}

const knowledgeBaseSlice = createSlice({
    name: SLICE_NAME,
    initialState,
    reducers: {
        setKnowledgeBaseId(state, action: PayloadAction<string>) {
            state.id = action.payload;
        }
    }
})

export const { setKnowledgeBaseId } = knowledgeBaseSlice.actions;

export default knowledgeBaseSlice;