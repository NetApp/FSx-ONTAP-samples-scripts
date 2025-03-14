'use client';

import React, { KeyboardEvent, ReactElement, useEffect, useMemo, useRef, useState } from 'react';
import './chatbot.scss'
import SendIcon from "@/app/[locale]/svgs/chatbot/send.svg";
import EnterpriseChatIcon from "@/app/[locale]/svgs/chatbot/enterpriseChat.svg";
import EmptyPromptIcon from '@/app/[locale]/svgs/chatbot/emptyPrompt.svg';
import LoadingIcon from '@/app/[locale]/svgs/loaderMain.svg';
import Prompt, { PromptItem, UserType } from './prompt/prompt';
import { closeSocket, useGetMessagesQuery, useSendMessageMutation } from '@/lib/api/chatApi.slice';
import { skip } from '@/lib/api/api.slice';
import rootSelector from '@/lib/selectors/root.selector';
import { ChatMessage } from '@/lib/store.types';
import { resetMessages, setChatId } from '@/lib/slices/chat.slice';
import ChatBotHeader, { PanelType } from './chatBotHeader/chatBotHeader';
import { useAppDispatch, useAppSelector, useAppStore } from '@/lib/hooks';
import { DsTypography } from '../dsComponents/dsTypography/dsTypography';
import { DsSelect, DsSelectItemProps } from '../dsComponents/dsSelect/dsSelect';
import { DsTextField } from '../dsComponents/dsTextField/dsTextField';
import { _Classes } from '@/utils/cssHelper.util';
import { DsCard } from '../dsComponents/dsCard/dsCard';
import { useGetKnowledgebasesQuery } from '@/lib/api/knowledgeBaseApi.slice';
import { ErrorApi } from '@/lib/api/api.types';
import HistoryPanel from '../panels/historyPanel/historyPanel';
import InfoPanel from '../panels/infoPanel/infoPanel';
import { useTranslation } from 'react-i18next';

