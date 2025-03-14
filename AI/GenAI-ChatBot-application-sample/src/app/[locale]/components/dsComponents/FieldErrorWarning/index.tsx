import React, { ReactNode, useLayoutEffect, useRef, useState } from 'react';
import styles from './FieldErrorWarning.module.scss';
import ErrorIcon from '@/app/[locale]/svgs/error.svg';
import WarningIcon from '@/app/[locale]/svgs/warning.svg';
import InfoIcon from '@/app/[locale]/svgs/info.svg';
import { DsTooltipInfoProps } from '../dsTooltipInfo/dsTooltipInfo';
import { _Classes } from '@/utils/cssHelper.util';
import { DsTypography } from '../dsTypography/dsTypography';

interface FieldErrorWarningProps {
  /** error text */
  error?: string;
  /** warning text */
  warning?: string;
  /** info text message */
  infoMessage?: string;
  /** custom classname */
  className?: string;
  /** In case the error or warning are too long, there will be a tooltip, this prop is the tooltip options */
  tooltipProps?: DsTooltipInfoProps;
  /** Widget to present in the right side of the error */
  rightWidget?: ReactNode;
  /** When there is an error, should the 'Error:' test be hidden? */
  isErrorPrefixHidden?: boolean;
  /** custom icon to show, instead of default error or warning icon */
  customErrorWarningIcon?: ReactNode;
}

export const FieldErrorWarning = ({
  error,
  warning,
  infoMessage,
  rightWidget,
  tooltipProps,
  isErrorPrefixHidden,
  customErrorWarningIcon,
  className
}: FieldErrorWarningProps) => {
  const shownText = error || warning || infoMessage;

  const errorRef = useRef<HTMLDivElement>(null);

  const [isEllipsis, setIsEllipsis] = useState(false);
  useLayoutEffect(() => {
    if ((error || warning) && errorRef?.current) {
      setIsEllipsis(errorRef?.current?.offsetWidth < errorRef?.current?.scrollWidth);
    }
  }, [error, warning]);

  return (shownText || rightWidget) ? (
    <div className={_Classes(styles.base, className)}>
      {error ? (
        <>
          {customErrorWarningIcon || <ErrorIcon className={styles['icon-error']} />}
          {!isErrorPrefixHidden && <DsTypography Component={'span'} variant={'Semibold_13'}>
            Error:
          </DsTypography>}
        </>
      ) : warning ? (
        <>
          {customErrorWarningIcon || <WarningIcon className={styles['icon-warning']} />}
          <DsTypography Component={'span'} variant={'Semibold_13'}>
            Warning:
          </DsTypography>
        </>
      ) : infoMessage ? (customErrorWarningIcon || <InfoIcon className={styles['icon-info']} />) : null}
      <DsTypography isEllipsis={true} Component={'span'} variant={'Regular_13'} ref={errorRef}>
        {shownText}
      </DsTypography>
      {isEllipsis &&
        <DsTypography className={styles.tooltip} variant={tooltipProps?.typographyVariant}>{shownText}</DsTypography>}
      {rightWidget && <div className={styles['right-widget']}>{rightWidget}</div>}
    </div>
  ) : null;
};
