import { CSSProperties, forwardRef, ReactNode } from "react";
import './dsCell.scss';
import { DsBaseComponentProps, TypographyVariant } from "../../dsTypes";
import { ColumnWidthType } from "./dsHeaderCell";
import { _Classes } from "@/utils/cssHelper.util";

export type DsCellVariant = 'Data' | 'Action';
export type FreezeDirection = 'Left' | 'Right';
export interface FreezColumn {
    direction: FreezeDirection,
    offset: number,
    isLast: boolean
}

export interface DsCellBase extends DsBaseComponentProps {
    isDisabled?: boolean,
    value?: string,
    formatCell?: (value?: string) => ReactNode,
    typographyVariant?: TypographyVariant
}

export interface DsCellProps extends DsCellBase {
    colspan?: number,
    rowSpan?: number,
}

interface DsInnerCellProps extends DsCellProps {
    width?: ColumnWidthType,
    isHidden?: boolean,
    //Action columns will not be sortable or resisable
    variant?: DsCellVariant,
    freeze?: FreezColumn
}

export const DsCell = forwardRef<HTMLTableCellElement, DsInnerCellProps>(({
    className,
    colspan = 1,
    rowSpan = 1,
    isDisabled,
    onClick = () => { },
    style = {},
    typographyVariant = 'Regular_14',
    width,
    value,
    isHidden,
    formatCell,
    variant = 'Data',
    freeze
}: DsInnerCellProps, ref) => {
    const { value: colWidth, unit } = width || {};

    const cellStyle = (isInnerCellContainer: boolean = false): CSSProperties => {
        if (isHidden) return { width: '0px', padding: '0', display: 'none' };

        const cellWidth = (colWidth: number): number | string => {
            const width = colWidth - (isInnerCellContainer ? 2 : 0);
            return isInnerCellContainer && colspan > 1 ? 'unset' : width;
        }

        return { width: colWidth !== undefined ? `${cellWidth(colWidth)}${unit}` : variant !== 'Action' ? 'unset' : 'fit-content' };
    }

    return (
        <td className={_Classes('dsCell', className, typographyVariant, {
            noContent: !value && !formatCell,
            isDisabled,
            freezed: !!freeze,
            isFreezLastLeft: freeze?.direction === 'Left' && freeze?.isLast,
            isFreezLastRight: variant !== 'Action' && freeze?.direction === 'Right' && freeze?.isLast,
        })}
            ref={ref}
            colSpan={colspan}
            rowSpan={rowSpan}
            style={{
                ...style,
                ...cellStyle(),
                left: freeze?.direction === 'Left' ? `${freeze.offset}px` : '',
                right: freeze?.direction === 'Right' ? `${freeze.offset}px` : ''
            }}
            onClick={onClick}>
            <div className={_Classes('cellContainer', variant)} style={cellStyle(true)}>
                <div className="cellContent" title={value}>
                    {formatCell ? formatCell(value) : value}
                </div>
            </div>
        </td>
    )
})

DsCell.displayName = 'DsCell';