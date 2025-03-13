import { forwardRef, useEffect, useRef, useState, MouseEvent, SyntheticEvent, useCallback, ReactElement } from 'react';
import './dsPopover.scss';
import { DsBaseComponentProps, OpenCloseStatus, TriggerType, WithChildren, WithMouseEvents } from '../dsTypes';
import { DsBaloon } from '../dsBaloon/dsBaloon';
import { _Classes } from '@/utils/cssHelper.util';
import { useOutsideClick } from '@/app/[locale]/hooks/useOutsideClick';
import useChangePosition, { PositionOffset } from '@/app/[locale]/hooks/usePosition';



export interface DsPopoverProps extends DsBaseComponentProps, WithChildren, WithMouseEvents<OpenCloseStatus, TriggerType | 'manual'> {
    title?: string | ReactElement,
    maxBalloonWidth?: string,
    trigger: TriggerType | 'manual',
    offset?: PositionOffset,
}

export const DsPopover = forwardRef<HTMLDivElement, DsPopoverProps>(({
    children,
    className,
    onClick,
    onMouseOver,
    onMouseLeave,
    onStatusChange,
    isCloseOnClickOutside = true,
    monitorPosition = 'all',
    placement,
    trigger = 'hover',
    status = 'closed',
    style,
    title,
    maxBalloonWidth,
    offset: userOffset = { top: 0, left: 0 },
    ...rest
}: DsPopoverProps, ref) => {
    enum size {
        height = 24,
        marginUpDown = 8,
        marginLeftRight = 16,
        gap = 16,
        iconWidth = 16
    }

    const thisRef = useRef<HTMLDivElement>(null);
    const baloonRef = useRef<HTMLDivElement>(null);
    const isOverBaloon = useRef<boolean>(false);

    const [popoverStatus, setPopoverStatus] = useState<OpenCloseStatus>(status);
    const [position, setPosition] = useState<PositionOffset>();
    const [popoverTrigger, setPopoverTrigger] = useState<TriggerType | 'manual'>(trigger);
    const [show, setShow] = useState<boolean>(false);

    const handleStatusChange = useCallback((status: OpenCloseStatus) => {
        setPopoverStatus(status);

        setTimeout(() => {
            const isShow = status === 'open';
            setShow(isShow);
        }, 200);

        if (onStatusChange) onStatusChange(status);
    }, [onStatusChange])

    useEffect(() => {
        handleStatusChange(status);
    }, [status, handleStatusChange])

    useEffect(() => {
        if (monitorPosition === 'off' && baloonRef.current) {
            const { top = 0, left = 0 } = userOffset;
            baloonRef.current.style.transform = `translate(${-size.marginLeftRight + left}px, ${size.marginUpDown + top}px)`;
        }
    }, [popoverStatus, monitorPosition, size, userOffset])

    useEffect(() => {
        setPopoverTrigger(trigger)
    }, [trigger])

    useChangePosition({ parentRef: thisRef, childRef: baloonRef, offsets: position, monitorPosition });

    const refDiv = useOutsideClick(() => {
        if (isCloseOnClickOutside && popoverStatus === 'open') handleStatusChange('closed')
    });

    useEffect(() => {
        if (placement) {
            setTimeout(() => {
                if (thisRef.current && baloonRef.current) {
                    const { clientHeight: thisHeight, clientWidth: thisWidth } = thisRef.current as HTMLDivElement;
                    const { clientHeight: baloonHeight, clientWidth: baloonWidth } = baloonRef.current as HTMLDivElement;
                    let totalHeight = thisHeight + size.marginUpDown;
                    let totalWidth = size.marginLeftRight * -1;
                    switch (placement) {
                        case 'right': {
                            totalHeight = (thisHeight - baloonHeight) / 2;
                            totalWidth = thisWidth + (size.marginLeftRight / 2);
                            break;
                        }
                        case 'bottomLeft': {
                            totalWidth = (baloonWidth - size.marginLeftRight) * -1;
                            break;
                        }
                        case 'bottomRight': {
                            totalWidth = (thisWidth - size.marginLeftRight);
                            break;
                        }
                        case 'left': {
                            totalHeight = (thisHeight - baloonHeight) / 2;
                            totalWidth = (baloonWidth + size.marginLeftRight) * -1;
                            break;
                        }
                        case 'top': {
                            totalHeight = (baloonHeight + size.marginUpDown) * -1;
                            totalWidth = (thisWidth - baloonWidth) / 2;
                            break;
                        }
                        case 'bottom': {
                            totalWidth = (thisWidth - baloonWidth) / 2;
                        }
                    }

                    setPosition(position => {
                        const { top = 0, left = 0 } = userOffset;
                        totalWidth += left;
                        totalHeight += top;

                        if (!position || position.left !== totalWidth || position.top !== totalHeight) {
                            return {
                                left: totalWidth,
                                top: totalHeight
                            };
                        }

                        return position;
                    })
                }
            }, 0);
        }
    }, [monitorPosition, placement, size, userOffset]);

    const handleClick = (event: SyntheticEvent) => {
        if (onClick) onClick(event);

        if (popoverTrigger === 'click') {
            handleStatusChange(popoverStatus === 'closed' ? 'open' : 'closed')
        }
    }

    const handleMouseOver = (event: MouseEvent) => {
        if (popoverTrigger === 'hover') handleStatusChange('open');
        if (onMouseOver) onMouseOver(event);
    }

    const handleMouseLeave = (event: MouseEvent) => {
        setTimeout(() => {
            if (!isOverBaloon.current) {
                if (popoverTrigger === 'hover') handleStatusChange('closed');
                if (onMouseLeave) onMouseLeave(event);
            }
        }, 200);
    }

    return (
        <div className={_Classes('dsPopover', className)} style={style} ref={ref}
            onClick={event => handleClick(event)}
            onMouseOver={event => handleMouseOver(event)}
            onMouseLeave={event => handleMouseLeave(event)}
            {...rest}>
            <div className="refDiv" ref={refDiv}>
                <div className="childrenContainer" ref={thisRef}>
                    {children}
                    {popoverStatus === 'open' && title && <DsBaloon
                        onClick={event => event.stopPropagation()}
                        ref={baloonRef}
                        maxWidth={maxBalloonWidth || '320px'}
                        className={_Classes('popoverBaloon', popoverStatus, { show })}
                        onMouseOver={() => isOverBaloon.current = true}
                        onMouseLeave={() => isOverBaloon.current = false}>{title}</DsBaloon>}
                </div>
            </div>
        </div>
    )
})

DsPopover.displayName = "DsPopover"