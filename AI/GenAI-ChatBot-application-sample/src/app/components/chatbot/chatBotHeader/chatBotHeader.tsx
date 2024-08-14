import styles from './chatBotHeader.module.scss';
import { _Classes } from '@/utils/cssHelper.util';
import HistoryIcon from '@/app/svgs/chatbot/clock.svg';
import AddIcon from '@/app/svgs/chatbot/add.svg';
import NotificationIcon from '@/app/svgs/notification.svg';
import { KnowledgeBase } from '@/lib/api/api.types';
import { DsTypography } from '../../dsComponents/dsTypography/dsTypography';
import { Popover } from '../../dsComponents/Popover';

export type PanelType = 'history' | 'info'

interface ChatBotHeaderProps {
    isDisabled: boolean,
    knowledgebase?: KnowledgeBase,
    isSendMessageDisabled: boolean,
    setNewChatId: (chatId: string) => void,
    setIsExpanded: (panelType: PanelType) => void
}

const ChatBotHeader = ({ isDisabled, knowledgebase, isSendMessageDisabled, setNewChatId, setIsExpanded }: ChatBotHeaderProps) => {
    return (
        <div className={_Classes(styles.chatBotHeader)}>
            <div className={_Classes(styles.leftWithKnowledgeName)}>
                <DsTypography isDisabled={isDisabled} variant='Regular_20' title={knowledgebase?.id ? knowledgebase.name : undefined} className={_Classes(styles.knowledgebaseName)}>{`${knowledgebase ? `"${knowledgebase?.name}"` : ''} chatbot`}</DsTypography>
            </div>
            <div className={_Classes(styles.right, { [styles.isDisabled]: isDisabled })}>
                <Popover placement="bottom-start" trigger={"hover"} container={<AddIcon width={18} title='New chat' className={_Classes(styles.headerIcon, styles.addChatIcon, { [styles.disabled]: isSendMessageDisabled || isDisabled })} onClick={() => setNewChatId(Date.now().toString())} />}>
                    <DsTypography variant="Regular_14">Start new chat</DsTypography>
                </Popover>
                <NotificationIcon width={24} className={_Classes(styles.headerIcon, styles.infoIcon, { [styles.disabled]: isDisabled })} onClick={() => setIsExpanded('info')} />
                <HistoryIcon alt="Open chat history" title='View history' width={22} className={_Classes(styles.headerIcon, styles.historyIcon)} onClick={() => setIsExpanded('history')} />
            </div>
        </div>
    )
}

export default ChatBotHeader;