import React, { SyntheticEvent, forwardRef } from "react";
import './dsCard.scss';
import { DsBaseComponentProps, WithChildren } from "../dsTypes";

export interface DsCardProps extends DsBaseComponentProps, WithChildren {
    onClick?: (event: SyntheticEvent) => void
}

export const DsCard = forwardRef<HTMLDivElement, DsCardProps>(({ children, className = '', onClick = () => { }, style }: DsCardProps, ref) => {
    return (
        <div className={`dsCard ${className}`} onClick={event => onClick(event)} ref={ref} style={style}>{children}</div>
    )
})

DsCard.displayName = 'DsCard';