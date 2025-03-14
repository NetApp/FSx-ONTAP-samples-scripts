import { forwardRef, Fragment, ReactElement, RefObject, useCallback, useEffect, useMemo, useRef, useState } from "react";
import './dsTable.scss';
import { DsBaseComponentProps } from "../dsTypes";
import { DsCard } from "../dsCard/dsCard";
import { DsCell, DsCellProps, FreezColumn, FreezeDirection } from "./dsCell/dsCell";
import FileIcon from "@/app/[locale]/svgs/tableIcons/file.svg";
import { DsTypography } from "../dsTypography/dsTypography";
import { ColumnWidthType, DsHeaderCell, DsTableColumn, SortType } from "./dsCell/dsHeaderCell";
import useRunOnce from "@/app/[locale]/hooks/useRunOnce";
import { useRefDimensions } from "@/app/[locale]/hooks/useRefDimentions";
import { _Classes } from "@/utils/cssHelper.util";
import { DsBaseButton } from "../dsButton/dsButton";
import DsTableFooter from "./dsTableFooter/dsTableFooter";
import useSyncScroll from "@/app/[locale]/hooks/useSyncScroll";
import useRunUntil from "@/app/[locale]/hooks/useRunUntil";
import { DsRadioButton } from "../../dsRadioButton/dsRadioButton";
import { DsCheckbox } from "../dsCheckbox/dsCheckbox";

export interface DsRow {
    id: string,
    cells: { [columnId: string]: DsCellProps }
    isDisabled?: boolean,
    disabledReason?: string,
    isSelectable?: boolean,
    expandable?: {
        isExpandable?: boolean,
        children?: ReactElement
    }
}

interface DsRowInner extends DsRow {
    isExpanded?: boolean
}

export type DsColumn = Omit<DsTableColumn, 'onSortChange'>;
export interface DsSortedColumn {
    columnId: string,
    order: SortType
}

interface FreezeOptions {
    freezLeftColumnId?: string
    freezRightColumnId?: string
}

export interface DsTableProps extends Omit<DsBaseComponentProps, 'onClick' | 'typographyVariant'> {
    columns: DsColumn[],
    data: DsRow[],
    rowHight?: 'single' | 'double',
    //Set a maximum height (in pixels) of the table
    maxHeight?: number,
    defaultSortedColumn?: DsSortedColumn,
    isHorizontalScroll?: boolean,
    pageSize?: number | false,
    actions?: DsBaseButton[],
    title?: string,
    isSearchable?: boolean,
    noDataText?: string,
    onRowHover?: (rowData: DsRow, rowIndex: number) => void
    onRowClick?: (rowData: DsRow, rowIndex: number) => void,
    onRowSelect?: (selectedRowsId: string[]) => void,
    onSort?: (col: DsColumn, order: SortType) => void,
    onRowsExapnded?: () => void,
    selectionType?: 'singular' | 'multiple',
    selectedRowsId?: string[],
    freezeOptions?: FreezeOptions,
    isLoading?: boolean,
    variant?: 'default' | 'light'
}

