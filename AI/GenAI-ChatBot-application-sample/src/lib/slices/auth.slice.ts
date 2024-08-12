import { createSlice } from "@reduxjs/toolkit";
import type { PayloadAction } from "@reduxjs/toolkit";
import { Auth } from "../store.types";

const SLICE_NAME = 'auth';

export const initialState: Auth = {
    isSuccess: false
};

const authSlice = createSlice({
    name: SLICE_NAME,
    initialState: initialState,
    reducers: {
        resetAuth(state) {
            localStorage.setItem('genAi', JSON.stringify(initialState))
            return initialState;
        },
        setAuth(state, action: PayloadAction<Auth>) {
            localStorage.setItem('genAi', JSON.stringify(action.payload))
            return action.payload;
        },
        
    }
});

export const { setAuth, resetAuth } = authSlice.actions;

export default authSlice;