import { ChangeEvent, ReactElement, SyntheticEvent, forwardRef, useCallback, useEffect, useMemo, useRef, useState } from "react";
import './dsSelect.scss';
import { DsTextField, DsTextFieldProps } from "../dsTextField/dsTextField";
import { DropDownCustomeItem, DsExpandableComponent, SelectionType } from "../dsTypes";
import { DsDropDownList, DsDropDownListItemProps, DsDropDownListProps, DsDropDownSearch } from "../dsDropDownList/dsDropDownList";
import { DsTypography } from "../dsTypography/dsTypography";
import { DsTooltipInfo } from "../dsTooltipInfo/dsTooltipInfo";
import { DsCheckbox } from "../dsCheckbox/dsCheckbox";
import { Chip, DsChipTextField } from "../dsTextField/dsChipTextField";
import { DsButtonProps } from "../dsButton/dsButton";
import { _Classes } from "@/utils/cssHelper.util";

export type DsSelectVariant = 'underline';

interface SelectChip extends Chip {
    isSelected: boolean
}

export interface DsSelectItemProps extends DsDropDownListItemProps {
    /** The value that will be shown when item is selected */
    value: string
}

interface SelectActionProps extends Omit<DsButtonProps, 'onClick'> {
    onClick?: (event: SyntheticEvent, selectedIds?: (string | number)[]) => void
}
type SelectActions = [SelectActionProps] | [SelectActionProps, SelectActionProps];

export interface DsSelectProps extends Omit<DsTextFieldProps, 'countLimiting' | 'value' | 'onChange'>, DsExpandableComponent, DropDownCustomeItem<DsDropDownListItemProps> {
    options: DsSelectItemProps[],
    selectedOptionIds?: (number | string)[],
    onInputChange?: (event?: ChangeEvent<HTMLInputElement>) => void,
    onSelect?: (option: DsSelectItemProps[]) => void,
    selectionType?: SelectionType,
    /** The formatLabel is a type that can get 'chip' or 'count' or a function (value: string[] | undefined) => string | undefined */
    formatLabel?: 'chip' | 'count' | ((value: string[] | undefined) => string | undefined) | ReactElement,
    isWithActions?: boolean,
    searchMethod?: DsDropDownSearch,
    isCleanable?: boolean,
    isSelectAll?: boolean,
    dropDown?: {
        placement?: 'alignRight' | 'center' | 'alignLeft',
        autoPosition?: boolean,
        offsetXpixels?: number,
        widthPixels?: number,
        maxHeight?: string,
        isCloseOnClickOutside?: boolean,
        actions?: SelectActions
    }
};

