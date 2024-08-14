import React, { MouseEvent, RefObject, SyntheticEvent, forwardRef, useEffect, useMemo, useRef, useState } from "react";
import './dsDropDownList.scss';
import { DropDownCustomeItem, DsBaseComponentProps, TriggerType } from "@/app/components/dsComponents/dsTypes";
import { useOutsideClick } from "@/app/hooks/useOutsideClick";
import { DsButton, DsButtonProps } from "../dsButton/dsButton";
import { DsTypography } from "../dsTypography/dsTypography";
import usePosition, { PositionOffset } from "@/app/hooks/usePosition";
import useRunOnce from "@/app/hooks/useRunOnce";
import SearchIcon from "@/app/svgs/search.svg";
import CloseIcon from "@/app/svgs/close.svg";
import { bestMatchString } from "@/utils/stringUtils";
import { DsFlashingDotsLoader } from "../dsFlashingDotsLoader/dsFlashingDotsLoader";
import { Popover } from "../Popover";
import { _Classes } from "@/utils/cssHelper.util";

type ListPosition = 'bottom' | 'top';
export type SearchMethod = 'basic' | 'smart' | ((items: DsDropDownListItemProps[], searchValue: string) => DsDropDownListItemProps[])

export interface DsDropDownSearch {
    method: SearchMethod,
    addItem?: (label: string) => void,
    isLoading?: boolean
}

interface DsDropDownListContainerProps {
    boundariesComponent: JSX.Element,
    dropdownlist: DsDropDownListProps
    onClickChild: (event: SyntheticEvent) => void,
    isDisabled: boolean
}

export interface DsDropdownChildItemProps extends DsDropDownListItemProps {
    placement?: 'right' | 'left'
}

export interface DsDropDownListItemProps extends Omit<DsBaseComponentProps, 'typographyVariant'> {
    id: number | string,
    label: string,
    childItems?: DsDropdownChildItemProps[],
    isDisabled?: boolean,
    disabledReason?: string
}

const DsDropDownListContainer = forwardRef<HTMLDivElement, DsDropDownListContainerProps>(({
    boundariesComponent,
    dropdownlist,
    onClickChild,
    isDisabled
}: DsDropDownListContainerProps, ref) => {
    const parentRef = useRef<HTMLDivElement>(null);
    const [dropWidth, setDropWidth] = useState<number>(parentRef.current?.clientWidth || 0);

    const [isExpanded, setIsExpanded] = useState<boolean>(false);
    const [isMouseOver, setIsMouseOver] = useState<boolean>(false);

    const clickOutsideRef = useOutsideClick(() => {
        setTimeout(() => {
            if (!isMouseOver) {
                setIsExpanded(false);
            }
        }, 50);
    });

    return (
        <div className={`dropDownListContainer ${isDisabled ? 'isDisabled' : ''}`} ref={ref} onMouseOver={() => setIsMouseOver(true)} onMouseLeave={() => setIsMouseOver(false)}>
            <div ref={parentRef}>
                <div onClick={() => setIsExpanded(!isExpanded)} ref={clickOutsideRef} className="parentContainer">
                    {boundariesComponent}
                    <svg className="parentChevron" width="16" height="16" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
                        <path fill-rule="evenodd" clip-rule="evenodd" d="M5.43412 13.8773L5.30224 13.9793C5.21331 13.8642 5.16506 13.7228 5.16506 13.5774C5.16506 13.4319 5.21331 13.2905 5.30224 13.1754L5.30575 13.1709L9.60303 7.98858L5.29914 2.78833L5.29359 2.77962C5.22053 2.66504 5.18466 2.53068 5.19089 2.39493C5.1971 2.25957 5.24486 2.12943 5.32766 2.0222C5.3686 1.96807 5.42064 1.92331 5.48031 1.89094C5.54032 1.85838 5.60663 1.83911 5.67474 1.83444C5.74286 1.82977 5.81118 1.83981 5.87507 1.86387C5.93897 1.88794 5.99694 1.92546 6.04505 1.97391L6.05032 1.97921L10.6864 7.57084C10.7828 7.6858 10.8352 7.83189 10.8335 7.98188C10.833 8.12876 10.7827 8.27115 10.6908 8.38569L10.6891 8.38773L6.06165 13.9698C6.01916 14.0272 5.9646 14.0746 5.90178 14.1087C5.83715 14.1437 5.76543 14.1637 5.69199 14.1672L5.684 14.1675C5.61074 14.1675 5.53845 14.1506 5.47257 14.1186C5.4067 14.0865 5.34896 14.0399 5.30371 13.9823L5.43479 13.8794L5.43412 13.8773Z" fill="#404040" />
                    </svg>
                </div>
                <DsDropDownList {...dropdownlist} isExpanded={isExpanded} skipPositionMonitor={true} offsetX={`-${dropWidth}px`} onExpandChange={(isExpanded, dropWidth) => setDropWidth(dropWidth || 0)} onClick={event => {
                    setIsExpanded(false);
                    onClickChild(event);
                }} />
            </div>
        </div>
    )
})

