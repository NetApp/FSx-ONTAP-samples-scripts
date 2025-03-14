import { MouseEvent, ReactElement, RefObject, SyntheticEvent, forwardRef, useEffect, useMemo, useRef, useState } from "react";
import './dsDropDownList.scss';
import { DropDownCustomeItem, DsBaseComponentProps, MonitorPosition, TriggerType } from "../dsTypes";
import { useOutsideClick } from "@/app/[locale]/hooks/useOutsideClick";
import { DsButton, DsButtonProps } from "../dsButton/dsButton";
import { DsTypography } from "../dsTypography/dsTypography";
import useChangePosition, { PositionOffset } from "@/app/[locale]/hooks/usePosition";
import useRunOnce from "@/app/[locale]/hooks/useRunOnce";
import SearchIcon from "@/app/[locale]/svgs/search.svg";
import CloseIcon from "@/app/[locale]/svgs/close.svg";
import { bestMatchString } from "@/utils/stringUtils";
import { DsFlashingDotsLoader } from "../dsFlashingDotsLoader/dsFlashingDotsLoader";
import { _Classes } from "@/utils/cssHelper.util";
import { DsPopover } from "../dsPopover/dsPopover";

type ListPosition = 'bottom' | 'top';
export type SearchMethod = 'basic' | 'smart' | ((items: DsDropDownListItemProps[], searchValue: string) => DsDropDownListItemProps[])

export interface DsDropDownSearch {
    method: SearchMethod,
    addItem?: (label: string) => void,
    isLoading?: boolean
}

interface DsDropDownListContainerProps {
    boundariesComponent: ReactElement,
    dropdownlist: DsDropDownListProps
    onClickChild: (event: SyntheticEvent) => void,
    isDisabled: boolean,
    disabledReason?: string,
    margin: number
}

export interface DsDropdownChildItemProps extends DsDropDownListItemProps {
    placement?: 'right' | 'left'
}

export interface DsDropDownListItemProps extends Omit<DsBaseComponentProps, 'typographyVariant' | 'id'> {
    id: number | string,
    label: string,
    childItems?: DsDropdownChildItemProps[],
    isDisabled?: boolean,
    isSelected?: boolean,
    disabledReason?: string,
}

