import { RefObject, useEffect } from 'react';
import { MonitorPosition } from '../components/dsComponents/dsTypes';

export interface PositionOffset { top?: number, left?: number }

interface useChangePositionProps {
    parentRef: RefObject<HTMLElement | null>,
    childRef: RefObject<HTMLElement | null>,
    offsets?: PositionOffset,
    monitorPosition: MonitorPosition,
    userOffest?: PositionOffset
}

/**
 * @param parentRef Reference to the parent of which the position is relative to
 * @param childRef Reference to the child that should maintain the position relative to the parent
 * @param offsets Optional offset to the x and y axis
 * @param skip 
 */
const useChangePosition = ({ parentRef, childRef, offsets = {}, monitorPosition = 'all', userOffest = {} }: useChangePositionProps) => {
    const { top = 0, left = 0 } = offsets;
    const { top: userOffesetTop = 0, left: userOffsetLeft = 0 } = userOffest;

    useEffect(() => {
        let animationFrameId: number;

        const updatePosition = () => {
            if (childRef.current && parentRef.current) {
                const { top: parentTop, left: parentLeft } = parentRef.current.getBoundingClientRect();

                childRef.current.style.top = `${(monitorPosition === 'left' ? 0 : parentTop) + top + userOffesetTop}px`;
                childRef.current.style.left = `${(monitorPosition === 'top' ? 0 : parentLeft) + left + userOffsetLeft}px`;
            }

            animationFrameId = requestAnimationFrame(updatePosition);
        };

        if (monitorPosition !== 'off') {
            animationFrameId = requestAnimationFrame(updatePosition);
        }

        return () => cancelAnimationFrame(animationFrameId);
    }, [parentRef, childRef, top, left, monitorPosition, userOffesetTop, userOffsetLeft]);
};

export default useChangePosition;