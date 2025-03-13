import { ChangeEvent, SyntheticEvent, forwardRef } from "react";
import './dsRadioButton.scss';
import { DsComponentProps, DsSelectableComponent } from "../dsComponents/dsTypes";
import OkIcon from "@/app/[locale]/svgs/ok.svg";
import { DsTypography } from "../dsComponents/dsTypography/dsTypography";
import { DsPopover } from "../dsComponents/dsPopover/dsPopover";

type RadioButtonVariant = 'tableRadio';

export interface DsRadioButtonProps extends Omit<DsComponentProps<RadioButtonVariant>, 'id'>, DsSelectableComponent<HTMLInputElement> {
    /** The group name of the radio button  */
    groupName?: string,
    onCheckedChange?: (isChecked: boolean) => void
}

export const DsRadioButton = forwardRef<HTMLLabelElement, DsRadioButtonProps>(({
    id,
    variant = 'Default',
    className = '',
    isDisabled,
    disabledReason,
    title,
    isSelected,
    onClick,
    onSelect = () => { },
    onCheckedChange = () => { },
    typographyVariant = 'Regular_14',
    style,
    groupName,
    ...rest
}: DsRadioButtonProps, ref) => {
    const handleClick = (event: SyntheticEvent) => {
        if (onClick) onClick(event);
    }

    const handleChange = (event: ChangeEvent<HTMLInputElement>) => {
        onSelect(id, event);
        onCheckedChange(event.target.checked);
    }

    return (
        <DsPopover trigger="hover" title={disabledReason} placement="bottom" {...rest}>
            <label className={`radioButton ${variant} ${className} ${isDisabled ? 'isDisabled' : ''}`} ref={ref} onClick={event => handleClick(event)} style={style}>
                <input type="radio" value={id} name={groupName} checked={isSelected} onChange={(event) => handleChange(event)} />
                <span className="checkmark">
                    {variant === 'Default' && <div className="point" />}
                    {variant === 'tableRadio' && <OkIcon className="okPoint" />}
                </span>
                <DsTypography title={typeof title === 'string' ? title : undefined} isEllipsis variant={typographyVariant} className="radioLabel">{title}</DsTypography>
            </label>
        </DsPopover>
    )
})

DsRadioButton.displayName = 'DsRadioButton'