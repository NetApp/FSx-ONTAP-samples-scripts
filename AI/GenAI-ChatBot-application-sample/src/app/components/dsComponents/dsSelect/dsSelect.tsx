import React, { ChangeEvent, SyntheticEvent, forwardRef, useCallback, useEffect, useMemo, useRef, useState } from "react";
import './dsSelect.scss';
import { DsTextField, DsTextFieldProps } from "../dsTextField/dsTextField";
import { DropDownCustomeItem, DsExpandableComponent, SelectionType } from "../dsTypes";
import { DsDropDownList, DsDropDownListItemProps, DsDropDownListProps, DsDropDownSearch } from "../dsDropDownList/dsDropDownList";
import { DsTypography } from "../dsTypography/dsTypography";
import { DsTooltipInfo } from "../dsTooltipInfo/dsTooltipInfo";
import { DsCheckbox } from "../dsCheckbox/dsCheckbox";
import { Chip, DsChipTextField } from "../dsTextField/dsChipTextField";
import { DsButtonProps } from "../dsButton/dsButton";

export type DsSelectVariant = 'underline';

interface SelectChip extends Chip {
    isSelected: boolean
}

export interface DsSelectItemProps extends DsDropDownListItemProps {
    /** The value that will be shown when item is selected */
    value: string
}

export interface DsSelectProps extends Omit<DsTextFieldProps<DsSelectVariant>, 'countLimiting' | 'value' | 'onChange'>, DsExpandableComponent, DropDownCustomeItem<DsDropDownListItemProps> {
    options: DsSelectItemProps[],
    selectedOptionIds?: (number | string)[],
    onInputChange?: (event?: ChangeEvent<HTMLInputElement>) => void,
    onSelect?: (option: DsSelectItemProps[]) => void,
    selectionType?: SelectionType,
    formatLabel?: 'chip' | 'count',
    isWithActions?: boolean,
    searchMethod?: DsDropDownSearch,
    isCleanable?: boolean,
    isSelectAll?: boolean
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
    isSelectAll = false
}: DsSelectProps, ref) => {
    const SELECT_ALL = 'selectAll';
    const SELECT_ALL_CHIP: DsSelectItemProps = useMemo(() => {
        return {
            id: SELECT_ALL,
            label: 'Select all',
            value: SELECT_ALL
        }
    }, []);

    const inputRef = useRef<HTMLInputElement>(null);

    const [selectOptions, setSelectOptions] = useState<DsSelectItemProps[]>([])
    const [expanded, setExpanded] = useState<boolean>(!!isExpanded);
    const [inputText, setInputText] = useState<string | SelectChip[] | undefined>();
    const [savedInputValueText, setSavedInputValueText] = useState<string | SelectChip[] | undefined>();
    const [selectedOptIds, setSelectedOptIds] = useState<(number | string)[]>([]);

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
    }, []);

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
        event && option?.onClick && option?.onClick(event);
    }, [onSelect])

    const handleCheckSelectItem = (event: ChangeEvent<HTMLInputElement>, id: string, option: DsSelectItemProps) => {
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
        option.onClick && option.onClick(event);
    };

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
            switch (formatLabel) {
                case 'count': {
                    const itemCount = selectionType === 'single' && inputText ? 1 : (inputText?.length || 0);

                    return `${itemCount} selected`;
                }
                default: {
                    return inputText as string;
                }
            }
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

    const dropdownlist = (): DsDropDownListProps => {
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
                        className={`selectItem singleItem ${className} ${isSingleItemSelected(id)}`}
                        variant={typographyVariant}
                        onClick={event => {
                            handleSingleSelectItem(option, event)
                        }}
                        isDisabled={isDisabled}
                        style={style}>
                        {customeLabel()}
                    </DsTypography>
                )
            } else {
                const isSelected = (id: string) => {
                    const chipList = (inputText || []) as SelectChip[]
                    if (id === SELECT_ALL) {
                        return chipList.length === selectOptions.length;
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
                children: 'Apply',
                onClick: () => {
                    setExpanded(false);
                    const selectedOptions = chipsToOptions(inputText as SelectChip[]);
                    setSelectedOptIds(selectedOptions.map(opt => opt.id));
                    onSelect(selectedOptions.filter(option => option.id !== SELECT_ALL));
                }
            },
            {
                children: 'Cancel',
                onClick: () => {
                    setExpanded(false);
                    setInputText(savedInputValueText);
                }
            }
        ]


        return {
            boundariesRef: inputRef,
            onExpandChange: isExpanded => {
                setExpanded(isExpanded)
                onExpandChange(isExpanded);
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
            isExpanded: expanded,
            actions: isWithActions && selectionType === 'multi' ? dropActions : undefined,
            isCloseOnClickOutside: !isWithActions,
            searchMethod: options.length > 0 ? searchMethod : undefined,
            formatOptionLabel: ({ id }) => {
                const customeOption = selectOptions.find(option => option.id === id);
                return customeOption ? <OptionItem option={customeOption!} /> : <></>
            }
        }
    }

    return (
        <div className={`dsSelect ${className} ${expanded ? 'isExpanded' : ''} ${isDisabled ? 'isDisabled' : ''} ${isLoading ? 'isLoading' : ''} ${isOptional ? 'isOptional' : ''} ${isReadOnly ? 'isReadOnly' : ''} ${variant} ${selectionType}`}
            ref={ref}>
            {tooltip && variant === 'underline' && <DsTooltipInfo {...tooltip} title={undefined} trigger="hover" className="underlineTooltip" />}
            {textFieldInput}
            <DsDropDownList {...dropdownlist()} style={{ width: inputRef.current?.clientWidth }} />
        </div>
    )
})

DsSelect.displayName = 'DsSelect';