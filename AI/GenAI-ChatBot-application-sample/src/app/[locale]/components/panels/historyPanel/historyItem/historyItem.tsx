import React, { FunctionComponent, useMemo } from "react";
import './historyItem.scss';
import BaloonIcon from "@/app/[locale]/svgs/chatbot/baloon.svg";
import ContextMenuIcon from '@/app/[locale]/svgs/chatbot/actionMenu.svg';
import { PromptItem } from "../../../chatbot/prompt/prompt";
import DeleteChatModal from "../../../modals/deleteChatModal/deleteChatModal";
import { formatDate } from "@/utils/formatterUtils";
import { useDialog } from "../../../dsComponents/Dialog";
import { DsTypography } from "../../../dsComponents/dsTypography/dsTypography";
import { DsButton } from "../../../dsComponents/dsButton/dsButton";
import { DsDropDownListItemProps } from "../../../dsComponents/dsDropDownList/dsDropDownList";
import { useTranslation } from "react-i18next";

interface HistoryItemProps {
    history: { messages: PromptItem[] }
    onClick: (...args: any) => void,
    chatId: string,
    selectedChatId?: string,
    knowledgeBaseId: string
}

const HistoryItem: FunctionComponent<HistoryItemProps> = ({ chatId, history, selectedChatId, onClick, knowledgeBaseId }) => {
    const { t } = useTranslation();

    const { messages } = history;
    const { setDialog } = useDialog();

    const isActive = useMemo(() => {
        return messages[0].chatId === selectedChatId;
    }, [selectedChatId, messages]);

    const historyItem = useMemo(() => {
        const firstMessage = messages.filter(message => message.date).sort((mess1, mess2) => mess1.date! - mess2.date!);
        return firstMessage[0] ? firstMessage[0] : messages[0];
    }, [messages]);

    const dropDownItems = useMemo((): DsDropDownListItemProps[] => {
        const items: DsDropDownListItemProps[] = [{
            id: '1',
            label: t('genAI.chatBot.history.delete'),
            onClick: async () => {
                setDialog(
                    <DeleteChatModal chatIds={[chatId]} chatMessage={historyItem.question} variant='single' knowledgeBaseId={knowledgeBaseId} />
                );
            }
        }]

        return items;
    }, [t, setDialog, chatId, historyItem.question, knowledgeBaseId]);

    return (
        <>
            {messages.length > 0 && <div className={`historyItem ${isActive ? 'active' : ''}`}>
                <div className="historyItemContainer" onClick={onClick}>
                    <BaloonIcon className="baloonIconCol" width={24} height={20} />
                    <div className="historyCol">
                        <DsTypography title={historyItem.question} variant="Regular_14" className="historyTitle">{historyItem.question}</DsTypography>
                        <DsTypography variant="Regular_12"
                            className="modeStatus">{formatDate(historyItem.date || Date.now())}</DsTypography>
                    </div>
                </div>
                <DsButton type="icon" className='historyMenu' icon={<ContextMenuIcon width={32} height={16} />} dropDown={{
                    placement: 'alignRight',
                    items: dropDownItems
                }} />
            </div>}
        </>
    )
}

export default HistoryItem;