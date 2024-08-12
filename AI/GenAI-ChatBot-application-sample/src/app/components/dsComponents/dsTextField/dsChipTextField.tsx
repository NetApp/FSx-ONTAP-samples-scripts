import React, { KeyboardEvent, RefObject, forwardRef, useEffect, useRef, useState } from "react";
import './dsChipTextField.scss';
import { DsComponentProps } from "../dsTypes";
import { DsTooltipInfoProps } from "../dsTooltipInfo/dsTooltipInfo";
import DsTextFieldFrame, { _className } from "./dsTextFieldFrame";
import { DsChip, DsChipProps } from "../dsTags/chip/dsChip";

export interface Chip {
    id: string,
    label: string,
    isHidden?: boolean
}

interface ChipWithOptions extends Chip {
    options: ChipWithOptions[]
}

export interface DsChipTextFieldProps<variant extends 'Default' | string = 'Default'> extends Omit<DsComponentProps<variant>, 'typographyVariant'> {
    isOptional?: boolean,
    tooltip?: Omit<DsTooltipInfoProps, 'title'>,
    chips?: Chip[],
    onChange?: (chips: Chip[]) => void,
    placeholder?: string,
    isReadOnly?: boolean,
    /** If set to false and no remaining space, the last chip will show a dropdown list of chips */
    isWrapText?: boolean,
    isCleanable?: boolean
};

