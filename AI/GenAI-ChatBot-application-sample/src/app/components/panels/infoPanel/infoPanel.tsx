import { _Classes } from '@/utils/cssHelper.util';
import panelStyles from '../panel.module.scss';
import styles from './infoPanel.module.scss';
import PanelHeader from '../panelHeader/panelHeader';
import { PanelType } from '../../chatbot/chatBotHeader/chatBotHeader';
import { DsTypography } from '../../dsComponents/dsTypography/dsTypography';
import CopyIcon from '@/app/svgs/copy.svg';
import { copyToClipboard } from '@/utils/domUtils';
import { useAppSelector } from '@/lib/hooks';
import rootSelector from '@/lib/selectors/root.selector';

interface InfoPanelProps {
    isExpanded: boolean,
    toggleExpanded: (panelType: PanelType) => void
}

const InfoPanel = ({ isExpanded, toggleExpanded }: InfoPanelProps) => {
    const { id: knowledgebaseId } = useAppSelector(rootSelector.knowledgeBase);

    return (
        <div className={_Classes(styles.infoPanel, panelStyles.panel, { [panelStyles.expanded]: isExpanded })}>
            <PanelHeader title='Information' isLoading={false} panelType='info' toggleExpanded={toggleExpanded} />
            <div className={styles.infoItems}>
                <div className={styles.item}>
                    <DsTypography variant='Semibold_14'>ID</DsTypography>
                    <div className={styles.idCopy}>
                        <DsTypography variant='Regular_14'>{knowledgebaseId}</DsTypography>
                        <CopyIcon width={20} onClick={() => copyToClipboard(knowledgebaseId)} className={styles.copyIcon} />
                    </div>
                </div>
                <div className={styles.item}>
                    <DsTypography variant='Semibold_14'>Description</DsTypography>
                    <DsTypography variant='Regular_14'>{`An AI chatbot is a sophisticated blend of technologies that simulates human-like conversation through text or speech interfaces. These aren\'t your average chatbots that simply follow a script; AI chatbots are imbued with artificial intelligence, machine learning (ML), and natural language processing (NLP).`}</DsTypography>
                </div>
            </div>
        </div>
    )
}

export default InfoPanel