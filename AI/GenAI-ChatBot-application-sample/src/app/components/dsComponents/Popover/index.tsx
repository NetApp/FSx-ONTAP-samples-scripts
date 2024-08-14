import React, { ReactNode } from 'react';
import { usePopperTooltip } from 'react-popper-tooltip';
import styles from './Popover.module.scss';
import ReactDOM from 'react-dom';
import { Config } from 'react-popper-tooltip/dist/types';
import { _Classes } from '@/utils/cssHelper.util';

export interface PopoverProps extends Config {
  /** variant of trigger */
  trigger?: 'click' | 'hover' | null;
  /** custom classname for the trigger element */
  containerClass?: string;
  /** custom classname for the tooltip element */
  popoverClass?: string;
  /** append tooltip to body */
  isAppendedToBody?: boolean;
  /** Tooltip element */
  children: ReactNode;
  /** The element which will trigger the tooltip */
  container: ReactNode;
  className?: string
}

export const getOffsets = (placement:Config['placement']):[number,number] =>{
switch (placement){
  case 'bottom-start':
  case 'top-start':
    return [-16,8]
  case 'top-end':
  case 'bottom-end':
    return [16,8]
  case 'left':
  case 'right':
  case 'bottom':
  case 'top':
  default:
    return [0, 8]
}
}

/** basic popover  */
export const Popover = ({
  container,
  containerClass,
  trigger = 'click',
  popoverClass,
  children,
  isAppendedToBody = false,
  placement = 'bottom-start',
  className = '',
  ...rest
}: PopoverProps) => {
  const {
    getArrowProps,
    getTooltipProps,
    setTooltipRef,
    setTriggerRef,
    visible,
  } = usePopperTooltip({ trigger, placement, offset:getOffsets(placement), ...rest });

  const tooltipWrapper = (
    <div
      ref={setTooltipRef}
      {...getTooltipProps({ className: _Classes(styles.base, popoverClass) })}
    >
      {children}
      <div
        {...getArrowProps()}
      />
    </div>
  );

  return (
    <>
      <span
        className={`${className} ${_Classes(styles['tooltip-wrapper'], containerClass)}`}
        ref={setTriggerRef}>
        {container}
      </span>
      {visible &&
        (isAppendedToBody
          ? ReactDOM.createPortal(tooltipWrapper, document.body)
          : tooltipWrapper)}
    </>
  );
};