export const DsSelect = forwardRef<HTMLDivElement, DsSelectProps>(({
    className = '',
    isDisabled,
    disabledReason,
    isLoading,
    isOptional,
    isReadOnly,
    isExpanded,
    message,
    onInputChange = () => { },
    onClick = () => { },
    onExpandChange = () => { },
    onSelect = () => { },
    formatOptionLabel,
    variant = 'Default',
    placeholder,
    style = {},
    title,
    tooltip,
    typographyVariant = 'Regular_14',
    options = [],
    selectedOptionIds,
    selectionType = 'single',
    formatLabel = 'chip',
    isWithActions = false,
    /** basic - search by exact search key, smart - search by similar search key */
    searchMethod,
    isCleanable = true,
    isSelectAll = false,
    dropDown,
    ...rest
}: DsSelectProps, ref) => {
    const SELECT_ALL = 'selectAll';
    const SELECT_ALL_CHIP: DsSelectItemProps = useMemo(() => {
        return {
            id: SELECT_ALL,
            label: 'Select all',
            value: SELECT_ALL,
            className: SELECT_ALL
        }
    }, []);
    const DEFAULT_DROPDOWN_WIDTH = 182;

    const inputRef = useRef<HTMLInputElement>(null);

    const [selectOptions, setSelectOptions] = useState<DsSelectItemProps[]>([])
    const [expanded, setExpanded] = useState<boolean>(!!isExpanded);
    const [inputText, setInputText] = useState<string | SelectChip[] | undefined>();
    const [savedInputValueText, setSavedInputValueText] = useState<string | SelectChip[] | undefined>();
    const [selectedOptIds, setSelectedOptIds] = useState<(number | string)[]>([]);
    const [offsetX, setOffsetX] = useState('0px');

    const optionsWithAll = useMemo<DsSelectItemProps[]>(() => {
        if (options.length === 0) {
            return [{
                id: 'noOptions',
                label: 'No options available',
                value: 'none',
                isDisabled: true
            }]
        }

        return selectionType === 'multi' && isSelectAll ? [SELECT_ALL_CHIP, ...options] : options;
    }, [SELECT_ALL_CHIP, isSelectAll, options, selectionType]);

    useEffect(() => {
        setExpanded(!!isExpanded);
    }, [isExpanded])

    useEffect(() => {
        setSelectOptions(ops => {
            return JSON.stringify(optionsWithAll) === JSON.stringify(ops) ? ops : optionsWithAll;
        })
    }, [optionsWithAll]);

    useEffect(() => {
        if (selectedOptionIds) {
            setSelectedOptIds(ids => {
                return JSON.stringify(ids) !== JSON.stringify(selectedOptionIds) ? selectedOptionIds : ids;
            });
        }
    }, [selectedOptionIds]);

    useEffect(() => {
        if (selectionType === 'single') {
            const selectedOption = selectOptions.find(option => selectedOptIds.map(id => id).includes(option.id));
            setInputText(selectedOption?.label);
        } else {
            const selectedOpts = selectOptions.filter(option => selectedOptIds.map(id => id).includes(option.id));

            const selectedChips = selectedOpts.map<SelectChip>(option => {
                const { id, label } = option;

                return {
                    id: id.toString(),
                    label,
                    isSelected: id !== SELECT_ALL ? true : selectedOpts.length === optionsWithAll.length,
                    isHidden: id === SELECT_ALL
                }
            });

            setInputText(selectedChips);
        }
    }, [selectOptions, selectionType, selectedOptIds, optionsWithAll.length])

    useEffect(() => {
        if (inputRef.current) {
            inputRef.current.setAttribute('isInputSelect', 'true');
        }
    }, [formatLabel]); //formatLabel needs to stay in the dependencies array to force the useEffect to run

    useEffect(() => {
        const placement = dropDown?.placement || 'right';
        const offsetXpixels = dropDown?.offsetXpixels || 0;
        const boundariesWidth = inputRef.current?.clientWidth || 0;
        const dropDownWidth = dropDown?.widthPixels || DEFAULT_DROPDOWN_WIDTH;

        switch (placement) {
            case 'center': {
                const offsetX = (boundariesWidth - dropDownWidth + offsetXpixels) / 2;
                setOffsetX(`${offsetX}px`);
                break;
            }
            case 'alignRight': {
                const offsetX = (boundariesWidth - dropDownWidth + offsetXpixels);
                setOffsetX(`${offsetX}px`);
                break;
            }
        }

    }, [dropDown?.placement, dropDown, formatLabel]);

    const chipsToOptions = useCallback((chips: Chip[]) => {
        return selectOptions.filter(option => chips.map(chip => chip.id).includes(option.id.toString()));
    }, [selectOptions])

    const changeEventWithActionButtons = useCallback((chips: Chip[]) => {
        if (!isWithActions || !expanded) {
            const selectedOptions = chipsToOptions(chips);
            setSelectedOptIds(selectedOptions.map(opt => opt.id));
            onSelect(selectedOptions.filter(option => option.id !== SELECT_ALL));
        }
    }, [isWithActions, expanded, onSelect, chipsToOptions])

    const handleSingleSelectItem = useCallback((option?: DsSelectItemProps, event?: SyntheticEvent) => {
        setSelectedOptIds(option ? [option.id] : [])
        onSelect(option ? [option] : []);
        setExpanded(false);
        setInputText(option?.label);
        if (event && option?.onClick) option?.onClick(event);
    }, [onSelect])

    const handleCheckSelectItem = useCallback((event: ChangeEvent<HTMLInputElement>, id: string, option: DsSelectItemProps) => {
        const { label } = option;
        let chips = (inputText as SelectChip[]) || [];
        if (event.target.checked === true) {
            if (id === SELECT_ALL) {
                chips = optionsWithAll.map<SelectChip>(chip => {
                    return {
                        id: chip.id.toString(),
                        isSelected: true,
                        label: chip.label,
                        isHidden: chip.id === SELECT_ALL
                    }
                })
            } else {
                const chipsWithoutSelectAll = chips.filter(chip => chip.id !== SELECT_ALL);
                chips = [{
                    id: SELECT_ALL,
                    isSelected: false,
                    label: SELECT_ALL_CHIP.label,
                    isHidden: true
                }, ...chipsWithoutSelectAll, {
                    id,
                    label: label,
                    isSelected: true,
                    isHidden: false
                }];
            }
        } else {
            chips = id === SELECT_ALL ? [] : chips.filter(chip => chip.id !== id);
        }

        setInputText(chips);
        changeEventWithActionButtons(chips);
        if (option.onClick) option.onClick(event);
    }, [SELECT_ALL_CHIP.label, changeEventWithActionButtons, inputText, optionsWithAll]);

    const textFieldInput = useMemo(() => {
        const handleOnChange = (event?: ChangeEvent<HTMLInputElement>) => {
            onInputChange(event);

            if (!event) {
                handleSingleSelectItem();
            }
        }

        const handleClick = (event: SyntheticEvent) => {
            onClick(event);

            if (!expanded) {
                setSavedInputValueText(inputText);
            }

            setExpanded(!expanded);
        }

        const handleOnChipChange = (chips: Chip[]) => {
            setInputText(chips.map<SelectChip>(chip => {
                return {
                    ...chip,
                    isSelected: true
                }
            }));

            changeEventWithActionButtons(chips);
        }

        const valueWithFormat = () => {
            if (typeof formatLabel === 'function') {
                if (Array.isArray(inputText)) {
                    return formatLabel(inputText.filter(item => item.id !== SELECT_ALL).map<string>(chip => chip.label))
                } else {
                    return formatLabel(inputText ? [inputText] : undefined)
                }
            };

            switch (formatLabel) {
                case 'count': {
                    const itemCount = selectionType === 'single' && inputText ? 1 : (inputText ? (inputText as SelectChip[]).filter(item => item.id !== SELECT_ALL).length : 0);

                    return `${itemCount} selected`;
                }
                default: {
                    return inputText as string;
                }
            }
        }

        if (typeof formatLabel === 'object') {
            return <div onClick={handleClick} ref={inputRef}>
                {formatLabel}
            </div>;
        }

        return (selectionType === 'single' || formatLabel !== 'chip') ? <DsTextField
            ref={inputRef}
            value={valueWithFormat()}
            isDisabled={isDisabled}
            disabledReason={disabledReason}
            isLoading={isLoading}
            isOptional={isOptional}
            isReadOnly={isReadOnly}
            message={message}
            onChange={handleOnChange}
            onClick={handleClick}
            placeholder={placeholder}
            title={title}
            tooltip={tooltip}
            typographyVariant={typographyVariant}
            style={style}
            isCleanable={isCleanable} /> :
            <DsChipTextField ref={inputRef}
                chips={((inputText || []) as Chip[])}
                isDisabled={isDisabled}
                disabledReason={disabledReason}
                isLoading={isLoading}
                isOptional={isOptional}
                isReadOnly={isReadOnly}
                message={message}
                onChange={handleOnChipChange}
                onClick={handleClick}
                placeholder={placeholder}
                title={title}
                tooltip={tooltip}
                isWrapText={false}
                style={style}
                isCleanable={isCleanable} />
    }, [inputText, isDisabled, isLoading, disabledReason, isCleanable, isOptional, isReadOnly, message, placeholder, title, tooltip, typographyVariant, expanded, selectionType, style, formatLabel, onClick, onInputChange, handleSingleSelectItem, changeEventWithActionButtons])

    const dropdownlist = useMemo((): DsDropDownListProps => {
        const OptionItem = ({ option }: { option: DsSelectItemProps }) => {
            const { id, label, className = '', isDisabled, style = {} } = option;

            const customeLabel = () => {
                return formatOptionLabel && options.length > 0 ? formatOptionLabel(option) : label;
            }

            if (selectionType === 'single' || options.length === 0) {
                const isSingleItemSelected = (id: string | number) => {
                    return selectedOptIds.includes(id) ? 'isSelected' : ''
                }

                return (
                    <DsTypography
                        key={id}
                        className={_Classes('selectItem', 'singleItem', className, isSingleItemSelected(id), { isDisabled })}
                        variant={typographyVariant}
                        onClick={event => {
                            handleSingleSelectItem(option, event)
                        }}
                        isDisabled={isDisabled}
                        style={style} >
                        {customeLabel()}
                    </DsTypography>
                )
            } else {
                const isSelected = (id: string) => {
                    const chipList = (inputText || []) as SelectChip[]
                    if (id === SELECT_ALL) {
                        return chipList.filter(chip => chip.id !== SELECT_ALL).length === selectOptions.filter(chip => chip.id !== SELECT_ALL).length;
                    }

                    return chipList.some(chip => chip.id === id.toString());
                }

                return <DsCheckbox key={id}
                    id={id.toString()}
                    title={customeLabel()}
                    onSelect={(id, event) => handleCheckSelectItem(event, id, option)}
                    isSelected={isSelected(id.toString())}
                    className={`selectItem ${className}`}
                    style={style}
                    isDisabled={isDisabled}
                />
            }
        }

        const dropActions: [DsButtonProps, DsButtonProps] = [
            {
                children: dropDown?.actions ? dropDown?.actions[0].children : 'Apply',
                onClick: (event) => {
                    setExpanded(false);
                    const selectedOptions = chipsToOptions(inputText as SelectChip[]);

                    if (dropDown?.actions && dropDown.actions[0].onClick) {
                        setInputText(savedInputValueText);
                        dropDown.actions[0].onClick(event, selectedOptions.map(opt => opt.id));
                    } else {
                        setSelectedOptIds(selectedOptions.map(opt => opt.id));
                        onSelect(selectedOptions.filter(option => option.id !== SELECT_ALL));
                    }
                }
            },
            {
                children: dropDown?.actions?.length === 2 ? dropDown?.actions[1].children : 'Cancel',
                onClick: (event) => {
                    setExpanded(false);
                    setInputText(savedInputValueText);

                    if (dropDown?.actions?.length === 2 && dropDown.actions[1].onClick) {
                        const selectedOptions = chipsToOptions(inputText as SelectChip[]);
                        dropDown.actions[1].onClick(event, selectedOptions.map(opt => opt.id));
                    }
                }
            }
        ]


        return {
            boundariesRef: inputRef,
            offsetX: offsetX,
            maxHeight: dropDown?.maxHeight,
            onExpandChange: isExpanded => {
                setExpanded(isExpanded)
                onExpandChange(isExpanded);
            },
            onClickOutside: () => {
                if (dropDown?.isCloseOnClickOutside && isWithActions && expanded) {
                    setExpanded(false);
                    setInputText(savedInputValueText);
                }
            },
            options: selectOptions.map<DsDropDownListItemProps>(option => {
                const { id, childItems, label, className, onClick, style, isDisabled, disabledReason } = option;

                return {
                    id,
                    label,
                    childItems,
                    searchByKey: option.label,
                    className,
                    onClick,
                    style,
                    typographyVariant,
                    isDisabled,
                    disabledReason
                }
            }),
            isExpanded: isExpanded !== undefined ? isExpanded : expanded,
            actions: isWithActions && selectionType === 'multi' ? (dropActions.slice(0, dropDown?.actions ? dropDown.actions.length : 2)) as SelectActions : undefined,
            isCloseOnClickOutside: dropDown?.isCloseOnClickOutside || !isWithActions,
            searchMethod: options.length > 0 ? searchMethod : undefined,
            formatOptionLabel: ({ id }) => {
                const customeOption = selectOptions.find(option => option.id === id);
                return customeOption ? <OptionItem option={customeOption!} /> : <></>
            },
            autoPosition: dropDown?.autoPosition === undefined ? true : dropDown?.autoPosition
        }
    }, [chipsToOptions, isExpanded, offsetX, expanded, formatOptionLabel, handleCheckSelectItem, handleSingleSelectItem, inputText, isWithActions, onExpandChange, onSelect, options.length, savedInputValueText, searchMethod, selectOptions, selectedOptIds, selectionType, typographyVariant, dropDown])

    return (
        <div className={`dsSelect ${className} ${expanded ? 'isExpanded' : ''} ${isDisabled ? 'isDisabled' : ''} ${isLoading ? 'isLoading' : ''} ${isOptional ? 'isOptional' : ''} ${isReadOnly ? 'isReadOnly' : ''} ${variant} ${selectionType}`}
            ref={ref} {...rest}>
            {tooltip && variant === 'underline' && <DsTooltipInfo {...tooltip} title={undefined} trigger="hover" className="underlineTooltip" />}
            {textFieldInput}
            <DsDropDownList {...dropdownlist} style={{ width: typeof formatLabel === 'object' ? `${dropDown?.widthPixels || DEFAULT_DROPDOWN_WIDTH}px` : inputRef.current?.clientWidth }} />
        </div>
    )
})

DsSelect.displayName = 'DsSelect';