DsDropDownListContainer.displayName = 'DsDropDownListContainer';

export interface DsDropDownListProps extends DsBaseComponentProps, DropDownCustomeItem<DsDropDownListItemProps> {
    isExpanded?: boolean,
    onExpandChange?: (isExpanded: boolean, dropWidth?: number) => void
    /** Element reference (useRef) that define the boundaries of the action list  */
    boundariesRef: RefObject<HTMLDivElement>
    /** Maximum dropdown height. Extra items will be visible by scroll */
    maxHeight?: string,
    options: DsDropDownListItemProps[],
    isDisabled?: boolean,
    /** There can be max of two action buttons  */
    actions?: [DsButtonProps] | [DsButtonProps, DsButtonProps];
    offsetX?: string,
    offsetY?: string,
    trigger?: TriggerType,
    skipPositionMonitor?: boolean,
    onMouseOver?: (event: MouseEvent<HTMLDivElement>) => void,
    isCloseOnClickOutside?: boolean,
    searchMethod?: DsDropDownSearch,
    /** If enabled the dropdown will open beneath or above the parent depending on the available space */
    autoPosition?: boolean
}

/**
 * Both this component and the boundariesRef component needs to be placed under a (display: block) div
 * The baloon list will automatically be placed ontop or under the boundariesRef, depending on the relative position to the view port
 */
