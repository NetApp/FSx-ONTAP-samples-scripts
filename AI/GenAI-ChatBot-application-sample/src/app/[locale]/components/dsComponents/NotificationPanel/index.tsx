import React, { useEffect, useMemo, useState } from 'react';
import {
  Notification,
  NotificationProps,
  NotificationType,
} from '../Notification';
import styles from './NotificationPanel.module.scss';
import { _Classes } from '@/utils/cssHelper.util';
import { DsButton } from '../dsButton/dsButton';

const values = {
  error: 5,
  urgent: 4,
  warning: 3,
  info: 2,
  success: 1,
};

const compare = (type1: NotificationType, type2: NotificationType) => {
  const val1 = values[type1] || 0;
  const val2 = values[type2] || 0;

  return val2 > val1 ? type2 : type1;
};

interface GroupedNotificationsProps {
  /** Array of notifications (with ID)*/
  notifications: NotificationProps[];
  /** Array of notifications (with ID)*/
  isPanelOpen: boolean;
  /** Array of notifications (with ID)*/
  setIsPanelOpen: React.Dispatch<React.SetStateAction<boolean>>;
  /** Array of notifications (with ID)*/
  groupedNotificationClassName: string;
}

const GroupedNotifications = ({
  notifications,
  isPanelOpen,
  setIsPanelOpen,
  groupedNotificationClassName,
}: GroupedNotificationsProps) => {
  const maxType = useCalculateGroupedNotificationType(notifications);

  return (
    <div
      // duration={400}
      // easing={'var(--cubic_bezier)'}
      // height={isPanelOpen ? 'auto' : 56}
      className={_Classes(
        styles['grouped-container'],
        groupedNotificationClassName
      )}
    >
      {!isPanelOpen && (
        <Notification
          type={maxType}
          variant={'primary'}
          className={styles['inactive-grouped-container']}
        >
          <div>
            You have {notifications.length} new notifications.
            <DsButton
              type={'text'}
              onClick={() => setIsPanelOpen(true)}
              className={styles['show-more']}
            >
              See Details
            </DsButton>
          </div>
        </Notification>
      )}
      {isPanelOpen && (
        <div className={styles['active-grouped-container']}>
          {notifications.map((notification, index) => {
            return (
              <Notification
                key={index}
                {...notification}
                className={_Classes(
                  notification.className,
                  styles['grouped-notification']
                )}
                variant={'secondary'}
              />
            );
          })}
        </div>
      )}
    </div>
  );
};

const useCalculateGroupedNotificationType = (
  notifications: NotificationProps[]
) =>
  useMemo(() => {
    let maxType = 'success' as NotificationType;
    notifications.forEach(({ type }) => {
      maxType = compare(maxType, type);
    });

    return maxType;
  }, [notifications]);

export interface NotificationPanelProps {
  /** Array of notifications (with ID)*/
  notifications: NotificationProps[];
  /** Is there a footer on the current screen? the notification panel will be above it*/
  isFooter?: boolean;
  /** custom classname*/
  className?: string;
  /** custom classname for the grouped notifications container */
  groupedNotificationClassName?: string;
}

const useIsGrouped = (
  notificationsCount: number
): [boolean, boolean, React.Dispatch<React.SetStateAction<boolean>>] => {
  const [isPanelOpen, setIsPanelOpen] = useState<boolean>(false);
  const [isGroupedNotification, setIsGroupedNotification] =
    useState<boolean>(false);
  useEffect(() => {
    if (notificationsCount > 1) {
      setIsGroupedNotification(true);
    }
    if (notificationsCount === 0) {
      setIsGroupedNotification(false);
      setIsPanelOpen(false);
    }
  }, [notificationsCount]);
  return [isGroupedNotification, isPanelOpen, setIsPanelOpen];
};

/** Notification Panel is meant to show the Notifications in the bottom of the screen, it includes the logic for grouped notifications*/
export const NotificationPanel = ({
  notifications,
  isFooter = false,
  className,
  groupedNotificationClassName = '',
}: NotificationPanelProps) => {
  const [isGroupedNotification, isPanelOpen, setIsPanelOpen] = useIsGrouped(
    notifications.length
  );

  if (notifications.length === 0) {
    return null;
  }
  return (
    <div
      className={_Classes(
        styles.base, isFooter ? styles['with-footer'] : '',
        className
      )}
    >
      {!isGroupedNotification ? (
        <Notification {...notifications[0]} />
      ) : (
        <GroupedNotifications
          notifications={notifications}
          isPanelOpen={isPanelOpen}
          setIsPanelOpen={setIsPanelOpen}
          groupedNotificationClassName={groupedNotificationClassName}
        />
      )}
    </div>
  );
};
