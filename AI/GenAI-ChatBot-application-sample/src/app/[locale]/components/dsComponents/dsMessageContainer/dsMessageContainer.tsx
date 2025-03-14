import React from "react";
import './dsMessageContainer.scss';
import { DsTypography } from "../dsTypography/dsTypography";
import ErrorIcon from "@/app/[locale]/svgs/error.svg";
import WarningIcon from "@/app/[locale]/svgs/warning.svg";
import InfoIcon from "@/app/[locale]/svgs/info.svg";
import { Message } from "../dsTypes";
import { DsTooltipInfo } from "../dsTooltipInfo/dsTooltipInfo";
import { useTranslation } from "react-i18next";

export interface DsMessageContainerProps {
    message: Message,
    className?: string,
    hideValue?: boolean
};

export const DsMessageContainer = ({ message, className = '', hideValue }: DsMessageContainerProps) => {
    const { t } = useTranslation();

    return (
        <div className={`dsMessageContainer ${className}`}>
            {message.type === 'error' && <ErrorIcon className='messageIcon errorIcon' width={16} height={16} />}
            {message.type === 'warning' && <WarningIcon className='messageIcon warningIcon' />}
            {message.type === 'info' && <InfoIcon className='messageIcon infoIcon' />}
            <DsTypography variant="Semibold_13" className="messageType">{`${t(`genAI.messages.errors.${message.type}`)}${!hideValue ? ':' : ''}`}</DsTypography>
            {!hideValue && <DsTypography variant="Regular_13" className="messageValue">{message.value}</DsTypography>}
            {message.tooltipValue && <DsTooltipInfo trigger="hover">{message.tooltipValue}</DsTooltipInfo>}
        </div>
    )
}