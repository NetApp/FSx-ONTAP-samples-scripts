import { RefObject, useEffect } from 'react';

export interface PositionOffset { top?: number, left?: number }

/**
 * @param parentRef Reference to the parent of which the position is relative to
 * @param childRef Reference to the child that should maintain the position relative to the parent
 * @param offsets Optional offset to the x and y axis
 * @param skip 
 */
const usePosition = (parentRef: RefObject<HTMLElement>, childRef: RefObject<HTMLElement>, offsets?: PositionOffset, skip: boolean = false) => {
    const { top = 0, left = 0 } = offsets || {};

    useEffect(() => {
        const timer = setInterval(() => {
            if (childRef.current && !skip) {

                const { top: parentTop = 0, left: parentLeft = 0 } = parentRef.current?.getBoundingClientRect() || {};
                childRef.current.style.top = `${parentTop + top}px`;
                childRef.current.style.left = `${parentLeft + left}px`;
            }
        }, 10)

        return () => clearInterval(timer);
    }, [parentRef, childRef, top, left, skip])
};

export default usePosition;