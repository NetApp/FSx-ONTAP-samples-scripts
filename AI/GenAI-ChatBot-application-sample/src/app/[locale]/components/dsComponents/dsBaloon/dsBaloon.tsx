import { forwardRef, MouseEvent } from "react";
import './dsBaloon.scss';
import { DsBaseComponentProps, WithChildren } from "../dsTypes";
import { DsTypography } from "../dsTypography/dsTypography";
import { _Classes } from "@/utils/cssHelper.util";

export interface DsBaloonProps extends DsBaseComponentProps, WithChildren {
    maxWidth?: string,
    onMouseOver?: (event: MouseEvent) => void,
    onMouseLeave?: (event: MouseEvent) => void
}

export const DsBaloon = forwardRef<HTMLDivElement, DsBaloonProps>(({
    children,
    className = '',
    style = {},
    maxWidth,
    typographyVariant = 'Regular_13',
    onMouseOver,
    onMouseLeave,
    onClick
}: DsBaloonProps, ref) => {
    return (
        <div
            onClick={onClick}
            className={_Classes('dsBaloonPopup', className)}
            ref={ref}
            style={{ ...style, maxWidth }}
            onMouseOver={event => onMouseOver && onMouseOver(event)}
            onMouseLeave={event => onMouseLeave && onMouseLeave(event)}>
            <DsTypography className="childrenContainer" variant={typographyVariant}>{children}</DsTypography>
        </div>
    )
})

DsBaloon.displayName = 'DsBaloon';