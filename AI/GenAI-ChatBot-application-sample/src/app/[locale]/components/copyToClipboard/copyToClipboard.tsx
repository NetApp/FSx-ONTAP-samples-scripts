import { ReactNode, useRef, useState } from "react";
import './copyToClipboard.scss';
import { MonitorPosition } from "../dsComponents/dsTypes";
import { PositionOffset } from "@/app/[locale]/hooks/usePosition";
import { DsPopover } from "../dsComponents/dsPopover/dsPopover";
import { _Classes } from "@/utils/cssHelper.util";
import { DsTypography } from "../dsComponents/dsTypography/dsTypography";
import CopyIcon from "@/app/[locale]/svgs/copy.svg";
import { useTranslation } from "react-i18next";

interface CopyToClipboardProps {
    tooltipTitle?: string,
    value: string,
    className?: string,
    children?: ReactNode,
    monitorPosition?: MonitorPosition,
    offset?: PositionOffset
}

const CopyToClipboard = ({
    value = '',
    tooltipTitle = '',
    className,
    children,
    monitorPosition = 'all',
    offset }: CopyToClipboardProps) => {
    const { t } = useTranslation();

    const contentForCopyRef = useRef<HTMLInputElement>(null);
    const [visible, setVisible] = useState<boolean>(false);

    const handleCopy = () => {
        contentForCopyRef.current?.select();
        navigator.clipboard.writeText(value);

        setVisible(true);

        setTimeout(() => {
            setVisible(false);
        }, 1500);
    }

    return (
        <DsPopover
            trigger="manual"
            title={[tooltipTitle, t('genAI.general.copied')].filter(value => value).join(' ')}
            status={visible ? 'open' : 'closed'}
            monitorPosition={monitorPosition}
            placement="top"
            offset={offset}
            className="copyToClipboard">
            <div className={_Classes('copyToClipboardContainer', className)} onClick={() => handleCopy()}>
                <CopyIcon className={_Classes("copyToClipboard")} />
                {children && <DsTypography variant="Regular_14">{children}</DsTypography>}
            </div>
        </DsPopover>
    )
}

export default CopyToClipboard;