export const DsChipTextField = forwardRef<HTMLInputElement, DsChipTextFieldProps>(({
    className = '',
    message,
    isDisabled = false,
    disabledReason,
    isLoading,
    isOptional,
    isReadOnly,
    tooltip,
    onClick = () => { },
    onChange = () => { },
    style = {},
    title,
    chips = [],
    placeholder,
    variant = 'Default',
    isWrapText = true,
    isCleanable = true
}: DsChipTextFieldProps, ref) => {
    interface ChipWidthMap { [key: number | string]: number };

    const innerTextFieldInputRef = useRef<HTMLDivElement>(null);
    const chipsContainerRef = useRef<HTMLDivElement>(null);
    const [textValue, setTextValue] = useState<string>('');
    const [selectedChips, setSelectedChips] = useState<ChipWithOptions[]>([]);
    const [defaultChips, setDefaultChips] = useState<Chip[]>([]);
    const [isInputSelect, setIsInputSelect] = useState<boolean>(false);
    const [isHoverActions, setIsHoverActions] = useState<boolean>(false);
    const [isInputFocus, setIsInputFocus] = useState<boolean>(false);
    const [chipWidthMap, setChipWidthMap] = useState<ChipWidthMap>({});

    const generateId = () => Date.now().toString();

    useEffect(() => {
        setDefaultChips(currentChips => {
            return currentChips.length !== chips.length ? chips.map(chip => {
                return {
                    ...chip,
                    //Default select chips visibility to true
                    isVisible: true// chip.isVisible === false ? false : true
                }
            }) : currentChips;
        });
    }, [chips])

    useEffect(() => {
        setTimeout(() => {
            const chipList = Array.isArray(defaultChips) ? defaultChips.map<ChipWithOptions>(({ id, label: value, isHidden }) => {
                return {
                    id,
                    label: value,
                    options: [],
                    isHidden
                }
            }) : [];

            setSelectedChips(chipList);
        }, 0);
    }, [defaultChips])

    useEffect(() => {
        setTimeout(() => {
            const thisRef = ref as RefObject<HTMLInputElement>;
            setIsInputSelect(thisRef?.current?.getAttribute('isInputSelect') === 'true');
        }, 0);
    });

    const flatChipListWidthOptions = (chips: ChipWithOptions[]): ChipWithOptions[] => {
        const chipList: ChipWithOptions[] = [];
        chips.forEach(chip => {
            const { options } = chip;
            if (options.length > 0) {
                chipList.push(...options);
            } else {
                chipList.push(chip)
            }
        })

        return chipList;
    }

    const availableWidthForChip = (chipsMap: ChipWidthMap): number => {
        const container = chipsContainerRef.current;
        if (!isWrapText && container) {
            const chipsContainerWidth = container.clientWidth;
            const contaierStyle = window.getComputedStyle(container, null);
            const paddingLeft = Number(contaierStyle.paddingLeft.replace('px', ''));
            const paddingRight = Number(contaierStyle.paddingRight.replace('px', ''));
            const totalInnerWidth = chipsContainerWidth - paddingLeft - paddingRight;

            const widthValues = Object.values(chipsMap);

            if (widthValues.length > 0) {
                const totalChipsWidth = widthValues.reduce((a, b) => a + b);
                return totalInnerWidth - totalChipsWidth;
            }
        }

        return 999999;
    };

    const handleKeyboardEvent = (event: KeyboardEvent<HTMLDivElement>) => {
        if (event.key === 'Enter') {
            if (textValue) {
                const chipList: ChipWithOptions[] = [...selectedChips, {
                    id: generateId(),
                    label: textValue,
                    options: [],
                    isHidden: false
                }];

                setTextValue('');
                setTimeout(() => {
                    const flatList = flatChipListWidthOptions(chipList);
                    setSelectedChips(flatList);
                    onChange(flatList);
                }, 0);
            }

            setTimeout(() => {
                innerTextFieldInputRef.current!.textContent = ''
            }, 0);
        }
        else {
            setTimeout(() => {
                const value = innerTextFieldInputRef.current?.textContent;
                setTextValue(value || '');

                if (event.key === 'Backspace' && !textValue) {
                    const chipToRemove = selectedChips[selectedChips.length - 1];
                    if (chipToRemove?.options.length === 0) {
                        removeChip(selectedChips[selectedChips.length - 1].id)
                    }
                }
            }, 100);
        }
    }

    const removeChip = (id: string | number, parentId?: string | number) => {
        let chipList: ChipWithOptions[] = [];

        if (!parentId) {
            chipList = selectedChips.filter(chip => chip.id !== id);
        } else {
            const parent = selectedChips.find(chip => chip.id === parentId);
            chipList = selectedChips.filter(chip => chip.id !== parentId);
            parent!.options = parent!.options.filter(chip => chip.id !== id);
            chipList = parent!.options.length > 0 ? [...chipList!, parent!] : [...chipList!];
        }

        const flatList = flatChipListWidthOptions(chipList);
        //Force chips to re-render. The list will be regenerated from scrach (in chipAdded function) on each chip removal.
        setSelectedChips([]);

        setTimeout(() => {
            setSelectedChips(flatList);
            onChange(flatList);

            setChipWidthMap({});
        }, 0);
    }

    const chipAdded = (id: number | string, width: number) => {
        if (width && chipWidthMap[id] !== width) {
            chipWidthMap[id] = width;
            const visibleChipsId = Object.keys(chipWidthMap);

            //remove keys of old drop chips
            const oldDropChipId = visibleChipsId.filter(chipId => !selectedChips.map(chip => chip.id).includes(chipId));
            oldDropChipId.forEach(id => delete chipWidthMap[id]);

            const availableWidth = availableWidthForChip(chipWidthMap);
            if (availableWidth < 5) {
                const dropChip = selectedChips.find(chip => !chip.label);
                const visibleChips = selectedChips.filter(chip => visibleChipsId.includes(chip.id));
                let chipList: ChipWithOptions[] = [];

                if (!dropChip) {
                    /** The seletion from selectedChips is to maintain the order of the chips */
                    const lastChipId = visibleChips[visibleChips.length - 1].id;
                    const newDropChips = selectedChips.filter(chip => ![...visibleChipsId].includes(chip.id) || [id, lastChipId].includes(chip.id));
                    chipList = selectedChips.filter(chip => ![...newDropChips].includes(chip));
                    const newChip: ChipWithOptions = {
                        id: generateId(),
                        label: '',
                        options: newDropChips,
                        isHidden: false
                    }

                    chipList = [...chipList, newChip];
                    delete chipWidthMap[id];
                } else {
                    /** The seletion from selectedChips is to maintain the order of the chips */
                    const lastChip = visibleChips[visibleChips.length - 2];
                    dropChip.options = [lastChip, ...dropChip.options];
                    chipList = selectedChips.filter(chip => chip.id !== lastChip.id);
                    delete chipWidthMap[lastChip.id];
                }

                setSelectedChips([...chipList]);
            }

            setChipWidthMap({ ...chipWidthMap });
        }
    }

    return (
        <DsTextFieldFrame
            ref={ref}
            className={`dsChipTextField ${className}`}
            message={message}
            isDisabled={isDisabled}
            disabledReason={disabledReason}
            isLoading={isLoading}
            isOptional={isOptional}
            isReadOnly={isReadOnly}
            style={style}
            title={title}
            tooltip={tooltip}
            value={selectedChips}
            variant={variant}
            onActionsHover={setIsHoverActions}
            resetValue={() => {
                setSelectedChips([]);
                onChange([]);
                innerTextFieldInputRef.current?.focus();
            }}
            showChevron={isInputSelect}
            isCleanable={isCleanable}
            onChvronClick={onClick}>
            <div ref={chipsContainerRef} className={`textFieldInput ${isInputSelect ? 'isInputSelect' : ''} ${isHoverActions ? 'isHoverActions' : ''} ${isInputFocus ? 'isInputFocus' : ''} ${isWrapText ? '' : 'noWrap'} ${isCleanable ? 'isCleanable' : ''}`}>
                {selectedChips.filter(chip => !chip.isHidden).map(({ id, label: value, options }) => {
                    const dropItems = options.filter(option => !option.isHidden).map<DsChipProps>(option => {
                        const { id, label: value } = option;

                        return {
                            id: id,
                            title: value
                        }
                    })

                    return <DsChip
                        id={id} key={id} title={value}
                        isDisabled={isDisabled || isLoading || isReadOnly}
                        onRemove={(event, id, parentId) => removeChip(id, parentId)}
                        onCreated={({ id, width }) => chipAdded(id, width)}
                        onClick={onClick}
                        dropdown={{
                            options: dropItems,
                            trigger: 'hover'
                        }} />
                })}
                <div contentEditable={!isInputSelect && !isDisabled}
                    ref={innerTextFieldInputRef}
                    //@ts-ignore
                    placeholder={selectedChips.length === 0 ? placeholder : undefined}
                    onKeyDown={(event => handleKeyboardEvent(event))}
                    onClick={event => onClick(event)}
                    onFocus={() => setIsInputFocus(true)}
                    onBlur={() => setIsInputFocus(false)}
                    className={`innerTextFieldInput ${_className("Regular_14")}`} />
            </div>
        </DsTextFieldFrame>
    )
})

DsChipTextField.displayName = 'DsChipTextField'