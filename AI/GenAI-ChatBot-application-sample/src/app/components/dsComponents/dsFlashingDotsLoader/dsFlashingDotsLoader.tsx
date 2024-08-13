import React from 'react';
import styles from './dsFlashingDotsLoader.module.scss';
import { _Classes } from '@/utils/cssHelper.util';

export interface DsFlashingDotsLoaderProps {
  className?: string;
  isGrey?: boolean;
}

export const DsFlashingDotsLoader = ({
  className,
  isGrey = false,
}: DsFlashingDotsLoaderProps) => {
  return (
    <div
      className={_Classes(styles['base'], className, isGrey ? styles.grey : '')}
    >
      <div className={styles['dot-flashing']} />
      <div className={styles['dot-flashing']} />
      <div className={styles['dot-flashing']} />
    </div>
  );
};
