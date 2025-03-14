import React, { forwardRef, ReactElement } from "react";
import './dsBadge.scss';
import { DsTypography } from "../../dsTypography/dsTypography";
import { DsBaseTag } from "../dsTag/dsTag";

type BadgeVariants = 'number' | 'dot';
export interface DsBadgeProps extends Omit<DsBaseTag<BadgeVariants>, 'isDisabled'> {
    title: number,
    icon?: ReactElement,
    type: 'error' | 'warning' | 'info' | 'success' | 'pending' | 'disabled'
}

export const DsBadge = forwardRef<HTMLDivElement, DsBadgeProps>(({
    title,
    typographyVariant = 'Semibold_14',
    variant = 'Default',
    style,
    icon,
    type
}: DsBadgeProps, ref) => {
    return (
        <div className={`dsBadge ${variant} ${type} ${icon ? 'iconDotColor' : undefined}`} ref={ref} style={style}>
            {icon && <div className="iconContainer">
                {icon}
            </div>}
            {variant === 'dot' && <div className="dot"></div>}
            {(variant === 'Default' || variant === 'number') && <DsTypography variant={typographyVariant} className="labelText">{title}</DsTypography>}
        </div>
    )
})

DsBadge.displayName = 'DsBadge';