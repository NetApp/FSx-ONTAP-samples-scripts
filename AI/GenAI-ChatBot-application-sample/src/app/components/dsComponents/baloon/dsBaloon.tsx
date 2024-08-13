import React, { forwardRef } from "react";
import './dsBaloon.scss';
import { DsBaseComponentProps, WithChildren } from "../dsTypes";
import { DsTypography } from "../dsTypography/dsTypography";

export interface DsBaloonProps extends DsBaseComponentProps, WithChildren {
    maxWidth?: string
}

export const DsBaloon = forwardRef<HTMLDivElement, DsBaloonProps>(({ children, className = '', style = {}, maxWidth, typographyVariant = 'Regular_13' }: DsBaloonProps, ref) => {
    return (
        <div className={`dsBaloonPopup ${className}`} ref={ref} style={{ ...style, maxWidth }}>
            <DsTypography className="childrenContainer" variant={typographyVariant}>{children}</DsTypography>
        </div>
    )
})

DsBaloon.displayName = 'DsBaloon';