import React, { MouseEvent, ReactElement, SyntheticEvent, forwardRef, useEffect, useRef, useState } from "react";
import './dsButton.scss';
import { DropDownCustomeItem, DsComponentProps, TriggerType } from "../dsTypes";
import { DsTypography } from "../dsTypography/dsTypography";
import LinkIcon from "@/app/[locale]/svgs/link.svg";
import ChevronIcon from "@/app/[locale]/svgs/chevron.svg";
import LoaderIcon from '@/app/[locale]/svgs/loader.svg';
import { DsDropDownList, DsDropDownListItemProps } from "../dsDropDownList/dsDropDownList";

export type ButtonsVariants = 'primary' | 'secondary' | 'destructive';

export interface DsBaseButton extends Omit<DsComponentProps<ButtonsVariants>, 'title'> {
    children?: string,
    isThin?: boolean,
    type?: 'text' | 'link' | 'icon' | 'button',
    isLoading?: boolean
}

interface Dropdown extends DropDownCustomeItem<DsDropDownListItemProps> {
    placement?: 'alignRight' | 'center' | 'alignLeft',
    items: DsDropDownListItemProps[],
    trigger?: TriggerType
}

export interface DsButtonProps extends DsBaseButton {
    icon?: ReactElement,
    /** Used with the link button. Will open a new tab with the provided link */
    externalLink?: string,
    dropDown?: Dropdown,
    hoverTooltip?: string
}

export const DsButton = forwardRef<HTMLDivElement, DsButtonProps>(({
    variant = 'Default',
    typographyVariant = 'Semibold_14',
    className = '',
    children,
    isThin,
    externalLink,
    onClick = (item: SyntheticEvent) => { },
    icon,
    type = 'button',
    isLoading,
    isDisabled,
    style,
    dropDown,
    hoverTooltip
}: DsButtonProps, ref) => {
    const boundariesRef = useRef<HTMLDivElement>(null);
    const [dropWidth, setDropWidth] = useState<number>(182);

    const [isExpanded, setIsExpanded] = useState<boolean>(false);
    const [offsetX, setOffsetX] = useState('0px');

    useEffect(() => {
        const placement = dropDown?.placement || 'right';
        const boundariesWidth = boundariesRef.current?.clientWidth || 0;
        const dropDownWidth = dropWidth || 0;

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

    }, [dropDown?.placement, dropWidth]);

    const handleButtonClick = (event: MouseEvent<HTMLDivElement>) => {
        onClick(event);
        if (dropDown?.items && dropDown?.items.length > 0) {
            setIsExpanded(!isExpanded);
        }
    }

    return (
        <div className={`dsButtonContainer ${className}`}>
            <div className={`boundariesRef`} ref={boundariesRef} style={style}>
                <div className={`dsButtons 
                    ${variant}
                    ${type}
                    ${isThin ? 'isThin' : ''} 
                    ${isLoading ? 'isLoading' : ''}
                    ${isDisabled ? 'isDisabled' : ''}
                    ${dropDown?.items ? 'dropdown' : ''}`}
                    onClick={(event) => handleButtonClick(event)}
                    ref={ref}>
                    <div className="buttonContent">
                        {(!isLoading || type !== 'button') && <>
                            {icon && <div className='extenrnalIcon'>{icon}</div>}
                            {/* {Icon && <div className='extenrnalIcon'>
                                <Image
                                    src={Icon}
                                    alt="clouds"
                                    width={24}
                                    height={24}
                                    priority
                                    />
                            </div>} */}
                            {type !== 'icon' && <DsTypography title={hoverTooltip} variant={typographyVariant} className='primaryButton'>
                                {type !== 'link' && children}
                                {type === 'link' && <div className="linkButton">
                                    <a href={externalLink} target="_blank" rel="noreferrer" className='externalLink'>{children}</a>
                                    <LinkIcon className='buttonIcon' />
                                </div>}
                            </DsTypography>}
                        </>}
                        {isLoading && type === 'button' && <LoaderIcon className="spinner" width={20} />}
                    </div>
                    {dropDown?.items && dropDown?.items.length > 0 && type !== 'icon' && <div className="dropdownIndicator">
                        <ChevronIcon className={`chevronIcon ${isExpanded ? 'isExpanded' : ''}`} />
                    </div>}
                </div>
            </div>
            {dropDown?.items && dropDown?.items.length > 0 && <DsDropDownList
                onExpandChange={(isExpanded, dropWidth) => {
                    setIsExpanded(isExpanded);
                    setDropWidth(dropWidth || 182);
                }}
                boundariesRef={boundariesRef}
                options={dropDown?.items}
                isExpanded={isExpanded}
                isDisabled={isDisabled || isLoading}
                offsetX={offsetX}
                trigger={dropDown.trigger}
                formatOptionLabel={dropDown.formatOptionLabel}
            />}
        </div>
    )
})

DsButton.displayName = 'DsButton';