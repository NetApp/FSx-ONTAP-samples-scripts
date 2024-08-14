import React, { forwardRef, ReactNode } from 'react';
import styles from './FlexLayout.module.scss';
import { ResolutionType, useThemeProvider } from '../ThemeProvider';
import { _Classes } from '@/utils/cssHelper.util';

type customResolutionColumn = number | false | null;
export type columnsType = number | false;

export interface FlexLayoutProps extends React.HTMLAttributes<HTMLDivElement> {
  /** All the React elements that should be placed on the layout */
  children?: ReactNode;
  /** Custom ClassName for overriding styles */
  className?: string;
  /** Custom styles object */
  style?: React.CSSProperties;
  /** Is it a layout container or item of an internal grid (for example, inside dialogs, cards or right panels */
  isInternalLayout?: boolean;
  /** Is it a container layout? Does it have children? If false, it's a layout item */
  isContainer?: boolean;
  /** How many columns should it take? maximum is 12, enter false for full page width  */
  columns?: columnsType;
  /** Same as column, but for medium resolution, if omitted. columns value will be taken */
  mediumResolutionColumns?: customResolutionColumn;
  /** Same as column, but for small resolution, if omitted. columns value will be taken */
  smallResolutionColumns?: customResolutionColumn;
  /** For Layout container, layout direction, should the elements be aligned in a row or a column */
  flexDirection?: 'row' | 'column';
  /** When isContainer true, should default horizontal padding removed? */
  isRemovePadding?: boolean;
}

const calculateColumnWidth = (
  columns: number | false,
  screenResolution: ResolutionType,
  mediumResolutionColumns: customResolutionColumn,
  smallResolutionColumns: customResolutionColumn,
) => {
  const numberOfColumns =
    screenResolution === 'mediumResolution' && mediumResolutionColumns !== null
      ? mediumResolutionColumns
      : screenResolution === 'smallResolution' &&
        smallResolutionColumns !== null
        ? smallResolutionColumns
        : columns;
  const maxGridColumns = 12;

  return numberOfColumns === false
    ? 'calc(100% + (2 * var(--horizontal-padding)))'
    : `calc((((100% - ${(maxGridColumns - 1) * 24
    }px) / ${maxGridColumns}) * ${numberOfColumns}) + ${(numberOfColumns - 1) * 24
    }px)`;
};

/** Responsive layout based on flexbox */
export const FlexLayout = forwardRef<HTMLDivElement, FlexLayoutProps>(({
  children,
  className = '',
  isInternalLayout = false,
  isContainer = false,
  columns = false,
  flexDirection = 'row',
  mediumResolutionColumns = null,
  smallResolutionColumns = null,
  isRemovePadding = false,
  ...rest
}, ref) => {
  const { screenResolution } = useThemeProvider();

  const _className = _Classes(styles.base,
    className,
    isContainer ? styles['container'] : '',
    flexDirection === 'column' ? styles['column-direction'] : '',
    screenResolution === 'smallResolution' ? styles['small-resolution'] : '',
    !isRemovePadding ? styles['default-padding'] : '',
    columns === false ? styles['off-grid'] : '',
  );

  return (
    <div className={_className} {...rest} ref={ref}>
      {children}
    </div>
  );
});

FlexLayout.displayName = 'FlexLayout';