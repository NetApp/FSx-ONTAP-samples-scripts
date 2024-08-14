import { createSlice, PayloadAction } from "@reduxjs/toolkit";
import { ErrorHandeling } from "../store.types";

const SLICE_NAME = 'errorHandeling';

export const initialState: ErrorHandeling = {
    selfeHandleErrorRequestIds: []
}

const errorHandelingSlice = createSlice({
    name: SLICE_NAME,
    initialState,
    reducers: {
        addSelfeHandleErrorRequestId(state, action: PayloadAction<string>) {
            if (state.selfeHandleErrorRequestIds.indexOf(action.payload) === -1) {
                state.selfeHandleErrorRequestIds.push(action.payload);
            }
        },
        removeSelfeHandleErrorRequestId(state, action: PayloadAction<string>) {
            const index = state.selfeHandleErrorRequestIds.indexOf(action.payload);
            state.selfeHandleErrorRequestIds.splice(index, 1);
        }
    }
})

export const {
    addSelfeHandleErrorRequestId,
    removeSelfeHandleErrorRequestId
} = errorHandelingSlice.actions;

export default errorHandelingSlice;