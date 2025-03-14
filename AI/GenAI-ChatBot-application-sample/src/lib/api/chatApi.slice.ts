import { ThunkDispatch } from "@reduxjs/toolkit";
import { apiSlice, BASE_URL } from "./api.slice";
import { History, Message } from "./api.types";
import { setMessage } from "../slices/chat.slice";
import { AiChatState } from "../store.types";
import initTranslations from "@/app/i18n";

interface ChatParams {
    knowledgeBaseId: string
}

interface ChatSocketParams extends ChatParams {
    chatId: string,
    question: string,
}

let socket: WebSocket;

const TEMP_STOP_REASON = 'TEMP_STOP_REASON';

export const closeSocket = () => {
    if (socket && socket.readyState === WebSocket.OPEN) {
        socket.close();
    }
}

const getSocket = async (args: { chatId: string, knowledgeBaseId: string, accessToken: string, question: string }, dispatch: ThunkDispatch<any, any, any>): Promise<{ socket: WebSocket, isSuccess: boolean }> => {
    const { chatId, accessToken, knowledgeBaseId, question } = args;

    const createWebSocket = (tries = 0) => {
        const BASE_HOST = `wss://${BASE_URL}/wlmai`;

        return new Promise(resolve => {
            if (socket) socket.close();
            socket = new WebSocket(`${BASE_HOST}/knowledge-bases/${knowledgeBaseId}/v1/chats/${chatId}?token=${accessToken}`);

            socket.onopen = () => {
                resolve(true);
            }

            socket.onerror = () => {
                socket.close();

                if (tries > 4) {
                    resolve(false);
                } else {
                    setTimeout(() => {
                        createWebSocket(tries + 1).then(isSuccess => {
                            resolve(isSuccess);
                        });
                    }, 1000);
                }
            }
        });
    }

    const waitForConnection = (accessToken: string, tries = 0): Promise<boolean> => {
        return new Promise(resolve => {
            setTimeout(() => {
                if (socket.readyState === WebSocket.OPEN) {
                    resolve(true);
                } else {
                    if (tries > 20) {
                        resolve(false);
                    } else {
                        waitForConnection(accessToken, tries + 1).then(isSuccess => {
                            resolve(isSuccess)
                        });
                    }
                }
            }, 100);
        });
    }

    const dispatchErrorMessage = async () => {
        const lang = process.env.NEXT_PUBLIC_LANGUAGE;
        const { t } = await initTranslations(lang, ['genAi']);

        dispatch(setMessage({
            question,
            answer: t('genAI.messages.errors.generalError'),
            stopReason: TEMP_STOP_REASON,
            type: 'ERROR',
            chatId
        }));
    }

    let newSocetCreated = false
    if (!socket || (socket.readyState !== WebSocket.OPEN && socket.readyState !== WebSocket.CONNECTING)) {
        const isSuccess = await createWebSocket();

        if (isSuccess) {
            newSocetCreated = true;
        } else {
            dispatchErrorMessage();

            return {
                socket,
                isSuccess: false
            }
        }
    }

    const isSuccess = await waitForConnection(accessToken);

    if (isSuccess) {
        if (newSocetCreated) {
            socket.addEventListener("message", (event: { data: string }) => {
                const message: Message = JSON.parse(event.data);

                dispatch(setMessage({ ...message, chatId }));
            });
        }
    } else {
        dispatchErrorMessage();
    }

    return {
        socket,
        isSuccess
    };
}

const chatApiSlice = apiSlice.injectEndpoints({
    endpoints: builder => ({
        sendMessage: builder.mutation<string, ChatSocketParams>({
            queryFn: ({ chatId, question, knowledgeBaseId }, api) => {
                const { dispatch, getState } = api;
                const { auth: { accessToken } } = getState() as AiChatState;

                return new Promise(resolve => {
                    if (accessToken) {
                        const bearer = accessToken.includes('Bearer') ? '' : 'Bearer ';
                        const bearerAccessToken = `${bearer}${accessToken}`;

                        getSocket({ chatId, accessToken: bearerAccessToken, question, knowledgeBaseId }, dispatch).then(response => {
                            const { socket, isSuccess } = response;

                            if (isSuccess) {
                                socket.send(question)
                            }

                            resolve({ data: question })
                        })
                    }
                })
            },
        }),
        getMessages: builder.query<History[], ChatParams>({
            query: ({ knowledgeBaseId }) => {
                return {
                    url: `knowledge-bases/${knowledgeBaseId}/v1/chats/history`
                }
            },
            transformResponse(baseQueryReturnValue, meta, arg) {
                const { history } = baseQueryReturnValue as { history: History[] };

                history.forEach(history => {
                    const { chatId } = history;

                    history.entries = history.entries.map(message => {
                        return {
                            ...message,
                            chatId,
                            stopReason: TEMP_STOP_REASON,
                        }
                    })
                });

                return history;
            },
            providesTags: result => result ? [
                ...result.map(({ chatId }) => ({ type: 'history' as const, chatId })),
                { type: 'history', id: 'LIST' }
            ] : [{ type: 'history', id: 'LIST' }]
        }),
        deleteChat: builder.mutation<void, { chatParams: ChatParams, chatId: string }>({
            query: ({ chatParams: { knowledgeBaseId }, chatId }) => {
                return {
                    url: `knowledge-bases/${knowledgeBaseId}/v1/chats/${chatId}`,
                    method: 'DELETE'
                }
            },
            invalidatesTags: [{ type: 'history', id: 'LIST' }]
        }),
    })
})

export const {
    useGetMessagesQuery,
    useSendMessageMutation,
    useDeleteChatMutation
} = chatApiSlice;