export const DsTable = forwardRef<HTMLDivElement, DsTableProps>(({
    className = '',
    style = {},
    columns = [],
    data = [],
    rowHight = 'single',
    maxHeight,
    defaultSortedColumn,
    isHorizontalScroll,
    pageSize = 50,
    actions = [],
    title,
    isSearchable = true,
    noDataText,
    onRowHover = () => { },
    onRowClick = () => { },
    onRowSelect = () => { },
    onSort = () => { },
    selectionType,
    selectedRowsId = [],
    freezeOptions,
    isLoading,
    variant = 'default',
    ...rest
}: DsTableProps, ref) => {
    const rowspanCells = useRef<Colspan>({});
    const tableContainerRef = useRef<HTMLDivElement>(null);
    const tableElementRef = useRef<HTMLTableElement>(null);
    const tableTopBarRef = useRef<HTMLDivElement>(null);
    const tableFooterRef = useRef<HTMLDivElement>(null);
    const horizontalScrollRef = useRef<HTMLDivElement>(null);
    const tableHeaderRef = useRef<HTMLTableSectionElement>(null);
    const tableDataFilteredRef = useRef<DsRowInner[]>([]);
    const enabledRowsRef = useRef<DsRowInner[]>([]);
    const doneLoadingRef = useRef<boolean>(false);

    const ACTION_COL = useMemo(() => {
        return {
            width: 56,
            idPref: '_ACTION_COL_'
        }
    }, []);

    type Colspan = {
        [colIndex: string]: {
            rowIndex: number,
            rowSpan: number
        }
    };

    const [tableData, setTableData] = useState<DsRowInner[]>(data);
    const [tableColumns, setTableColumns] = useState<DsColumn[]>(columns);
    const [managedTableColumns, setManagedTableColumns] = useState<DsColumn[]>(columns);
    const [sortedColumn, setSortedColumn] = useState<DsSortedColumn | undefined>(defaultSortedColumn);
    const [tableContainerWidth, setTableContainerWidth] = useState<number>(0);
    const [isAllColumnsFixedWidth, setIsAllColumnsFixedWidth] = useState<boolean>(false);
    const [currentPage, setCurrentPage] = useState<number>(1);
    const [searchValue, setSearchValue] = useState<string>();
    const [forceRender, setForceRender] = useState<number>(Date.now());
    const [columnDraggingParams, setColumnStartDraggParams] = useState<{
        columnId: string,
        origWidth: number,
        move: number
    }>()
    const [mainLayout, setMainLayout] = useState<HTMLElement | null>(null);
    const [selectedIds, setSelectedIds] = useState<string[]>(selectionType === 'singular' ? [selectedRowsId[0]] : selectedRowsId);
    const [filterdColumns, setFilterdColumns] = useState<{ [columnId: string]: string[] }>({});
    const [freezeColumns, setFreezeColumns] = useState<{
        [columnId: string]: {
            direction: FreezeDirection,
            width: number
        },
    }>({});
    const [freezeSettings, setFreezeSettings] = useState<FreezeOptions | undefined>(freezeOptions);

    const { width: widthFromContainerRef, top: tableTopPosition } = useRefDimensions(tableContainerRef.current);
    const { height: mainLayoutHight } = useRefDimensions(mainLayout);
    const { width: tableWidth } = useRefDimensions(tableElementRef.current);
    useSyncScroll([horizontalScrollRef, tableContainerRef], "horizontal")

    useRunUntil(() => {
        setTimeout(() => {
            const mainLayoutElement = document.querySelector('body');
            if (mainLayoutElement) setMainLayout(mainLayoutElement);
        }, 0);
    }, !!mainLayout)

    useEffect(() => {
        setTableData(data);
    }, [data])

    useEffect(() => {
        setTableColumns(columns);
        setManagedTableColumns(columns);
    }, [columns])

    const isNotActionCol = useCallback((col: DsColumn): boolean => {
        return !col.id.includes(ACTION_COL.idPref) && col.variant !== 'Action';
    }, [ACTION_COL.idPref])

    const hasExpandableRows = useMemo<boolean>(() => {
        return data.some(row => row.expandable?.isExpandable);
    }, [data])

    useEffect(() => {
        if (columnDraggingParams) {
            const { columnId, origWidth, move } = columnDraggingParams;

            setTableColumns(tableColumns => {
                const draggedCol = tableColumns.find(col => col.id === columnId)!;
                const newWidth = origWidth + move;

                if (draggedCol.width?.value !== newWidth) {
                    const newValue = origWidth + move;

                    draggedCol.width = {
                        unit: 'px',
                        value: newValue < 0 ? 0 : newValue
                    }

                    setForceRender(Date.now());
                }

                return tableColumns;
            });
        }
    }, [columnDraggingParams, tableColumns])

    useRunOnce(() => {
        if (sortedColumn) {
            const { columnId, order } = sortedColumn;
            const col = tableColumns.find(col => col.id === columnId);

            if (col) handleSort(order, col);
        }
    });

    useEffect(() => {
        setTableContainerWidth(widthFromContainerRef);
    }, [widthFromContainerRef])

    const totalColumnsWidth = useCallback((onlyAction?: boolean): number => {
        const allColumnsWidth = tableColumns.reduce((totalWidth, col) => {
            const { width: { unit = 'px', value = 0 } = {} } = col;
            let colWidth = 0;

            switch (unit) {
                case 'px': {
                    colWidth = value;
                    break;
                }
                case '%': {
                    colWidth = tableContainerWidth * value / 100;
                    break;
                }
            }

            let widthForAdd = col.isHidden ? 0 : colWidth;
            if (onlyAction && isNotActionCol(col)) {
                widthForAdd = 0;
            }

            return totalWidth + widthForAdd;
        }, 0)

        return allColumnsWidth;
    }, [tableColumns, tableContainerWidth, isNotActionCol])

    const isTotalColWidthLessThanTable = useMemo((): boolean => {
        return totalColumnsWidth() < tableContainerWidth;
    }, [tableContainerWidth, totalColumnsWidth])

    const handleSort = useCallback((order: SortType, column: DsColumn) => {
        const { id, customeSort } = column;

        const sortedData = customeSort ? customeSort([...data], order) : [...data].sort((row1, row2) => {
            const val1 = row1.cells[id] ? row1.cells[id].value : '';
            const val2 = row2.cells[id] ? row2.cells[id].value : '';

            if (!val1 || !val2) return 1;

            switch (order) {
                case 'ascending': {
                    return val1.localeCompare(val2, undefined, { numeric: true }) > 0 ? 1 : -1
                }
                case 'descending': {
                    return val1.localeCompare(val2, undefined, { numeric: true }) > 0 ? -1 : 1
                }
                default:
                    return 0
            }
        });

        setSortedColumn({
            columnId: id,
            order
        });
        setTableData(() => order === 'unset' ? [...data] : [...sortedData]);
    }, [data])

    const tableDataSearcheFiltered = useMemo((): DsRowInner[] => {
        tableDataFilteredRef.current = searchValue ? tableData.filter(row => {
            return JSON.stringify(row.cells).toLowerCase().includes(searchValue);
        }) : tableData;

        return tableDataFilteredRef.current;
    }, [searchValue, tableData])

    const tableDataFiltered = useMemo((): DsRowInner[] => {
        // filterdColumns
        const isInFilterSelection = (cells: { [columnId: string]: DsCellProps }): boolean => {
            let isShow = true;
            const cellEntires = Object.entries(cells);
            const filterKeys = Object.keys(filterdColumns);

            if (filterKeys.length === 0) return true;

            cellEntires.forEach(cell => {
                if (filterKeys.includes(cell[0])) {
                    const cellValue = cell[1].value;
                    if (!cellValue || !filterdColumns[cell[0]].includes(cellValue)) {
                        isShow = false
                    };
                }
            })

            return isShow;
        }

        return tableDataSearcheFiltered.filter(row => isInFilterSelection(row.cells));
    }, [tableDataSearcheFiltered, filterdColumns])

    const numberOfPages = useMemo((): number => {
        return Math.ceil(tableDataFiltered.length / (pageSize as number));
    }, [pageSize, tableDataFiltered.length])

    const showPagination = useMemo<boolean>(() => {
        if (currentPage > numberOfPages) setCurrentPage(numberOfPages || 1);

        return pageSize ? tableDataFiltered.length > pageSize : false;
    }, [tableDataFiltered.length, pageSize, currentPage, numberOfPages])

    const showHorizontalScroll = useMemo<boolean>(() => {
        return (!!isHorizontalScroll && (tableContainerRef.current?.clientWidth || 0) < tableWidth);
    }, [isHorizontalScroll, tableWidth])

    const tableRows = useMemo<DsRowInner[]>(() => {
        const startIndex = (currentPage - 1) * (pageSize as number);
        const rows = showPagination ? tableDataFiltered.slice(startIndex, startIndex + (pageSize as number)) : tableDataFiltered;
        enabledRowsRef.current = rows.filter(row => !row.isDisabled || row.isSelectable);

        return rows;
    }, [showPagination, currentPage, pageSize, tableDataFiltered])

    useEffect(() => {
        let managedCols = [...managedTableColumns];

        const selectionCol = (cols: DsColumn[]): DsColumn[] => {
            const SELECTION_COL_ID = `${ACTION_COL.idPref}selectionColumns`;
            let newSelectedIds = selectedIds;

            const selectionCols: DsColumn[] = [{
                id: SELECTION_COL_ID,
                width: {
                    value: ACTION_COL.width + 10,
                    unit: 'px'
                },
                className: 'selectionColumns',
                isSortable: false,
                isResizable: false,
                isFilterable: false,
                value: '',
                formatCell: () => {
                    const enabledFilteredRows = tableDataFilteredRef.current.filter(row => !row.isDisabled || row.isSelectable).map(row => row.id);

                    return (
                        <>
                            {selectionType === 'multiple' && <DsCheckbox
                                id={Date.now().toString()}
                                variant="tableHeaderCheckbox"
                                indeterminate={newSelectedIds.length > 0 && newSelectedIds.length < enabledFilteredRows.length}
                                isSelected={newSelectedIds.length === enabledFilteredRows.length}
                                dropDown={{
                                    items: [
                                        {
                                            id: 'thisPage',
                                            label: 'Select this page',
                                            isSelected: newSelectedIds.length < enabledFilteredRows.length && !enabledRowsRef.current.some(row => !newSelectedIds.includes(row.id)),
                                            onClick: () => {
                                                newSelectedIds = enabledRowsRef.current.map(row => row.id);
                                                setSelectedIds(newSelectedIds)
                                            }
                                        },
                                        {
                                            id: 'allPages',
                                            label: 'Select all pages',
                                            isSelected: newSelectedIds.length === enabledFilteredRows.length,
                                            onClick: () => {
                                                newSelectedIds = enabledFilteredRows;
                                                setSelectedIds(newSelectedIds)
                                            }
                                        },
                                        {
                                            id: 'clearAll',
                                            label: 'Clear all',
                                            isDisabled: newSelectedIds.length === 0,
                                            onClick: () => {
                                                newSelectedIds = [];
                                                setSelectedIds(newSelectedIds)
                                            }
                                        }
                                    ],
                                    placement: 'center'
                                }} />}
                        </>
                    )
                },
                formatCells: (_, row) => {
                    return (
                        <>
                            {selectionType === 'singular' && <DsRadioButton
                                id={row.id}
                                variant="tableRadio"
                                isDisabled={(row.isDisabled && (row.isSelectable === undefined || row.isSelectable === false)) || row.isSelectable === false}
                                disabledReason={row.isSelectable !== true ? row.disabledReason : undefined}
                                groupName="tableSingulr"
                                isSelected={newSelectedIds.includes(row.id)}
                                onSelect={() => {
                                    newSelectedIds = [row.id];
                                    setSelectedIds(newSelectedIds);
                                    onRowSelect(newSelectedIds);
                                }} />}
                            {selectionType === 'multiple' && <DsCheckbox
                                id={row.id}
                                variant="tableCheckbox"
                                isDisabled={(row.isDisabled && (row.isSelectable === undefined || row.isSelectable === false)) || row.isSelectable === false}
                                disabledReason={row.isSelectable !== true ? row.disabledReason : undefined}
                                isSelected={newSelectedIds.includes(row.id)}
                                onCheckedChange={isChecked => {
                                    newSelectedIds = isChecked ? [...newSelectedIds, row.id] : newSelectedIds.filter(id => id !== row.id);
                                    setSelectedIds(newSelectedIds);
                                    onRowSelect(newSelectedIds);
                                }} />}
                        </>
                    )
                }
            }, ...cols];

            setFreezeSettings(freezeSettings => {
                if (!freezeSettings?.freezLeftColumnId) return {
                    ...freezeSettings,
                    freezLeftColumnId: SELECTION_COL_ID
                }

                return freezeSettings;
            })

            return selectionCols;
        }

        if (selectionType) {
            managedCols = selectionCol([...managedCols]);
        }

        setTableColumns(columns => {
            return (columns.toString() !== managedCols.toString()) ? managedCols : columns;
        });

        if (!doneLoadingRef.current) {
            setTimeout(() => {
                doneLoadingRef.current = true;
                setForceRender(Date.now());
            }, 200);
        }
    }, [tableRows, hasExpandableRows, tableColumns, selectedIds, managedTableColumns, selectionType, ACTION_COL, forceRender, isNotActionCol, onRowSelect])

    const footerOffset = useMemo<number>(() => {
        const footerHight = tableFooterRef.current?.clientHeight || 0;
        const headerHight = tableHeaderRef.current?.clientHeight || 0;
        const availableHight = mainLayoutHight - headerHight - tableTopPosition;

        return availableHight > footerHight ? 0 : (availableHight - footerHight)
    }, [tableTopPosition, mainLayoutHight])

    const showCell = (row: DsRowInner, rowIndex: number, colIndex: number): boolean => {
        const spanIndex = Object.values(row.cells).map((cell, index) => {
            return {
                colIndex: index,
                rowIndex,
                colspan: cell.colspan,
                rowSpan: cell.rowSpan
            };
        });

        const cellsWithColspan = spanIndex.filter(item => item.colspan && item.colspan > 1);
        const colSpanIsShow = cellsWithColspan.length === 0 || cellsWithColspan.some(colpanCell => colpanCell.colIndex === colIndex || colIndex < colpanCell.colIndex || colIndex > (colpanCell.colIndex + colpanCell.colspan! - 1));

        const cellsWithRowspan = spanIndex.filter(item => item.rowSpan && item.rowSpan > 1);

        if (cellsWithRowspan.length > 0) {
            const colspan: Colspan = {};
            cellsWithRowspan.forEach(cell => {
                const { colIndex, rowIndex, rowSpan = 1 } = cell;
                colspan[colIndex] = {
                    rowIndex,
                    rowSpan
                };
            });

            rowspanCells.current = { ...rowspanCells.current, ...colspan };
        }

        const rowSpanCell = rowspanCells.current[colIndex];
        const rowSpanIsShow = !rowSpanCell || rowIndex <= rowSpanCell.rowIndex || rowIndex > (rowSpanCell.rowSpan + rowSpanCell.rowIndex - 1);

        return colSpanIsShow && rowSpanIsShow;
    }

    const manageColumnsWidth = useCallback((col: DsColumn, colIndex: number, origColWidth?: ColumnWidthType): ColumnWidthType | undefined => {
        let colWidth = origColWidth;

        const transformPercentToPixels = (width?: ColumnWidthType): ColumnWidthType | undefined => {
            if (!tableContainerWidth || !width || width.unit === 'px') return width

            const calculatedWidth = tableContainerWidth * width.value / 100

            return {
                unit: 'px',
                value: calculatedWidth
            }
        }

        //In case total column width is less than the width of the table
        if (isNotActionCol(tableColumns[colIndex]) && tableColumns.filter(col => isNotActionCol(col)).length === colIndex + 1 && !col.isHidden) {
            colWidth = isTotalColWidthLessThanTable ? undefined : colWidth;
        }

        const devideToCols = tableColumns.filter(col => !col.width && !col.isHidden).length;
        const needToManageAllColumns = !showHorizontalScroll && tableContainerWidth && (tableContainerWidth < tableWidth || isAllColumnsFixedWidth) && !origColWidth?.value && !col.isHidden;
        if (needToManageAllColumns) {
            const newColWidth = (tableContainerWidth - totalColumnsWidth()) / (devideToCols || 1);

            colWidth = {
                value: newColWidth,
                unit: 'px'
            }

            if (!isAllColumnsFixedWidth) {
                setIsAllColumnsFixedWidth(true);
            }
        }

        //Only fixed and action cols are remained
        if (devideToCols === 0 && !col.isHidden && isNotActionCol(col)) {
            if (columnDraggingParams?.columnId) {
                const visibleCols = tableColumns.filter(col => !col.isHidden && isNotActionCol(col));
                const draggedColIndex = visibleCols.findIndex(col => col.id === columnDraggingParams.columnId);
                const visibleColIndex = visibleCols.findIndex(visibleCol => visibleCol.id === col.id);

                if ((draggedColIndex === 0 && visibleColIndex === visibleCols.length - 1) || (draggedColIndex > 0 && visibleColIndex === 0)) {
                    colWidth = undefined;

                    setTableColumns(tableColumns => {
                        const resetCol = tableColumns.find(tableCol => tableCol.id === col.id)!;
                        resetCol.width = undefined;

                        return tableColumns;
                    });
                }
            } else if (tableContainerWidth < totalColumnsWidth()) {
                colWidth = {
                    value: (tableContainerWidth - totalColumnsWidth(true)) / tableColumns.filter(col => !col.isHidden && col.width && isNotActionCol(col)).length,
                    unit: 'px'
                }
            }
        }

        return transformPercentToPixels(colWidth);
    }, [isTotalColWidthLessThanTable, columnDraggingParams?.columnId, isAllColumnsFixedWidth, tableColumns, tableContainerWidth, tableWidth, showHorizontalScroll, totalColumnsWidth, isNotActionCol])

    const jumpToPage = (pageNumber: number) => {
        setCurrentPage(pageNumber);
        tableContainerRef.current!.scrollTop = 0
    }

    const isLastVisibleColumn = (index: number) => {
        return [...tableColumns].reverse().findIndex(col => !col.isHidden && isNotActionCol(col)) === index;
    }

    const onColumnStartDragg = (columnId: string, ref: RefObject<HTMLTableCellElement | null>) => {
        document.body.style.cursor = 'col-resize';

        const handleDragg = (event: MouseEvent) => {
            setColumnStartDraggParams({
                columnId,
                origWidth: ref.current!.clientWidth,
                move: event.movementX
            });
        }

        const mouseup = () => {
            document.body.style.cursor = 'initial';
            setColumnStartDraggParams(undefined);
            document.removeEventListener('mousemove', handleDragg);
            document.removeEventListener('mouseup', mouseup);
        }

        document.addEventListener('mousemove', handleDragg);
        document.addEventListener('mouseup', mouseup);
    }

    const isHeaderHidden = (): boolean => {
        return !title && actions.length === 0 && !isSearchable;
    }

    const tableMaxHight = (): string | undefined => {
        if (maxHeight && maxHeight < mainLayoutHight) return `${maxHeight}px`;
        if (showHorizontalScroll) return `${mainLayoutHight - (tableTopBarRef.current?.clientHeight || 0) - (tableFooterRef.current?.clientHeight || 0) - (showPagination ? 0 : 6) - 1}px`;
    }

    const uniqueRowValues = (colId: string): string[] => {
        const allRowsValue = tableDataSearcheFiltered.map<string | undefined>(row => {
            return row.cells[colId] ? row.cells[colId].value : undefined
        });

        const onlyUnique = (value: string, index: number, array: (string | undefined)[]) => {
            return array.indexOf(value) === index;
        }

        return allRowsValue.filter((value, index) => value && onlyUnique(value, index, allRowsValue)) as string[];
    }

    const handleRowClick = (row: DsRowInner, rowIndex: number) => {
        onRowClick(row, rowIndex);

        if (row.expandable?.isExpandable) {
            const rw = tableData.find(rw => rw.id === row.id);

            if (rw) {
                rw.isExpanded = !rw.isExpanded;
                setTableData([...tableData])
            }
        }
    }

    const freezDirection = (column: DsColumn): FreezColumn | undefined => {
        if (!freezeSettings || !isHorizontalScroll) return undefined;

        const { freezLeftColumnId, freezRightColumnId } = freezeSettings;
        const colIndex = tableColumns.findIndex(col => col.id === column.id);
        const freezLeftColumnIdIndex = tableColumns.findIndex(col => col.id === freezLeftColumnId);
        const freezRightColumnIdIndex = tableColumns.findIndex(col => col.id === freezRightColumnId);

        let offset = 0;
        if (freezLeftColumnIdIndex > -1 && colIndex <= freezLeftColumnIdIndex) {
            for (let index = 0; index < colIndex; index++) {
                const id = tableColumns[index].id;
                offset += freezeColumns[id] ? freezeColumns[id].width : 0;
            }
        } else if (freezRightColumnIdIndex > -1 && colIndex >= freezRightColumnIdIndex) {
            for (let index = tableColumns.length - 1; index > colIndex; index--) {
                const id = tableColumns[index].id;
                offset += freezeColumns[id] ? freezeColumns[id].width : 0;
            }
        }

        if (freezLeftColumnIdIndex > -1 && tableColumns.findIndex(col => col.id === column.id) <= tableColumns.findIndex(col => col.id === freezLeftColumnId)) {
            return {
                direction: 'Left',
                offset,
                isLast: isNotActionCol(column) && column.id === freezLeftColumnId
            }
        } else if (freezRightColumnIdIndex > -1 && tableColumns.findIndex(col => col.id === column.id) >= tableColumns.findIndex(col => col.id === freezRightColumnId)) return {
            direction: 'Right',
            offset,
            isLast: isNotActionCol(column) && column.id === freezRightColumnId
        }

        return undefined
    }

    return (
        <div className={_Classes('dsTable', className, `table-${variant}`, { isVisible: doneLoadingRef.current })} ref={ref} style={style} {...rest}>
            <DsCard className={_Classes('tableCardContent', { isHorizontalScroll: showHorizontalScroll, maxHeight: !!maxHeight, showPagination, isHeaderHidden: isHeaderHidden() })} ref={tableContainerRef} style={{ maxHeight: tableMaxHight() }}>
                <table className="tableElement" ref={tableElementRef}>
                    <thead ref={tableHeaderRef} style={{ zIndex: tableRows.length + 1 }}>
                        <tr>
                            {tableColumns.map((col, index) => {
                                const { id, isSortable, width } = col;
                                const { columnId, order: sortedColumnOrder = 'unset' } = sortedColumn || {};
                                const colWidth = manageColumnsWidth(col, index, width);
                                const freeze = freezDirection(col);

                                return (
                                    <DsHeaderCell
                                        key={index}
                                        {...col}
                                        width={colWidth}
                                        isLast={isLastVisibleColumn(index)}
                                        className={_Classes(col.className, { isLastAndNoExtraCols: index === tableColumns.length - 1 })}
                                        isHidden={col.isHidden}
                                        freeze={freeze}
                                        onSortChange={order => {
                                            handleSort(order, col);
                                            onSort(col, order);
                                        }}
                                        onColumnStartDragg={onColumnStartDragg}
                                        isSortable={isSortable}
                                        order={sortedColumn && columnId !== id ? 'unset' : sortedColumnOrder}
                                        onMount={(_, ref) => {
                                            if (col.variant === 'Action' && !col.width) {
                                                col.width = {
                                                    unit: 'px',
                                                    value: ref.current?.clientWidth || 0
                                                }
                                            }

                                            if (ref.current && freeze) {
                                                setFreezeColumns(freezeColumns => {
                                                    if (freezeColumns[col.id]?.width === ref.current!.clientWidth) return freezeColumns;

                                                    return {
                                                        ...freezeColumns,
                                                        [col.id]: {
                                                            direction: freeze.direction,
                                                            width: ref.current!.clientWidth
                                                        }
                                                    }
                                                })
                                            }
                                        }}
                                        filterItemList={isNotActionCol(col) ? uniqueRowValues(col.id) : []}
                                        onFilterSelect={(columnId: string, values: string[]) => {
                                            setFilterdColumns(filterdColumns => {
                                                if (values.length > 0) {
                                                    return {
                                                        ...filterdColumns,
                                                        [columnId]: values
                                                    }
                                                } else {
                                                    delete filterdColumns[columnId];
                                                    return {
                                                        ...filterdColumns,
                                                    }
                                                }
                                            });
                                        }}
                                        selectedItemsId={(() => {
                                            return filterdColumns[col.id];
                                        })()}
                                    />
                                )
                            })}
                        </tr>
                    </thead>
                    <tbody>
                        {tableRows.map((row, rowIndex) => {
                            const { id, isDisabled, expandable: { isExpandable, children } = {}, isExpanded } = row;

                            return (
                                <Fragment key={rowIndex}>
                                    <tr
                                        key={rowIndex}
                                        style={{ zIndex: tableRows.length - rowIndex }}
                                        onMouseEnter={() => isDisabled ? {} : onRowHover(row, rowIndex)}
                                        onClick={() => isDisabled ? {} : handleRowClick(row, rowIndex)}
                                        className={_Classes('rowHeader', { isSelected: selectedIds.includes(id), isDisabled, isExpandable })}>
                                        {tableColumns.map((col, colIndex) => {
                                            const cell = row.cells[col.id];
                                            const { className, value, formatCell } = cell || {};
                                            const isShowCell = showCell(row, rowIndex, colIndex);
                                            const { formatCells, width } = col;
                                            const colWidth = manageColumnsWidth(col, colIndex, width);
                                            const freeze = freezDirection(col);

                                            return (
                                                isShowCell ? <DsCell key={colIndex}
                                                    {...cell}
                                                    variant={col.variant}
                                                    freeze={freeze}
                                                    className={_Classes(className, { doubleHight: rowHight === 'double' })}
                                                    isHidden={col.isHidden}
                                                    width={colWidth}
                                                    value={value}
                                                    isDisabled={isDisabled}
                                                    formatCell={formatCell ? () => formatCell(value) : formatCells ? () => formatCells(cell, row, rowIndex) : undefined} /> : undefined
                                            )
                                        })}
                                    </tr>
                                    {isExpandable && <tr key={`${rowIndex}_expanded`} className={_Classes('expandedRowContainer', { isExpanded })}>
                                        <td colSpan={tableColumns.filter(col => !col.isHidden).length}>
                                            <div className="expandedCellContainer">{children}</div>
                                        </td>
                                    </tr>}
                                </Fragment>
                            )
                        })}
                    </tbody>
                </table>
                {tableDataFiltered.length === 0 && <div className="emptyTableContainer">
                    <FileIcon className='emptyContent' />
                    <DsTypography variant="Semibold_14" className='emptyContent'>{noDataText || 'No Data'}</DsTypography>
                </div>}
            </DsCard>
            <DsTableFooter
                ref={tableFooterRef}
                scrollerRef={horizontalScrollRef}
                bottomOffset={footerOffset}
                tableWidth={tableWidth}
                showHorizontalScroll={showHorizontalScroll} />
        </div>
    )
})

DsTable.displayName = 'DsTable';