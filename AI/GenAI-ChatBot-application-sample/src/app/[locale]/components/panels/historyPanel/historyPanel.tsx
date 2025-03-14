import { _Classes } from '@/utils/cssHelper.util';
import styles from './historyPanel.module.scss';
import panelStyles from '../panel.module.scss';
import PanelHeader from '../panelHeader/panelHeader';
import { PanelType } from '../../chatbot/chatBotHeader/chatBotHeader';
import { PromptItem } from '../../chatbot/prompt/prompt';
import BaloonIcon from "@/app/[locale]/svgs/chatbot/baloon.svg";
import HistoryItem from './historyItem/historyItem';
import { useAppSelector } from '@/lib/hooks';
import rootSelector from '@/lib/selectors/root.selector';
import { DsTypography } from '../../dsComponents/dsTypography/dsTypography';
import { useTranslation } from 'react-i18next';

interface HistoryPanelProps {
    isExpanded: boolean,
    isLoading: boolean,
    toggleExpanded: (panelType: PanelType) => void,
    promptList: PromptItem[],
    historyList: Map<any, any>,
    setNewChatId: (chatId: string) => void
}

const HistoryPanel = ({ isExpanded, isLoading, promptList, historyList, toggleExpanded, setNewChatId }: HistoryPanelProps) => {
    const { t } = useTranslation();
    const { chatId } = useAppSelector(rootSelector.chat);
    const { id: knowledgebaseId } = useAppSelector(rootSelector.knowledgeBase);

    return (
        <div className={_Classes(styles.chatHistory, panelStyles.panel, { [panelStyles.expanded]: isExpanded })}>
            <PanelHeader title={t('genAI.chatBot.history.title')} isLoading={isLoading} panelType='history' toggleExpanded={toggleExpanded} />
            <div className={_Classes(styles.historyList, { [styles.emptyHistory]: promptList.length === 0 && historyList.size === 0 })}>
                {promptList.length > 0 || historyList.size > 0 ? Array.from(historyList.keys()).sort((hist1, hist2) => hist2 - hist1).map(id => {
                    return (
                        <HistoryItem key={id}
                            history={{
                                messages: historyList.get(id)
                            }}
                            chatId={id}
                            onClick={() => setNewChatId(id)}
                            selectedChatId={chatId}
                            knowledgeBaseId={knowledgebaseId} />
                    )
                }) : <></>}
                {promptList.length === 0 && historyList.size === 0 && <div className={styles.emptryHistoryContainer}>
                    <BaloonIcon width={24} />
                    <DsTypography variant='Regular_14'>{t('genAI.chatBot.history.empty')}</DsTypography>
                </div>}
            </div>
        </div>
    )
}

export default HistoryPanel;