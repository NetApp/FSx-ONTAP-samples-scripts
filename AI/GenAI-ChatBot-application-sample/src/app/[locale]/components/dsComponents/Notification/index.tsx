import React, { ReactNode, SyntheticEvent, useState } from 'react';
import Error from '@/app/[locale]/svgs/error.svg';
import Warning from '@/app/[locale]/svgs/warning.svg';
import Success from '@/app/[locale]/svgs/success.svg';
import Close from '@/app/[locale]/svgs/close.svg';
import Info from '@/app/[locale]/svgs/info.svg';
import styles from './Notification.module.scss';
import { _Classes } from '@/utils/cssHelper.util';
import { DsButton } from '../dsButton/dsButton';
import { DsTypography } from '../dsTypography/dsTypography';

export interface HandleMoreInfoWhenLongTextProps {
  /** The notification text */
  text: ReactNode,
  /** if the notification text is a react Node, what will be the number of characters of the notification text */
  textLength?: number,
  /** In case the text is long, and there is a show more, which title should be presented */
  title: string
}

/** Handle situation when the text is too long, will convert the notification to 'show more' with a title */
export const handleMoreInfoWhenLongText = ({ text, textLength, title }: HandleMoreInfoWhenLongTextProps) => {
  if (!text) {
    return null;
  }
  const finalTextLength = typeof text === 'string' ? text?.length : (textLength || 0);
  if (finalTextLength > 300) {
    return {
      moreInfo: text,
      children: title
    };
  }
  return {
    children: text
  };
};

export const iconTypeMapper = {
  error: { icon: Error },
  warning: { icon: Warning },
  success: { icon: Success },
  info: { icon: Info },
  urgent: { icon: Warning }
};
export type NotificationType =
  | 'success'
  | 'error'
  | 'warning'
  | 'info'
  | 'urgent';
export type NotificationVariant = 'primary' | 'secondary';

export interface NotificationProps extends React.HTMLAttributes<HTMLDivElement> {
  /** Notification Type */
  type: NotificationType;
  /** Notification variant */
  variant?: NotificationVariant;
  /** Children */
  children: ReactNode;
  /** In case of expandable Notification, It's the expanded section */
  moreInfo?: ReactNode;
  /** If this Notification closeable, It's the callback */
  onClose?: (event: SyntheticEvent) => void;
  /** Custom classname */
  className?: string;
  /** Custom classname for moreInfo part */
  moreInfoClassName?: string;
  /** moreInfoWrapper classname */
  moreInfoWrapperClassName?: string;
}

/** Notification */
export const Notification = ({
  type = 'success',
  variant = 'primary',
  children,
  moreInfoClassName = '',
  moreInfo,
  onClose,
  className,
  moreInfoWrapperClassName = '',
  ...rest
}: NotificationProps) => {
  const [showMore, setShowMore] = useState(false);
  const Icon = iconTypeMapper[type].icon;
  const hasMore = !!moreInfo;
  const closeable = !!onClose;

  return (
    <div
      className={_Classes(
        styles['base'],
        styles[type],
        styles[variant]
      )}
      {...rest}
    >
      <div className={styles['main']}>
        <Icon className={styles['type-icon']} />
        <DsTypography variant={'Semibold_14'} className={styles['content']}>
          {children}
          {hasMore && (
            <DsButton
              variant='primary'
              type='text'
              onClick={() => setShowMore(!showMore)}
              className={_Classes(styles['show-more'])}
            >
              {showMore ? 'Show less' : 'Show more'}
            </DsButton>
          )}
        </DsTypography>
        {closeable && (
          <DsButton
            variant='primary'
            className={styles['delete-button']}
            onClick={event => onClose(event)}
            type='icon'
            icon={<Close width={24} />}
          />
        )}
      </div>
      <div className={_Classes(
        styles['more-wrapper'],
        showMore ? styles.expanded : '',
        moreInfoWrapperClassName)}>
        <DsTypography variant={'Regular_14'} className={_Classes(styles['more'], moreInfoClassName)}>
          {moreInfo}
        </DsTypography>
      </div>
    </div>
  );
};