export const DsDropDownList = forwardRef<HTMLDivElement, DsDropDownListProps>(({
    className = '',
    style = {},
    boundariesRef,
    maxHeight = '240px',
    options = [],
    isExpanded = false,
    isDisabled = false,
    onClick: onClickChildItem = () => { },
    onExpandChange = () => { },
    onMouseOver = () => { },
    actions,
    offsetX = '0px',
    offsetY = '0px',
    trigger = 'click',
    skipPositionMonitor = false,
    isCloseOnClickOutside = true,
    searchMethod,
    formatOptionLabel,
    autoPosition = false
}: DsDropDownListProps, ref) => {
    const margin = skipPositionMonitor ? -4 : 4;
    const isMouseOverDropdown = useRef<boolean>(false);
    const isMouseOverTrigger = useRef<boolean>(false);
    const actionListRef = useRef<HTMLDivElement>(null);

    const [offset, setOffset] = useState<PositionOffset>();
    const [isListExpanded, setIsListExpanded] = useState<boolean>(false);
    const [position, setPosition] = useState<ListPosition>('bottom');
    const [dropOptions, setDropOptions] = useState<DsDropDownListItemProps[]>(options);
    const [searchInput, setSearchInput] = useState<string>('');

    usePosition(boundariesRef, actionListRef, offset, skipPositionMonitor);


    const clickOutsideRef = useOutsideClick(() => {
        setTimeout(() => {
            if (isCloseOnClickOutside) {
                setIsListExpanded(false);
                onExpandChange(false, actionListRef.current?.clientWidth);
            }
        }, 50);
    });

    useRunOnce(() => {
        if (trigger === 'hover') {
            (boundariesRef.current as HTMLDivElement).addEventListener('mouseover', () => {
                isMouseOverTrigger.current = true;

                onExpandChange(!isListExpanded, actionListRef.current?.clientWidth);
                setIsListExpanded(!isListExpanded);
            });

            (boundariesRef.current as HTMLDivElement).addEventListener('mouseleave', () => {
                isMouseOverTrigger.current = false;

                setTimeout(() => {
                    if (!isMouseOverDropdown.current) {
                        onExpandChange(false, actionListRef.current?.clientWidth);
                        setIsListExpanded(false);
                    }
                }, 200);
            });
        }
    });

    useEffect(() => {
        setDropOptions(options);
    }, [options]);

    useEffect(() => {
        setIsListExpanded(isExpanded);

        setTimeout(() => {
            onExpandChange(isExpanded, actionListRef.current?.clientWidth);
        }, 0);

        setTimeout(() => {
            if (actionListRef.current) {
                const offsety = Number(offsetY.replace('px', ''));
                actionListRef.current.style.transform = `translate(${offsetX}, ${offsety + margin}px)`;
            }
        }, 0);
    }, [isExpanded, offsetX, offsetY, margin, onExpandChange])

    useEffect(() => {
        const manageOpenDirection = (actionList: HTMLDivElement, boundaries: HTMLDivElement) => {
            const vpHeight = window.innerHeight;
            const parentHeight = boundaries.clientHeight;
            // setParentWidth(boundaries.clientWidth);
            let totalHeight = margin;
            const { top, bottom } = actionList.getBoundingClientRect();

            if (top < 0) {
                setPosition('bottom');
                actionList.style.transform = `translate(${offsetX}, ${margin}px)`;
            } else if (bottom > vpHeight || position === 'top') {
                totalHeight = (actionList.clientHeight + parentHeight + margin) * -1;
                setPosition('top');
                actionList.style.transform = `translate(${offsetX}, ${totalHeight}px)`;
            }
        }

        setOffset({ top: boundariesRef.current?.clientHeight });

        setTimeout(() => {
            if (autoPosition && actionListRef.current && boundariesRef.current && isListExpanded) {
                manageOpenDirection(actionListRef.current, boundariesRef.current);
            }
        }, 0);
    }, [isListExpanded, boundariesRef, offsetX, margin, searchInput, position, autoPosition]);

    useEffect(() => {
        let filteredOptions: DsDropDownListItemProps[] = [];

        if (searchMethod?.method === 'smart') {
            const { ratings } = bestMatchString(searchInput, options.map<string>(option => {
                return option.label;
            }));

            const minScoreRatingList = ratings.filter(rating => rating.rating > 0);

            //If the smart filter do not produce a match use simple text matching
            if (minScoreRatingList.length > 0) {
                const sortedTargets = minScoreRatingList.sort((rate1, rate2) => rate2.rating - rate1.rating).map(rating => rating.target);
                filteredOptions = options.filter(options => sortedTargets.includes(options.label));
                filteredOptions.sort((label1, label2) => sortedTargets.indexOf(label1.label) - sortedTargets.indexOf(label2.label));
            } else {
                filteredOptions = options.filter(option => option.label.includes(searchInput));
            }
        } else if (typeof searchMethod?.method === 'function') {
            filteredOptions = searchMethod.method(options, searchInput);
        } else {
            filteredOptions = options.filter(option => option.label.toLowerCase().includes(searchInput.toLowerCase()));
        }

        setDropOptions(filteredOptions);
    }, [options, searchInput, searchMethod])

    const handleonMouseLeave = () => {
        isMouseOverDropdown.current = false;

        if (trigger === 'hover') {
            setTimeout(() => {
                if (!isMouseOverDropdown.current //This is not a mistake! even that on above line we set isMouseOverDropdown.current = false, in the setTimeout it can be true due to hover on child element
                    && !isMouseOverTrigger.current) {
                    onExpandChange(false, actionListRef.current?.clientWidth);
                    setIsListExpanded(false);
                }
            }, 200);
        }
    }

    const DropdownItems = (item: DsDropdownChildItemProps) => {
        const { label, childItems, placement = 'left', className = '', onClick = () => { }, style = {}, isDisabled } = item;
        const childRef = useRef<HTMLDivElement>(null);

        const customeLabel = (option: DsDropDownListItemProps) => {
            return formatOptionLabel ? formatOptionLabel(option) : <DsTypography isDisabled={isDisabled} variant="Regular_14"
                className={`dropItem ${className}`}
                style={style}
                onClick={event => {
                    if (!childItems) {
                        onExpandChange(false, actionListRef.current?.clientWidth);
                        setIsListExpanded(false);
                        onClickChildItem(event);
                    }
                    onClick(event);
                }}
            >{label}</DsTypography>;
        }

        const offset = useMemo((): string => {
            const dropDownWidth = (actionListRef.current?.clientWidth || 0);

            switch (placement) {
                case 'left': {
                    const offsetX = dropDownWidth * -1;
                    return `${offsetX}px`;
                }
                default: {
                    const offsetX = dropDownWidth;
                    return `${offsetX}px`;
                }
            }
        }, [placement]);

        if (childItems && childItems.length > 0) {
            return (
                <DsDropDownListContainer
                    ref={childRef}
                    boundariesComponent={<DsTypography variant="Regular_14" className="parentTitle">{customeLabel(item)}</DsTypography>}
                    dropdownlist={
                        {
                            boundariesRef: childRef,
                            options: childItems,
                            offsetX: offset,
                            offsetY: `${(boundariesRef.current ? ((boundariesRef.current.clientHeight * -1) - margin) : 0)}px`,
                            trigger: 'click',
                            formatOptionLabel
                        }
                    }
                    onClickChild={event => {
                        setIsListExpanded(false);
                        onExpandChange(false, actionListRef.current?.clientWidth);
                        onClickChildItem(event);
                    }}
                    isDisabled={!!isDisabled} />
            )
        }

        return <div onClick={() => setSearchInput('')}>
            <Popover className="dropDownItemPopover" placement="top-start" trigger={!item.isDisabled || !item.disabledReason ? null : "hover"} container={customeLabel(item)}>
                <DsTypography variant="Regular_14">{item.disabledReason}</DsTypography>
            </Popover>
        </div>;
    };

    return (
        <div className={`dsDropDownList ${className}`} ref={actionListRef} style={{ minWidth: boundariesRef.current?.clientWidth, ...style }}>
            <div className="actionListRef" ref={ref} tabIndex={0} onMouseOver={onMouseOver}>
                {isListExpanded && !isDisabled && <div className={`actionListContainer ${position}`} ref={clickOutsideRef}>
                    {searchMethod && <div className={`searchableContainer ${searchMethod.addItem ? 'searchAdd' : ''}`}>
                        <SearchIcon className="searchIcon" />
                        <input type="text" placeholder="Search" value={searchInput} className={`dropInputSearch ${_Classes('Regular_13')}`} onChange={event => setSearchInput(event.target.value)} />
                        <CloseIcon className={`closeSearch ${searchInput ? 'closeVisible' : ''}`} onClick={() => setSearchInput('')} />
                        {searchMethod.addItem && <>
                            {!searchMethod.isLoading && <DsButton variant="primary" type="text" isDisabled={!searchInput || searchInput.length === 0} onClick={() => {
                                searchMethod.addItem!(searchInput);
                                setSearchInput('');
                            }}>+ Add</DsButton>}
                            {searchMethod.isLoading && <DsFlashingDotsLoader />}
                        </>}
                    </div>}
                    <div className="itemsContainer"
                        style={{ maxHeight: maxHeight }}
                        onMouseOver={() => isMouseOverDropdown.current = true}
                        onMouseLeave={() => handleonMouseLeave()}>
                        {dropOptions.map((item, index) => {
                            return <DropdownItems key={index} {...item} />;
                        })}
                    </div>
                    {actions && <div className="actionsContainer">
                        {actions.map((action, index) => {
                            const { children, onClick = () => { } } = action;
                            return <DsTypography key={index} className="dsButtonContainer" variant="Regular_14" onClick={event => onClick(event)}>{children}</DsTypography>
                        })}
                    </div>}
                </div>}
            </div>
        </div>
    )
})

DsDropDownList.displayName = 'DsDropDownList';