import React, { ReactNode, RefObject, SyntheticEvent, forwardRef, useState } from "react";
import './dsTextField.scss';
import { DsTypography } from "../dsTypography/dsTypography";
import { DsComponentProps, TypographyVariant } from "../dsTypes";
import { DsTooltipInfo, DsTooltipInfoProps } from "../dsTooltipInfo/dsTooltipInfo";
import { DsMessageContainer } from "../dsMessageContainer/dsMessageContainer";
import CloseIcon from "@/app/[locale]/svgs/close.svg";
import ShowIcon from "@/app/[locale]/svgs/show.svg";
import HideIcon from "@/app/[locale]/svgs/hide.svg";
import { DsFlashingDotsLoader } from "../dsFlashingDotsLoader/dsFlashingDotsLoader";
import styles from '../dsTypography/dsTypography.module.scss';
import { _Classes } from "@/utils/cssHelper.util";
import { DsPopover } from "../dsPopover/dsPopover";

export interface DsTextFieldFrameProps<variant extends 'Default' | string = 'Default'> extends DsComponentProps<variant> {
    isOptional?: boolean,
    tooltip?: Omit<DsTooltipInfoProps, 'title'>,
    onActionsHover: (isHover: boolean) => void,
    isReadOnly?: boolean,
    countLimiting?: number,
    children: ReactNode,
    value?: string | any[],
    resetValue: () => void,
    showChevron: boolean,
    isCleanable?: boolean,
    isPassword?: boolean,
    onShowHidePassword?: (isShow: boolean) => void,
    onChvronClick: (event: SyntheticEvent) => void
};

export const _className = (typographyVariant: TypographyVariant) => _Classes(
    styles.base,
    styles[typographyVariant]
);

const DsTextFieldFrame = forwardRef<HTMLDivElement, DsTextFieldFrameProps>(({
    className = '',
    message,
    isDisabled,
    disabledReason,
    isLoading,
    isOptional,
    isReadOnly,
    isCleanable = true,
    isPassword,
    tooltip,
    resetValue,
    onActionsHover,
    onShowHidePassword = () => { },
    onChvronClick,
    value,
    style = {},
    title,
    children,
    countLimiting = 0,
    variant = 'Default',
    showChevron
}: DsTextFieldFrameProps, ref) => {
    const [showPasswordText, setShowPasswordText] = useState<boolean>(false);

    const clickChevron = (event: SyntheticEvent) => {
        (ref as RefObject<HTMLDivElement>).current?.click();
        onChvronClick(event);
    }

    const handleShowHidePassword = (isShow: boolean) => {
        setShowPasswordText(isShow);
        onShowHidePassword(isShow);
    }

    return (
        <DsPopover className={`dsTextFramePopover ${className}`} placement='bottomRight' trigger={!isDisabled || !disabledReason ? 'triggerDisabled' : "hover"} title={disabledReason}>
            <div className={`dsTextFieldFrame ${variant} ${isDisabled ? 'isDisabled' : ''} ${isLoading ? 'isLoading' : ''} ${isReadOnly ? 'isReadOnly' : ''} ${message?.type === 'error' ? 'isError' : ''}`}
                style={style}>
                <div className="textFieldHeader">
                    <DsTypography variant="Regular_14" className="textFieldTitle">{title}</DsTypography>
                    <DsTypography variant="Regular_14" className="textFieldInfo">
                        {isOptional && 'Optional'}
                        {tooltip && <DsTooltipInfo trigger="hover" {...tooltip} className={`textFieldTooltip ${tooltip.className || ''}`} />}
                    </DsTypography>
                </div>
                <div ref={ref} tabIndex={1} className="inputTextContainer" onMouseLeave={() => onActionsHover(false)}>
                    <div className="inputContainer">
                        {children}
                        <div className="actionsContainer" onMouseOver={() => onActionsHover(true)}>
                            {!isLoading && <>
                                {(value && (typeof value === 'string' || (Array.isArray(value) && value.length > 0))) && !isDisabled && !isReadOnly && !isLoading && isCleanable && !isPassword && <CloseIcon className='closeIcon' onClick={() => resetValue()} />}
                                {isPassword && <>
                                    {!showPasswordText && <ShowIcon className='showHidePassword' width={24} onClick={() => handleShowHidePassword(true)} />}
                                    {showPasswordText && <HideIcon className='showHidePassword' width={24} onClick={() => handleShowHidePassword(false)} />}
                                </>}
                                {showChevron && <svg
                                    width="9"
                                    height="5"
                                    viewBox="0 0 9 5"
                                    fill="none"
                                    xmlns="http://www.w3.org/2000/svg"
                                    className='chevronIcon'
                                    onClick={event => clickChevron(event)}
                                >
                                    <path
                                        d="M4.5 5L0.602887 0.499999L8.39711 0.5L4.5 5Z"
                                        fill="var(--selector-on-bg)"
                                    />
                                </svg>}
                            </>}
                            {isLoading && <DsFlashingDotsLoader />}
                        </div>
                    </div>
                    <div className="extraInfoContainer">
                        <div className="container messageContainer">
                            {message && <DsMessageContainer message={message} />}
                        </div>
                        <div className="container">
                            {countLimiting > 0 && <DsTypography variant="Regular_13">{`${value?.length || 0}/${countLimiting}`}</DsTypography>}
                        </div>
                    </div>
                </div>
            </div>
        </DsPopover>
    )
})

DsTextFieldFrame.displayName = 'DsTextFieldFrame';

export default DsTextFieldFrame;