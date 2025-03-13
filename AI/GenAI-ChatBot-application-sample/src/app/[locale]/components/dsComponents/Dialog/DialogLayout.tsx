import React, { ReactNode } from 'react';

import styles from './DialogLayout.module.scss';
import { FieldErrorWarning } from '../FieldErrorWarning';
import { DsTooltipInfoProps } from '../dsTooltipInfo/dsTooltipInfo';
import { DsTypography } from '../dsTypography/dsTypography';
import { _Classes } from '@/utils/cssHelper.util';

export interface DialogFooterProps {
  /** Dialog Footer buttons */
  children: ReactNode,
  /** Dialog error message */
  error?: string | undefined,
  /** Dialog warning message */
  warning?: string | undefined,
  /** Dialog info message */
  infoMessage?: string | undefined,
  /** Error or warning tooltip props */
  errorOrWarningTooltipProps?: DsTooltipInfoProps,
}

export const DialogFooter = ({ error, warning, infoMessage , children, errorOrWarningTooltipProps }: DialogFooterProps) => {
  return <div className={styles['dialog-footer']}>
    {(error||warning||infoMessage) && <FieldErrorWarning infoMessage={infoMessage} error={error} warning={warning} tooltipProps={errorOrWarningTooltipProps} />}
    <div className={styles['buttons-container']}>
      {children}
    </div>
  </div>;
};


export interface DialogContentProps {
  /** Dialog Header text */
  children: ReactNode,
}

export const DialogContent = ({ children }: DialogContentProps) => {
  return <div className={styles['dialog-content']}>{children}</div>;
};


export interface DialogHeaderProps {
  /** Dialog Header text */
  children: ReactNode,
}

export const DialogHeader = ({ children }: DialogHeaderProps) => {
  return <DsTypography style={{padding: '20px 40px'}} variant={'Regular_20'} color={'var(--text-title)'}
                     className={styles.header}>{children}</DsTypography>;
};


export interface DialogLayoutProps {
  /** custom className */
  className?: string,
  /** dialog content */
  children: ReactNode,
}

/** Default layout of a modal  */
export const DialogLayout = ({ className = '', children }: DialogLayoutProps) => {
  return <div className={_Classes(styles['default-dialog-layout'], className)}>
    {children}
  </div>;
};