const Chatbot = () => {
    const { t } = useTranslation();
    const dispatch = useAppDispatch();
    const initialPanelState = new Map<PanelType, boolean>([
        ['history', false],
        ['info', false]
    ]);
    const sendMessageInputContainerRef = useRef<HTMLDivElement>(null);
    const chatAreaRef = useRef<HTMLDivElement>(null);

    const [message, setMessageInput] = useState<string>('');
    const [panelsMap, setPanelsMap] = useState<Map<PanelType, boolean>>(initialPanelState);
    const [question, setQuestion] = useState<ChatMessage[]>([]);

    const { getState } = useAppStore();
    const { isSuccess: isSuccessAuth } = useAppSelector(rootSelector.auth);
    const { messages: newMessages, chatId } = useAppSelector(rootSelector.chat);
    const { id: knowledgebaseId } = useAppSelector(rootSelector.knowledgeBase);

    const { data: knowledgebase, error } = useGetKnowledgebasesQuery({ knowledgebaseId, isSelfHandleErrors: true }, { skip: skip(getState(), !isSuccessAuth || !knowledgebaseId) });
    const { data: { message: errorMessage } = {} } = (error || {}) as ErrorApi;

    const { data: historyList = [], isLoading, isFetching, refetch } = useGetMessagesQuery({ knowledgeBaseId: knowledgebase?.id! }, { skip: skip(getState(), !knowledgebase?.id) });
    const [createMessage] = useSendMessageMutation();

    const messageListFromHistory = useMemo<ChatMessage[]>(() => {
        const list: ChatMessage[] = [];

        historyList.forEach(history => {
            const { chatId } = history;

            list.push(...history.entries.map<ChatMessage>(entry => {
                return {
                    ...entry,
                    chatId
                }
            }));
        })

        return list;
    }, [historyList]);

    const sortedMessageList: ChatMessage[] = useMemo(() => {
        return ([...messageListFromHistory, ...newMessages, ...question] as ChatMessage[]).filter(message => message.chatId === chatId).sort((mess1, mess2) => {
            return (mess1.index || 0) - (mess2.index || 0);
        });
    }, [chatId, newMessages, question, messageListFromHistory]);

    const promptList: PromptItem[] = useMemo(() => {
        const createQuestionAnswer = (chatId: string, message: ChatMessage): PromptItem[] => {
            return [{
                chatId: message.chatId || chatId,
                user: 'USER',
                message: message.question,
                question: message.question,
                date: message.date,
                isWriting: false,
                isTemp: false,
                type: message.type
            }, {
                chatId: message.chatId || chatId,
                user: 'BOT',
                message: message.answer,
                question: message.question,
                date: message.date,
                isWriting: !message.stopReason,
                isTemp: false,
                filesData: message.filesData,
                type: message.type
            }]
        }

        return sortedMessageList.reduce((prompts: PromptItem[], message: ChatMessage) => {
            const { answer, stopReason, index, date, filesData, type } = message;
            const isMessageHistory = index === undefined;
            const isNewQuestion = (prompts.length === 0 || (prompts.length > 1 && !prompts[prompts.length - 1].isWriting));

            if (isMessageHistory || isNewQuestion) {
                prompts.push(...createQuestionAnswer(chatId, message));
            } else {
                // Another response to the same message
                const lastPrompt = prompts[prompts.length - 1];

                if (lastPrompt) {
                    lastPrompt.message += answer;
                    lastPrompt.date = date;
                    lastPrompt.isWriting = !stopReason;
                    lastPrompt.filesData = filesData;
                    lastPrompt.type = type;
                }
            }

            return prompts
        }, []) || [];

    }, [sortedMessageList, chatId]);

    const allUniqueStartersList = useMemo<string[]>(() => {
        const map: { [key: string]: string } = {};
        const { conversationStarters = [] } = knowledgebase || {};

        conversationStarters.forEach(starter => map[starter] = starter);

        return Object.keys(map);
    }, [knowledgebase]);

    const randomStarters = useMemo((): string[] => {
        const numIndexes = Math.min(allUniqueStartersList.length, 4);
        const starters: string[] = [];

        while (starters.length < numIndexes) {
            const rand = Math.floor(Math.random() * allUniqueStartersList.length);
            if (!starters.includes(allUniqueStartersList[rand])) {
                starters.push(allUniqueStartersList[rand]);
            }
        }

        return starters.sort((starter1, starter2) => starter2 > starter1 ? 1 : -1);
    }, [allUniqueStartersList])

    const histories = useMemo(() => {
        const list = [...promptList, ...messageListFromHistory];
        return list ? list.reduce((entryMap, e) => {
            return entryMap.set(e.chatId, [...entryMap.get(e.chatId) || [], e])
        }, new Map()) : new Map();

    }, [messageListFromHistory, promptList]);

    const emptyChatContent = useMemo((): {
        svg: ReactElement,
        description: ReactElement
    } => {
        const descriptionForNoStarters = () => {
            return (
                <ul className="descriptionList">
                    <li>
                        <DsTypography variant="Regular_16">{t('genAI.chatBot.emptyChat.noStarters.bullet1')}</DsTypography>
                    </li>
                    <li>
                        <DsTypography variant="Regular_16">{t('genAI.chatBot.emptyChat.noStarters.bullet2')}</DsTypography>
                    </li>
                </ul>
            )
        }

        return {
            svg: <EnterpriseChatIcon className='emptyChatIcon' width={180} />,
            description: randomStarters.length === 0 ? descriptionForNoStarters() : <DsTypography variant='Regular_16' className='descriptionForStarters'>{t('genAI.chatBot.emptyChat.subTitle')}</DsTypography>
        }
    }, [randomStarters.length, t]);

    const resetQuestion = () => {
        setQuestion([]);
    }

    // reset the question once starting to get socket response
    useEffect(() => {
        if (newMessages.length > 0) {
            resetQuestion();
        }
    }, [newMessages]);

    useEffect(() => {
        if (!isFetching) {
            dispatch(resetMessages());
        }
    }, [isFetching, dispatch]);

    useEffect(() => {
        closeSocket();
        resetQuestion();
        dispatch(resetMessages());
    }, [dispatch, chatId])

    useEffect(() => {
        if (promptList.length > 0) {
            const index = promptList.length - 1;
            setTimeout(() => {
                const scrollElement = document.getElementById(generateUniqueId(index, 'BOT'));
                scrollElement?.scrollIntoView({ behavior: "smooth", block: 'start' });
            }, 300);
        }
    }, [promptList])

    const generateUniqueId = (index: number, user: UserType) => {
        return `uniqueMessageId--${index}--${user}`;
    }

    const sendMessage = (newMessage: string = message) => {
        if (newMessage) {
            sendMessageInputContainerRef.current?.focus();

            setQuestion([{
                chatId: chatId!,
                question: newMessage,
                answer: '',
                stopReason: null,
                index: (newMessages[newMessages.length - 1]?.index || 0),
                type: 'ANSWER'
            }]);

            createMessage({
                chatId: chatId!,
                question: newMessage,
                knowledgeBaseId: knowledgebase?.id!
            });

            setMessageInput('');
        }
    }

    const isSendMessageDisabled = useMemo(() => {
        const isWriting = promptList[promptList.length - 1]?.isWriting;
        const isDisabled = !knowledgebase || !chatId || isWriting;

        if (!isDisabled) {
            setTimeout(() => {
                const input = document.querySelector(".chatPromptInput input") as HTMLInputElement;
                if (input) {
                    input.focus();
                }
            }, 0);
        }

        return isDisabled;
    }, [knowledgebase, chatId, promptList])

    const setNewChatId = (chatId: string) => {
        dispatch(setChatId(chatId));
        refetch();
    }

    const ConversationStarterPrompts = () => {
        const conversationPrompts: ReactElement[] = [];
        const listLength = randomStarters.length;

        for (let i = 0; i < listLength; i++) {
            const title = randomStarters && randomStarters.length > 0 ? randomStarters[i] : undefined;

            conversationPrompts.push(
                <DsTypography
                    onClick={() => title ? sendMessage(title) : {}}
                    key={`conversationStarter_${i}`}
                    isDisabled={isSendMessageDisabled}
                    title={title}
                    variant='Regular_14'
                    className={`conversationStarter clickable`}>
                    <div className="promptContainer">
                        {title}
                    </div>
                </DsTypography>
            )
        }

        return (
            <>
                {listLength > 0 ? <div className={`conversationStarterContainer ${listLength < 4 ? 'colStyle' : ''}`}>{conversationPrompts.length > 0 ? conversationPrompts : ''}</div> : <></>}
            </>
        )
    }

    const toggleExpanded = (panelType: PanelType) => {
        const expanded = panelsMap.get(panelType);
        panelsMap.set(panelType, !expanded);

        if (!expanded) {
            const otherPanel: PanelType = panelType === 'history' ? 'info' : 'history';
            panelsMap.set(otherPanel, false);
        }

        setPanelsMap(new Map(panelsMap));
    }

    return (
        <div className='chatbotContaier' id='box'>
            <div className={_Classes('chatbot', { isPanelExpanded: !!panelsMap.get('history') || !!panelsMap.get('info') })}>
                <ChatBotHeader
                    isDisabled={!knowledgebase}
                    isSendMessageDisabled={isSendMessageDisabled}
                    knowledgebase={knowledgebase}
                    setIsExpanded={toggleExpanded}
                    setNewChatId={setNewChatId} />
                <div className="content">
                    <div className={_Classes('chatArea', { emptyChat: promptList?.length === 0 })} ref={chatAreaRef}>
                        {knowledgebase && <DsSelect
                            className={`allConversationStarters`}
                            variant='underline'
                            options={allUniqueStartersList.map((starter, index): DsSelectItemProps => {
                                return {
                                    id: index,
                                    label: starter,
                                    value: starter,
                                }
                            })}
                            onSelect={selectedOption => sendMessage(selectedOption[0].value)}
                            placeholder={t('genAI.chatBot.conversationStarters')}
                            isDisabled={isSendMessageDisabled || allUniqueStartersList.length === 0}
                            isCleanable={false}
                            selectedOptionIds={[-1]} />}

                        {knowledgebase && <>
                            {promptList?.length === 0 && <div className="emptyChatContainer">
                                <div className="emptyChatDescriptionContainer">
                                    {emptyChatContent.svg}
                                    <DsTypography isDisabled={!knowledgebase} variant='Semibold_20'>{t('genAI.chatBot.emptyChat.title')}</DsTypography>
                                    <div className='emptyChatDescription'>{emptyChatContent.description}</div>
                                </div>
                                {<ConversationStarterPrompts />}
                            </div>}
                            {promptList?.length > 0 && <div className="chatListContainer">
                                <div className="chatList">
                                    {promptList.filter(message => message.chatId === chatId).map((prompt, index) => {
                                        return <Prompt id={generateUniqueId(index, prompt.user)} key={index} prompt={prompt}
                                            className='prompt' chatAreaRef={chatAreaRef} />
                                    })}
                                </div>
                            </div>}
                        </>}
                        {!knowledgebase && <>
                            {errorMessage && <div className='disabledChatContainer'>
                                <DsCard className='disabledChatCard'>
                                    <EmptyPromptIcon width={48} />
                                    <DsTypography variant='Semibold_20'>{t('genAI.chatBot.notAvailable')}</DsTypography>
                                    <DsTypography variant="Regular_14" isDisabled className='disabledChatDescription'>{errorMessage}</DsTypography>
                                </DsCard>
                            </div>}
                            {!errorMessage && <LoadingIcon width={60} className='loadingChatIcon' />}
                        </>}
                    </div>
                    <div className="discussion" tabIndex={0} ref={sendMessageInputContainerRef}>
                        <div className="textArea">
                            <DsTextField
                                isDisabled={isSendMessageDisabled}
                                className='chatPromptInput'
                                isCleanable={false}
                                value={message}
                                onChange={event => setMessageInput(event!.target.value)}
                                onKeyDown={(event: KeyboardEvent<HTMLInputElement>) => event.key === 'Enter' && sendMessage()} />
                            <div className='sendContainer'>
                                <SendIcon width={28} className={`sendButton ${isSendMessageDisabled || !knowledgebase ? 'disabled' : ''}`} onClick={() => sendMessage()} />
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            <HistoryPanel
                historyList={histories}
                isExpanded={!!panelsMap.get('history')}
                isLoading={isLoading || isFetching}
                promptList={promptList}
                setNewChatId={setNewChatId}
                toggleExpanded={toggleExpanded} />
            <InfoPanel isExpanded={!!panelsMap.get('info')} toggleExpanded={toggleExpanded} />
        </div>
    )
}

export default Chatbot;