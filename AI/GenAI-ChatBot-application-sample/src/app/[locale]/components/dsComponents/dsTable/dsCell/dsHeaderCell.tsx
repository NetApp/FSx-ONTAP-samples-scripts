import { ReactNode, RefObject, useEffect, useRef, useState } from "react";
import './dsHeaderCell.scss';
import { DsCell, DsCellBase, DsCellProps, DsCellVariant, FreezColumn } from "./dsCell";
import SortIcon from "@/app/[locale]/svgs/tableIcons/sort.svg";
import FilterIcon from "@/app/[locale]/svgs/tableIcons/filter.svg";
import { _Classes } from "@/utils/cssHelper.util";
import { DsRow } from "../dsTable";
import { DsSelect, DsSelectItemProps } from "../../dsSelect/dsSelect";

export type SortType = 'ascending' | 'descending' | 'unset';
export interface ColumnWidthType {
    value: number,
    unit: 'px' | '%'
}

export interface DsTableColumn extends DsCellBase {
    id: string,
    isSortable?: boolean,
    formatCells?: (cell: DsCellProps, row: DsRow, rowIndex: number) => ReactNode
    isResizable?: boolean,
    isFilterable?: boolean,
    isHidden?: boolean,
    width?: ColumnWidthType,
    //Action columns will not be sortable or resisable
    variant?: DsCellVariant,
    customeSort?: (rows: DsRow[], order: SortType) => DsRow[]
}

export interface DsColumnInner extends DsTableColumn {
    order?: SortType,
    onSortChange: (order: SortType) => void,
    onColumnStartDragg: (columnId: string, ref: RefObject<HTMLTableCellElement | null>) => void,
    onMount: (columnId: string, ref: RefObject<HTMLTableCellElement | null>) => void,
    onFilterSelect: (columnId: string, values: string[]) => void,
    isLast: boolean,
    filterItemList: string[],
    selectedItemsId: string[],
    freeze?: FreezColumn
}

export const DsHeaderCell = ({
    id,
    value,
    isDisabled,
    className,
    onClick = () => { },
    style = {},
    typographyVariant = 'Semibold_14',
    isResizable = true,
    isSortable = true,
    isFilterable,
    filterItemList = [],
    selectedItemsId = [],
    order = 'unset',
    onSortChange,
    onColumnStartDragg,
    onMount,
    onFilterSelect,
    width,
    isHidden,
    formatCell,
    isLast,
    variant = 'Data',
    freeze
}: DsColumnInner) => {
    const headerCellRef = useRef<HTMLTableCellElement>(null);

    const [sortState, setSortState] = useState<SortType>(order);

    useEffect(() => {
        setSortState(order);
        onMount(id, headerCellRef)
    }, [order, onMount, id])

    const toggleSorting = () => {
        let newSortState: SortType = sortState;

        switch (newSortState) {
            case 'unset': {
                newSortState = 'ascending';
                break;
            }
            case 'ascending': {
                newSortState = 'descending';
                break;
            }
            case 'descending': {
                newSortState = 'unset'
                break;
            }
        }

        setSortState(newSortState);
        onSortChange(newSortState);
    }

    return (
        <DsCell
            ref={headerCellRef}
            typographyVariant={typographyVariant}
            style={style}
            className={_Classes('dsHeaderCell', className, { isLast })}
            onClick={onClick}
            isHidden={isHidden}
            isDisabled={isDisabled}
            width={width}
            value={value}
            variant={variant}
            freeze={freeze}
            formatCell={() => {
                return (
                    <div className="headerCellContent">
                        <div className="headerValueContent">
                            {formatCell ? formatCell(value) : value}
                        </div>
                        {selectedItemsId.length > 0 && <div>({selectedItemsId.length})</div>}
                        {variant === 'Data' && (isSortable || isResizable) && <div className="cellActions">
                            {isFilterable && <DsSelect
                                formatLabel={<FilterIcon className="filterColumns" />}
                                options={filterItemList.map<DsSelectItemProps>(label => {
                                    return {
                                        id: label,
                                        label,
                                        value: label
                                    }
                                })}
                                dropDown={{
                                    placement: 'center',
                                    isCloseOnClickOutside: true,
                                    actions: [
                                        {
                                            children: 'Apply'
                                        },
                                        {
                                            children: 'Clear',
                                            onClick: () => onFilterSelect(id, [])
                                        }
                                    ]
                                }}
                                selectionType='multi'
                                isWithActions
                                onSelect={options => onFilterSelect(id, options.map(option => option.label))}
                                selectedOptionIds={selectedItemsId}
                            />}
                            {isSortable && <div className="sortingContainer" onClick={() => toggleSorting()}>
                                {sortState === 'unset' && <SortIcon />}
                                {sortState === 'ascending' && <svg width="12" height="15" viewBox="0 0 12 15" fill="none" xmlns="http://www.w3.org/2000/svg">
                                    <path fillRule="evenodd" clipRule="evenodd" d="M6.00011 14.3595C6.5524 14.3595 7.00011 13.9118 7.00011 13.3595L7.00011 6.3595L9.93259 6.3595C10.3565 6.3595 10.5881 5.86507 10.3167 5.53941L6.38422 0.820429C6.18433 0.580553 5.8159 0.580552 5.616 0.820428L1.68352 5.5394C1.41214 5.86507 1.64372 6.3595 2.06763 6.3595L5.00011 6.3595L5.00011 13.3595C5.00011 13.9118 5.44783 14.3595 6.00011 14.3595Z" fill="var(--icon-secondary)" />
                                </svg>}
                                {sortState === 'descending' && <svg width="12" height="15" viewBox="0 0 12 15" fill="none" xmlns="http://www.w3.org/2000/svg">
                                    <path fillRule="evenodd" clipRule="evenodd" d="M5.99989 0.640503C5.4476 0.640503 4.99989 1.08822 4.99989 1.6405V8.6405H2.06741C1.64349 8.6405 1.41191 9.13493 1.6833 9.46059L5.61578 14.1796C5.81567 14.4194 6.1841 14.4194 6.384 14.1796L10.3165 9.4606C10.5879 9.13493 10.3563 8.6405 9.93237 8.6405H6.99989V1.6405C6.99989 1.08822 6.55217 0.640503 5.99989 0.640503Z" fill="#404040" />
                                </svg>}
                            </div>}
                            {isResizable && <div
                                className={_Classes('resizeElement', { isResizable })}
                                onMouseDownCapture={() => onColumnStartDragg(id, headerCellRef)} />}
                        </div>}
                    </div>
                )
            }} />
    )
}