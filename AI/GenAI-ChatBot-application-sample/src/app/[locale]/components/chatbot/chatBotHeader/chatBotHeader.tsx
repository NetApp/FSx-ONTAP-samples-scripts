import styles from './chatBotHeader.module.scss';
import { _Classes } from '@/utils/cssHelper.util';
import HistoryIcon from '@/app/[locale]/svgs/chatbot/clock.svg';
import AddIcon from '@/app/[locale]/svgs/chatbot/add.svg';
import NotificationIcon from '@/app/[locale]/svgs/notification.svg';
import { KnowledgeBase } from '@/lib/api/api.types';
import { DsTypography } from '../../dsComponents/dsTypography/dsTypography';
import { useTranslation } from 'react-i18next';
import { DsPopover } from '../../dsComponents/dsPopover/dsPopover';

export type PanelType = 'history' | 'info'

interface ChatBotHeaderProps {
    isDisabled: boolean,
    knowledgebase?: KnowledgeBase,
    isSendMessageDisabled: boolean,
    setNewChatId: (chatId: string) => void,
    setIsExpanded: (panelType: PanelType) => void
}

const ChatBotHeader = ({ isDisabled, knowledgebase, isSendMessageDisabled, setNewChatId, setIsExpanded }: ChatBotHeaderProps) => {
    const { t } = useTranslation();

    return (
        <div className={_Classes(styles.chatBotHeader)}>
            <div className={_Classes(styles.leftWithKnowledgeName)}>
                <DsTypography isDisabled={isDisabled} variant='Regular_20' title={knowledgebase?.id ? knowledgebase.name : undefined} className={_Classes(styles.knowledgebaseName)}>{`${knowledgebase ? `"${knowledgebase?.name}"` : ''} ${t('genAI.chatBot.title')}`}</DsTypography>
            </div>
            <div className={_Classes(styles.right, { [styles.isDisabled]: isDisabled })}>
                <DsPopover placement="bottomLeft" trigger='hover' title={t('genAI.chatBot.newChat')}>
                    <AddIcon width={18} title={t('genAI.chatBot.newChat')} className={_Classes(styles.headerIcon, styles.addChatIcon, { [styles.disabled]: isSendMessageDisabled || isDisabled })} onClick={() => setNewChatId(Date.now().toString())} />
                </DsPopover>
                <NotificationIcon width={24} className={_Classes(styles.headerIcon, styles.infoIcon, { [styles.disabled]: isDisabled })} onClick={() => setIsExpanded('info')} />
                <DsPopover placement="bottomLeft" trigger='hover' className={_Classes(styles.headerIcon, styles.historyIcon)} title={t('genAI.chatBot.history.view')}>
                    <HistoryIcon alt={t('genAI.chatBot.history.view')} title={t('genAI.chatBot.history.view')} width={22} onClick={() => setIsExpanded('history')} />
                </DsPopover>
            </div>
        </div>
    )
}

export default ChatBotHeader;