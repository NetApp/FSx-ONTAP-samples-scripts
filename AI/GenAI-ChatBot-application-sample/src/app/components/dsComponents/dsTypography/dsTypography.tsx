import React, { forwardRef, ReactNode } from 'react';
import styles from './dsTypography.module.scss';
import { _Classes } from '@/utils/cssHelper.util';
import { TypographyVariant } from '../dsTypes';

export interface DsTypographyProps extends React.HTMLAttributes<HTMLDivElement> {
  /** Title or Body Text */
  children: ReactNode;
  /** Center */
  isCenter?: boolean;
  /** Ellipses */
  isEllipsis?: boolean;
  /** NoWrap */
  isNowrap?: boolean;
  /** ClassName */
  className?: string;
  /** Variant */
  variant?: TypographyVariant;
  /** Custom Element */
  Component?: React.ElementType;
  /** custom styles object */
  style?: React.CSSProperties;
  /** Color of the text, must be vaild css color definition*/
  color?: string;
  isDisabled?: boolean
}

/** Typography */
export const DsTypography = forwardRef((props: DsTypographyProps, ref) => {
  const {
    children,
    isCenter,
    isEllipsis,
    isNowrap,
    className = '',
    variant = 'Regular_14',
    Component = 'div',
    color = 'var(--text-primary)',
    isDisabled,
    ...rest
  } = props;

  const _className = _Classes(
    styles.base,
    className,
    styles[variant],
    styles[isDisabled ? 'typographyPropsIsDisabled' : '']
  );

  return (
    <Component className={`${_className}`} {...rest}>
      {children}
    </Component>
  );
});

DsTypography.displayName = 'DsTypography';
