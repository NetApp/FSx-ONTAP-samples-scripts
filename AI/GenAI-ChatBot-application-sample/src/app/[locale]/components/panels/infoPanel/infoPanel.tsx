import { _Classes } from '@/utils/cssHelper.util';
import panelStyles from '../panel.module.scss';
import styles from './infoPanel.module.scss';
import PanelHeader from '../panelHeader/panelHeader';
import { PanelType } from '../../chatbot/chatBotHeader/chatBotHeader';
import { DsTypography } from '../../dsComponents/dsTypography/dsTypography';
import CopyIcon from '@/app/[locale]/svgs/copy.svg';
import { copyToClipboard } from '@/utils/domUtils';
import { useAppSelector } from '@/lib/hooks';
import rootSelector from '@/lib/selectors/root.selector';
import { useTranslation } from 'react-i18next';
import CopyToClipboard from '../../copyToClipboard/copyToClipboard';

interface InfoPanelProps {
    isExpanded: boolean,
    toggleExpanded: (panelType: PanelType) => void
}

const InfoPanel = ({ isExpanded, toggleExpanded }: InfoPanelProps) => {
    const { t } = useTranslation();
    const { id: knowledgebaseId } = useAppSelector(rootSelector.knowledgeBase);

    return (
        <div className={_Classes(styles.infoPanel, panelStyles.panel, { [panelStyles.expanded]: isExpanded })}>
            <PanelHeader title={t('genAI.info.title')} isLoading={false} panelType='info' toggleExpanded={toggleExpanded} />
            <div className={styles.infoItems}>
                <div className={styles.item}>
                    <DsTypography variant='Semibold_14'>{t('genAI.general.id')}</DsTypography>
                    <div className={styles.idCopy}>
                        <DsTypography variant='Regular_14'>{knowledgebaseId}</DsTypography>
                        <CopyToClipboard value={knowledgebaseId} />
                    </div>
                </div>
                <div className={styles.item}>
                    <DsTypography variant='Semibold_14'>{t('genAI.info.descriptionTitle')}</DsTypography>
                    <DsTypography variant='Regular_14'>{t('genAI.info.description')}</DsTypography>
                </div>
            </div>
        </div>
    )
}

export default InfoPanel