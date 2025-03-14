import { DsFlashingDotsLoader } from '../../dsComponents/dsFlashingDotsLoader/dsFlashingDotsLoader';
import { DsTypography } from '../../dsComponents/dsTypography/dsTypography';
import { PanelType } from '../../chatbot/chatBotHeader/chatBotHeader';
import styles from './panelHeader.module.scss';
import CloseHistoryIcon from '@/app/[locale]/svgs/chatbot/rightChevron.svg';

interface PanelHeaderProps {
    title: string,
    isLoading: boolean,
    panelType: PanelType,
    toggleExpanded: (panelType: PanelType) => void
}

const PanelHeader = ({ title, isLoading, panelType, toggleExpanded }: PanelHeaderProps) => {
    return (
        <div className={styles.panelHeader}>
            <div className={styles.headerText}>
                <DsTypography variant='Semibold_16'>{title}</DsTypography>
                {(isLoading) && <DsFlashingDotsLoader />}
            </div>
            <div className={styles.historyAction}>
                <CloseHistoryIcon className={styles.close} width={20} onClick={() => toggleExpanded(panelType)} />
            </div>
        </div>
    )
}

export default PanelHeader;