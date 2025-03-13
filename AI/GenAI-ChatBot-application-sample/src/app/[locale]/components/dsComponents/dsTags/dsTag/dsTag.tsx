import React, { forwardRef } from "react";
import './dsTag.scss';
import { DsComponentProps } from "../../dsTypes";
import { DsTypography } from "../../dsTypography/dsTypography";

type LabelVariants = 'new' | 'comingSoon' | 'privatePreview' | 'preview' | 'Deprecated' | 'best';

export interface DsBaseTag<tagVariant extends 'Default' | string = 'Default'> extends Omit<DsComponentProps<tagVariant>, 'isLoading' | 'error'> { }
export interface DsTagProps extends Omit<DsBaseTag<LabelVariants>, 'isDisabled'> {
    title: string,
}

export const DsTag = forwardRef<HTMLDivElement, DsTagProps>(({ title,
    typographyVariant = 'Regular_14',
    variant = 'Default',
    className = '',
    style }: DsTagProps, ref) => {
    return (
        <div className={`dsTag ${className} ${variant}`} ref={ref} style={style}>
            <DsTypography variant={typographyVariant} className="labelText">{title}</DsTypography>
        </div>
    )
})

DsTag.displayName = 'DsTag';