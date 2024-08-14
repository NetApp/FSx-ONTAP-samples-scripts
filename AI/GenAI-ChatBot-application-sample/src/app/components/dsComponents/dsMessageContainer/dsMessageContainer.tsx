import React from "react";
import './dsMessageContainer.scss';
import { DsTypography } from "../dsTypography/dsTypography";
import ErrorIcon from "@/app/svgs/error.svg";
import WarningIcon from "@/app/svgs/warning.svg";
import InfoIcon from "@/app/svgs/info.svg";
import { Message } from "../dsTypes"; 
import { DsTooltipInfo } from "../dsTooltipInfo/dsTooltipInfo";

export interface DsMessageContainerProps {
    message: Message,
    className?: string,
    hideValue?: boolean
};

export const DsMessageContainer = ({ message, className = '', hideValue }: DsMessageContainerProps) => {
    return (
        <div className={`dsMessageContainer ${className}`}>
            {message.type === 'error' && <ErrorIcon className='messageIcon errorIcon' width={16} height={16}/>}
            {message.type === 'warning' && <WarningIcon className='messageIcon warningIcon' />}
            {message.type === 'info' && <InfoIcon className='messageIcon infoIcon' />}
            <DsTypography variant="Semibold_13" className="messageType">{`${message.type}${!hideValue ? ':' : ''}`}</DsTypography>
            {!hideValue && <DsTypography variant="Regular_13" className="messageValue">{message.value}</DsTypography>}
            {message.tooltipValue && <DsTooltipInfo trigger="hover">{message.tooltipValue}</DsTooltipInfo>}
        </div>
    )
}