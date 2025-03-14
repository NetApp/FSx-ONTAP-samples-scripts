import { forwardRef, RefObject } from 'react';
import './dsTableFooter.scss';
import { _Classes } from '@/utils/cssHelper.util';

interface DsTableFooterProps {
    bottomOffset: number,
    tableWidth: number,
    scrollerRef: RefObject<HTMLDivElement | null>,
    showHorizontalScroll: boolean
}

const DsTableFooter = forwardRef<HTMLDivElement, DsTableFooterProps>(({
    scrollerRef,
    bottomOffset,
    tableWidth,
    showHorizontalScroll,
}: DsTableFooterProps, ref) => {
    return (
        <div className={_Classes('dsTableFooter', { hidden: !showHorizontalScroll })} ref={ref} style={{ bottom: bottomOffset }}>
            {showHorizontalScroll && <div className="horizontalScroll" ref={scrollerRef}>
                <div className="elementWithTableWidth" style={{ width: `${tableWidth}px` }}></div>
            </div>}
        </div>
    )
})

export default DsTableFooter;

DsTableFooter.displayName = 'DsTableFooter';