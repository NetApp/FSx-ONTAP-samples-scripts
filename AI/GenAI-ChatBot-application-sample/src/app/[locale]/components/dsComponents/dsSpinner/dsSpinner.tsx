import React from 'react';
import LoaderIcon from '@/app/[locale]/svgs/loader.svg';
import styles from './dsSpinner.module.scss';
import { _Classes } from '@/utils/cssHelper.util';

export interface DsSpinnerProps
  extends Omit<React.ComponentPropsWithoutRef<'svg'>, 'children'> {
  /** Large size of a loader */
  isLarge?: boolean;
}

export const DsSpinner: React.FC<DsSpinnerProps> = ({
  isLarge,
  className,
  ...props
}) => (
  <LoaderIcon
    className={_Classes(styles.base, className, isLarge ? styles.large : '')}
    {...props}
  />
);
