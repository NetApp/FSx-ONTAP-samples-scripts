import React, { SyntheticEvent, forwardRef, useMemo, useRef, useState } from "react";
import './dsChip.scss';
import { DsTypography } from "../../dsTypography/dsTypography";
import CloseIcon from '@/app/[locale]/svgs/close.svg';
import { DsBaseTag } from "../dsTag/dsTag";
import { DsDropDownList, DsDropDownListItemProps } from "../../dsDropDownList/dsDropDownList";
import { TriggerType } from "../../dsTypes";
import useRunOnce from "@/app/[locale]/hooks/useRunOnce";

export interface DsChipProps extends DsBaseTag {
    id: string
    onRemove?: (event: SyntheticEvent, id: string | number, parentId?: string | number) => void,
    dropdown?: {
        trigger: TriggerType,
        options: DsChipProps[]
    },
    onCreated?: (args: { id: number | string, width: number }) => void,
    title: string
}

export const MIN_CHIP_WIDTH = 43;

export const DsChip = forwardRef<HTMLDivElement, DsChipProps>(({
    id,
    title,
    typographyVariant = 'Regular_14',
    variant = 'Default',
    style,
    className = '',
    onRemove = () => { },
    isDisabled,
    dropdown,
    onCreated = () => { },
    onClick = () => { }
}: DsChipProps, ref) => {
    const boundariesRef = useRef<HTMLDivElement>(null);
    const dropdownRef = useRef<HTMLDivElement>(null);

    const [isExpanded, setIsExpanded] = useState<boolean>(false);

    useRunOnce(() => {
        if (boundariesRef.current) {
            onCreated({
                id,
                width: boundariesRef.current.clientWidth
            });
        }
    });

    const dropOptions = useMemo<DsDropDownListItemProps[]>(() => {
        return dropdown?.options.map(option => {
            const { id: childId, title } = option;

            return {
                id: childId,
                label: title,
            }
        }) || []
    }, [dropdown]);

    const isDropdown = useMemo<boolean>(() => {
        return dropdown && dropdown.options.length > 0 ? true : false;
    }, [dropdown])

    const handleClick = (event: SyntheticEvent) => {
        onClick(event);

        if (isDropdown) {
            setIsExpanded(!isExpanded);
        }
    }

    return (
        <div className='chipContainer' ref={ref}>
            <div ref={boundariesRef} className={`dsChip ${className} ${variant} ${isDisabled ? 'isDisabled' : ''} ${isDropdown ? 'isDropdown' : ''}`} style={{ ...style, minWidth: isDropdown ? `${MIN_CHIP_WIDTH}px` : 'unset' }}>
                <DsTypography
                    onClick={handleClick}
                    title={typeof title === 'string' && !isDropdown ? title : undefined}
                    className="chipTitle"
                    variant={typographyVariant}>
                    {!isDropdown ? title : <div className="dropdownTitle">
                        <span className="plusSign">+</span>
                        <DsTypography className="dropCounterTitle" variant={typographyVariant}>{dropdown?.options.length}</DsTypography>
                    </div>}
                </DsTypography>
                {!isDropdown && <CloseIcon className='chipClose' onClick={(event: SyntheticEvent) => onRemove(event, id)} />}
            </div>
            {isDropdown && <DsDropDownList
                ref={dropdownRef}
                offsetX="-50%"
                isExpanded={isExpanded}
                onExpandChange={setIsExpanded}
                className="chipDropdownList"
                boundariesRef={boundariesRef}
                options={dropOptions}
                trigger={dropdown?.trigger}
                onMouseOver={() => dropdownRef.current?.focus()}
                formatOptionLabel={option => {
                    const customeOption = dropdown?.options.find(item => item.id === option.id)!;
                    const { id: childId, title, className } = customeOption;

                    return <DsChip
                        {...customeOption}
                        id={id}
                        title={title}
                        onRemove={(event: React.SyntheticEvent<Element, Event>) => onRemove(event, childId, id)}
                        typographyVariant={typographyVariant}
                        className={`chipDropItem ${className}`} />
                }}
            />}
        </div>
    )
})

DsChip.displayName = 'DsChip';