const DsDropDownListContainer = forwardRef<HTMLDivElement, DsDropDownListContainerProps>(({
    boundariesComponent,
    dropdownlist,
    onClickChild,
    isDisabled,
    disabledReason
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

    const getOffsetY = () => {
        const parentHight = parentRef.current?.getBoundingClientRect().height;
        return ((parentHight || 0) * -1).toString()
    }

    return (
        <div className={`dropDownListContainer ${isDisabled ? 'isDisabled' : ''}`} ref={ref} onMouseOver={() => setIsMouseOver(true)} onMouseLeave={() => setIsMouseOver(false)}>
            <div ref={parentRef}>
                <DsPopover trigger={!isDisabled ? 'triggerDisabled' : "hover"} title={disabledReason} monitorPosition={'all'} placement="top">
                    <div onClick={() => setIsExpanded(!isExpanded)} ref={clickOutsideRef} className={_Classes('parentContainer', { isDisabled })}>
                        {boundariesComponent}
                        <svg className="parentChevron" width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                            <path d="M15.5 11.397C15.483 11.2231 15.4173 11.0546 15.3029 10.9212L11.6995 6.71982C11.4307 6.40651 11.0281 6.44766 10.7263 6.71982C10.4246 6.99199 10.4246 7.49915 10.7263 7.85442L13.8513 11.4979L10.7263 15.1456C10.4246 15.5009 10.4246 16.008 10.7263 16.2802C11.0281 16.5523 11.4307 16.5935 11.6995 16.2802L15.3029 12.0788C15.4173 11.9454 15.483 11.7769 15.5 11.603L15.5 11.397Z" fill="#404040" />
                        </svg>
                    </div>
                </DsPopover>
                {!isDisabled && <DsDropDownList {...dropdownlist}
                    boundariesRef={parentRef}
                    isExpanded={isExpanded}
                    className="dropDownChild"
                    monitorPosition='off'
                    offsetX={`-${dropWidth}px`}
                    offsetY={getOffsetY()}
                    onExpandChange={(_, dropWidth) => setDropWidth(dropWidth || 0)}
                    onClick={event => {
                        setIsExpanded(false);
                        onClickChild(event);
                    }}
                    autoPosition={true}
                    isAsubMenu={true} />}
            </div>
        </div>
    )
})

DsDropDownListContainer.displayName = 'DsDropDownListContainer';

type DropdownActions = [DsButtonProps] | [DsButtonProps, DsButtonProps];

export interface DsDropDownListProps extends DsBaseComponentProps, DropDownCustomeItem<DsDropDownListItemProps> {
    isExpanded?: boolean,
    onExpandChange?: (isExpanded: boolean, dropWidth?: number) => void
    /** Element reference (useRef) that define the boundaries of the action list  */
    boundariesRef: RefObject<HTMLDivElement | null>
    /** Maximum dropdown height. Extra items will be visible by scroll */
    maxHeight?: string,
    options: DsDropDownListItemProps[],
    isDisabled?: boolean,
    /** There can be max of two action buttons  */
    actions?: DropdownActions;
    offsetX?: string,
    offsetY?: string,
    trigger?: TriggerType,
    monitorPosition?: MonitorPosition
    onMouseOver?: (event: MouseEvent<HTMLDivElement>) => void,
    onClickOutside?: () => void,
    isCloseOnClickOutside?: boolean,
    searchMethod?: DsDropDownSearch,
    /** If enabled the dropdown will open beneath or above the parent depending on the available space */
    autoPosition?: boolean
    isAsubMenu?: boolean
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
    onClickOutside = () => { },
    actions,
    offsetX = '0px',
    offsetY = '0px',
    trigger = 'click',
    monitorPosition = 'all',
    isCloseOnClickOutside = true,
    searchMethod,
    formatOptionLabel,
    autoPosition = false,
    isAsubMenu = false,
    ...rest
}: DsDropDownListProps, ref) => {
    const margin = monitorPosition === 'left' ? -4 : 4;
    const isMouseOverDropdown = useRef<boolean>(false);
    const isMouseOverTrigger = useRef<boolean>(false);
    const actionListRef = useRef<HTMLDivElement>(null);

    const [offset, setOffset] = useState<PositionOffset>();
    const [isListExpanded, setIsListExpanded] = useState<boolean>(false);
    const [position, setPosition] = useState<ListPosition>('bottom');
    const [dropOptions, setDropOptions] = useState<DsDropDownListItemProps[]>(options);
    const [searchInput, setSearchInput] = useState<string>('');
    const [scrollTop, setScrollTop] = useState<number>(0);

    useChangePosition({ parentRef: boundariesRef, childRef: actionListRef, offsets: offset, monitorPosition });


    const clickOutsideRef = useOutsideClick(() => {
        setTimeout(() => {
            if (isCloseOnClickOutside) {
                setIsListExpanded(false);
                onExpandChange(false, actionListRef.current?.clientWidth);
            }

            onClickOutside()
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
    }, [isExpanded, onExpandChange])

    useEffect(() => {
        if (!isListExpanded) {
            setSearchInput('');
        }

        const manageOpenDirection = (actionList: HTMLDivElement, boundaries: HTMLDivElement) => {
            const vpHeight = window.innerHeight;
            const { top, bottom } = actionList.getBoundingClientRect();

            if (top < 0) {
                setPosition('bottom');
                actionList.style.transform = `translate(${offsetX}, ${margin}px)`;
            } else if (bottom > vpHeight) {
                const parentHeight = isAsubMenu ? 0 : boundaries.clientHeight;
                let totalHeight = margin;
                totalHeight = (actionList.clientHeight + parentHeight + (isAsubMenu ? margin * -1 : margin * 2)) * -1;
                setPosition('top');
                actionList.style.transform = `translate(${offsetX}, ${totalHeight}px)`;
            }
        }

        setOffset({ top: boundariesRef.current?.clientHeight });

        setTimeout(() => {
            if (actionListRef.current && boundariesRef.current && isListExpanded) {
                const offsety = Number(offsetY.replace('px', ''));
                actionListRef.current.style.transform = `translate(${offsetX}, ${offsety}px)`;

                if (autoPosition) {
                    manageOpenDirection(actionListRef.current, boundariesRef.current);
                }
            }
        }, 0);
    }, [isListExpanded, boundariesRef, offsetX, offsetY, margin, searchInput, position, autoPosition, isAsubMenu]);

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
        const { label, childItems, placement = 'left', className = '', onClick = () => { }, style = {}, isDisabled, disabledReason, isSelected, ...rest } = item;
        const childRef = useRef<HTMLDivElement>(null);

        const customeLabel = (option: DsDropDownListItemProps) => {
            return formatOptionLabel ? formatOptionLabel(option) : <DsTypography isDisabled={isDisabled} variant="Regular_14"
                className={_Classes('dropItem', className, { isDisabled, isSelected })}
                style={style}
                title={label}
                onClick={event => {
                    if (!isDisabled) {
                        if (!childItems) {
                            onExpandChange(false, actionListRef.current?.clientWidth);
                            setIsListExpanded(false);
                            onClickChildItem(event);
                        }
                        onClick(event);
                    }
                }}
                {...rest}
                id={rest.id.toString()}
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
                    isDisabled={!!isDisabled}
                    disabledReason={disabledReason}
                    margin={isAsubMenu ? Math.abs(margin) : margin} />
            )
        }

        return <div onClick={() => setSearchInput('')}>
            <DsPopover
                className="dropDownItemPopover"
                placement="top"
                trigger={!item.isDisabled || !item.disabledReason ? 'triggerDisabled' : "hover"}
                title={item.disabledReason}
                monitorPosition='off'
                offset={{ top: scrollTop * -1 }}>
                {customeLabel(item)}
            </DsPopover>
        </div>;
    };

    return (
        <div className={_Classes('dsDropDownList', className)} ref={actionListRef} style={{ minWidth: boundariesRef.current?.clientWidth, ...style }} {...rest}>
            <div className="actionListRef" ref={ref} tabIndex={0} onMouseOver={onMouseOver}>
                {isListExpanded && !isDisabled && <div className={`actionListContainer ${position}`} ref={clickOutsideRef}>
                    {searchMethod && <div className={`searchableContainer ${searchMethod.addItem ? 'searchAdd' : ''}`}>
                        <SearchIcon className="searchIcon" />
                        <input type="text" autoFocus placeholder="Search" value={searchInput} className={`dropInputSearch ${_Classes('Regular_13')}`} onChange={event => setSearchInput(event.target.value)} />
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
                        onScroll={(event => setScrollTop(event.currentTarget.scrollTop))}
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