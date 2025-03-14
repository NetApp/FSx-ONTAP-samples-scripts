import React, { ReactElement, ReactNode, SyntheticEvent, forwardRef, useRef, useState } from "react";
import './dsTooltipInfo.scss';
import { DsComponentProps, OpenCloseStatus, TriggerType, WithMouseEvents } from "../dsTypes";
import { DsTypography } from "../dsTypography/dsTypography";
import { DsBaloon } from "../dsBaloon/dsBaloon";
import TooltipIcon from '@/app/[locale]/svgs/info.svg';
import { useOutsideClick } from "@/app/[locale]/hooks/useOutsideClick";
import useChangePosition, { PositionOffset } from "@/app/[locale]/hooks/usePosition";
import useRunUntil from "@/app/[locale]/hooks/useRunUntil";

export type TooltipStatus = 'opened' | 'closed';

export interface DsTooltipInfoProps extends Omit<DsComponentProps, 'message' | 'isLoading' | 'variant'>, WithMouseEvents<OpenCloseStatus, TriggerType | 'manual'> {
    children?: ReactNode,
    icon?: ReactElement,
    trigger?: TriggerType,
    defaultStatus?: TooltipStatus,
    placement?: 'bottomRight' | 'right' | 'bottomLeft' | 'left' | 'top',
    maxBalloonWidth?: string
};

export const DsTooltipInfo = forwardRef<HTMLDivElement, DsTooltipInfoProps>(({
    children,
    className = '',
    icon,
    isDisabled,
    onClick,
    style = {},
    title,
    typographyVariant = 'Regular_14',
    trigger = 'click',
    defaultStatus = 'closed',
    placement = 'bottomRight',
    maxBalloonWidth = '320px',
    monitorPosition = 'all'
}: DsTooltipInfoProps, ref) => {
    const thisRef = useRef<HTMLDivElement>(null);
    const ballonRef = useRef<HTMLDivElement>(null);
    const iconContainerRef = useRef<HTMLDivElement>(null);
    const [status, setStatus] = useState<TooltipStatus>(defaultStatus);
    const [position, setPosition] = useState<PositionOffset>();

    useChangePosition({ parentRef: thisRef, childRef: ballonRef, offsets: position, monitorPosition });

    const refDiv = useOutsideClick(() => {
        setStatus('closed');
    });

    useRunUntil(() => {
        setTimeout(() => {
            if (thisRef.current && ballonRef.current && iconContainerRef.current) {
                enum size {
                    height = 24,
                    marginUpDown = 8,
                    marginLeftRight = 16,
                    gap = 16,
                    iconWidth = 16
                }

                const { clientHeight: thisHeight, clientWidth: thisWidth } = thisRef.current as HTMLDivElement;
                const { clientHeight: baloonHeight, clientWidth: baloonWidth } = ballonRef.current as HTMLDivElement;
                const { clientHeight: iconContainerHeight } = iconContainerRef.current;
                let totalHeight = thisHeight + size.marginUpDown;
                let totalWidth = size.marginLeftRight * -1;
                switch (placement) {
                    case 'right': {
                        totalHeight = (baloonHeight - iconContainerHeight) / -2;
                        totalWidth = thisWidth + size.marginLeftRight;
                        break;
                    }
                    case 'bottomLeft': {
                        totalWidth = (baloonWidth - (size.marginLeftRight * 2)) * -1;
                        break;
                    }
                    case 'left': {
                        totalHeight = (baloonHeight - iconContainerHeight) / -2;
                        totalWidth = (baloonWidth + size.marginLeftRight) * -1;
                        break;
                    }
                    case 'top': {
                        totalHeight = (baloonHeight + size.marginUpDown) * -1;
                    }
                }

                setPosition({
                    top: totalHeight,
                    left: totalWidth
                })
            }
        }, 0);
    }, !!position);

    const handleClick = (event: SyntheticEvent) => {
        onClick && onClick(event);
        trigger === 'click' && setStatus(status === 'closed' ? 'opened' : 'closed');
    }

    const handleMouseOver = (event: SyntheticEvent) => {
        trigger === 'hover' && setStatus('opened');
    }

    const handleMouseLeave = (event: SyntheticEvent) => {
        trigger === 'hover' && setStatus('closed');
    }

    return (
        <div className={`dsTooltipInfo ${className} ${isDisabled ? 'isDisabled' : ''} ${onClick || children ? 'clickable' : ''} ${status}`}
            ref={ref}
            onClick={event => handleClick(event)}
            onMouseOver={event => handleMouseOver(event)}
            onMouseLeave={event => handleMouseLeave(event)}
            style={style}>
            <div className="tooltipContainer" ref={thisRef}>
                <div className="refDiv" ref={refDiv}>
                    <div className="tooltipInfoTitleContainer">
                        <DsTypography variant={typographyVariant} className="iconTitleContainer" ref={iconContainerRef}>
                            {icon ? icon : <TooltipIcon className='defaultTooltipIcon' />}
                            {title && <span className="tooltipInfoTitle">{title}</span>}
                        </DsTypography>
                    </div>
                    {status === 'opened' && !isDisabled && <DsBaloon ref={ballonRef} maxWidth={maxBalloonWidth} className="tooltipInfoBaloon">{children}</DsBaloon>}
                </div>
            </div>
        </div>
    )
})

DsTooltipInfo.displayName = 'DsTooltipInfo'