import { ChangeEvent, forwardRef, useEffect, useRef, useState } from "react";
import './dsCheckbox.scss';
import { DropDownCustomeItem, DsComponentProps, DsSelectableComponent } from "../dsTypes";
import { DsTypography } from "../dsTypography/dsTypography";
import OkIcon from "@/app/[locale]/svgs/ok.svg";
import { DsDropDownList, DsDropDownListItemProps } from "../dsDropDownList/dsDropDownList";
import { DsMessageContainer } from "../dsMessageContainer/dsMessageContainer";
import { DsPopover } from "../dsPopover/dsPopover";

type CheckboxVariants = 'tableCheckbox' | 'tableHeaderCheckbox'

export interface TableHeaderDropDown extends DropDownCustomeItem<DsDropDownListItemProps> {
    placement?: 'alignRight' | 'center' | 'alignLeft',
    items: DsDropDownListItemProps[]
}

export interface DsCheckboxProps extends Omit<DsComponentProps<CheckboxVariants>, 'onClick' | 'id'>, DsSelectableComponent<HTMLInputElement> {
    /** indeterminate mode will activate the third state of the checkbox */
    indeterminate?: boolean,
    defaultChecked?: boolean,
    /** A dropdown list for the table header checkbox */
    dropDown?: TableHeaderDropDown,
    onCheckedChange?: (isChecked: boolean) => void
}

export const DsCheckbox = forwardRef<HTMLLabelElement, DsCheckboxProps>(({
    id,
    variant = 'Default',
    className = '',
    isDisabled,
    disabledReason,
    title,
    isSelected = false,
    onSelect = () => { },
    onCheckedChange = () => { },
    typographyVariant = 'Regular_14',
    style,
    indeterminate = false,
    defaultChecked = false,
    message,
    dropDown,
    ...rest
}: DsCheckboxProps, ref) => {
    const inputRef = useRef<HTMLInputElement>(null);
    const boundariesRef = useRef<HTMLInputElement>(null);
    const dropDownRef = useRef<HTMLDivElement>(null);

    const [isSelectedCheckbox, setIsSelectedCheckbox] = useState<boolean>(variant === 'tableHeaderCheckbox' ? false : isSelected);
    const [isExpanded, setIsExpanded] = useState<boolean>(false);
    const [offsetX, setOffsetX] = useState('0px');

    useEffect(() => {
        if (inputRef.current) {
            if (defaultChecked && indeterminate) {
                inputRef.current.indeterminate = true;
            }
        }
    }, [defaultChecked, indeterminate]);

    useEffect(() => {
        setIsSelectedCheckbox(isSelected || indeterminate);
    }, [isSelected, indeterminate]);

    useEffect(() => {
        const placement = dropDown?.placement || 'right';
        const boundariesWidth = boundariesRef.current?.clientWidth || 0;
        const dropDownWidth = dropDownRef.current?.clientWidth || 0;

        switch (placement) {
            case 'center': {
                const offsetX = (boundariesWidth - dropDownWidth) / 2;
                setOffsetX(`${offsetX}px`);
                break;
            }
            case 'alignRight': {
                const offsetX = (boundariesWidth - dropDownWidth);
                setOffsetX(`${offsetX}px`);
                break;
            }
        }

    }, [dropDown?.placement]);

    const handleChange = (event: ChangeEvent<HTMLInputElement>) => {
        onSelect(id, event);
        if (event.target.checked && indeterminate) {
            event.target.indeterminate = true;
        }

        onCheckedChange(event.target.checked);

        if (variant === 'tableHeaderCheckbox' && dropDown) {
            setIsExpanded(!isExpanded);
        }
    }

    return (
        <DsPopover trigger="hover" title={disabledReason} placement="bottom" {...rest}>
            <div className={`dsCheckBoxContainer ${isDisabled ? 'isDisabled' : ''}`}>
                <div className={`dsCheckboxBoundriesContainer ${isDisabled ? 'isDisabled' : ''}`} ref={boundariesRef}>
                    <label className={`dsCheckbox ${variant} ${className} ${isDisabled ? 'isDisabled' : ''} ${message?.type === 'error' ? 'error' : ''} ${indeterminate ? 'indeterminate' : ''}`}
                        ref={ref}
                        style={style}>
                        <input type="checkbox" checked={isSelectedCheckbox} onChange={(event) => handleChange(event)} ref={inputRef} />
                        <span className="checkmark">
                            {!indeterminate && <OkIcon className='checkedSign' />}
                            {indeterminate && <div className="checkedSign" />}
                        </span>
                        {variant === 'Default' && <DsTypography title={typeof title === 'string' ? title : undefined} isEllipsis variant={typographyVariant} className="radioLabel">{title}</DsTypography>}
                    </label>
                    {variant === 'tableHeaderCheckbox' && <svg
                        width="9"
                        height="5"
                        viewBox="0 0 9 5"
                        fill="none"
                        xmlns="http://www.w3.org/2000/svg"
                        className={`chevronIcon ${isExpanded ? 'isExpanded' : ''}`}
                    >
                        <path
                            d="M4.5 5L0.602887 0.499999L8.39711 0.5L4.5 5Z"
                            fill="var(--selector-on-bg)"
                        />
                    </svg>}
                </div>
                {message && !isExpanded && <DsMessageContainer message={message} className={`${variant !== 'Default' ? 'bigCheckbox' : ''}`} />}
                {variant === 'tableHeaderCheckbox' && dropDown && <DsDropDownList
                    ref={dropDownRef}
                    onExpandChange={setIsExpanded}
                    boundariesRef={boundariesRef}
                    isExpanded={isExpanded}
                    options={dropDown.items}
                    offsetX={offsetX}
                    formatOptionLabel={dropDown.formatOptionLabel}
                    monitorPosition="all"
                />}
            </div>
        </DsPopover>
    )
})

DsCheckbox.displayName = 'DsCheckbox';