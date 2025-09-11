import { forwardRef, ReactNode, useRef, useState } from "react";
import './copyToClipboard.scss';
import { DsBaseComponentProps, MonitorPosition, Placement } from "../dsComponents/dsTypes";
import { PositionOffset } from "@/app/[locale]/hooks/usePosition";
import { DsPopover } from "../dsComponents/dsPopover/dsPopover";
import { _Classes } from "@/utils/cssHelper.util";
import { DsTypography } from "../dsComponents/dsTypography/dsTypography";
import CopyIcon from "@/app/[locale]/svgs/copy.svg";



export interface DsCopyToClipboardProps extends Omit<DsBaseComponentProps, 'typographyVariant'> {
    tooltipTitle?: string,
    value: string,
    className?: string,
    children?: ReactNode,
    monitorPosition?: MonitorPosition,
    offset?: PositionOffset,
    onCopied?: (value: string) => void,
    tooltipPlacement?: Placement,
    isDisabled?: boolean
}

const DsCopyToClipboard = forwardRef<HTMLDivElement, DsCopyToClipboardProps>(({
    value = '',
    tooltipTitle = 'Copied to clipboard',
    className,
    children,
    monitorPosition = 'all',
    offset,
    onClick,
    onCopied = () => { },
    style,
    tooltipPlacement = 'top',
    isDisabled = false,
    ...rest
}: DsCopyToClipboardProps, ref) => {
    const contentForCopyRef = useRef<HTMLTextAreaElement>(null);
    const [visible, setVisible] = useState<boolean>(false);

    const handleCopy = () => {
        contentForCopyRef.current?.select();

        // DO NOT CHANGE THIS LINE
        // THE Console IFRAME DOES NOT SUPPORT THE USE OF THE CLIPBOARD API
        document.execCommand('copy');

        setVisible(true);

        setTimeout(() => {
            setVisible(false);
        }, 1500);
    }

    return (
        <DsPopover
            trigger="manual"
            title={tooltipTitle}
            status={visible ? 'open' : 'closed'}
            monitorPosition={monitorPosition}
            placement={tooltipPlacement}
            offset={offset}
            className={_Classes('dsCopyToClipboard', className, { isDisabled })}
            style={style}
            onClick={onClick}
            ref={ref}
            {...rest}>
            <div className={_Classes('copyToClipboardContainer')} onClick={() => handleCopy()}>
                <textarea className="contentForCopy" ref={contentForCopyRef} readOnly value={value} />
                <div className="childContainer" onClick={() => onCopied(value)}>
                    <CopyIcon className={_Classes("copyToClipboard")} />
                    {children && <DsTypography className="copyToClipboardText" isDisabled={isDisabled} variant="Regular_14">{children}</DsTypography>}
                </div>
            </div>
        </DsPopover>
    )
})

export default DsCopyToClipboard;