'use client';

import React, { FunctionComponent } from "react";
import { useEffect, useState } from "react";
import { useDispatch } from "react-redux";
import { NotificationPanel } from "../dsComponents/NotificationPanel";
import { NOTIFICATION_CONSTS } from "./notification.consts";
import { Notification } from "@/lib/store.types";
import { removeNotification } from "@/lib/slices/notifications.slice"; 
import rootSelector from "@/lib/selectors/root.selector";

import './NotificationGroup.scss'
import { DsButton } from "../dsComponents/dsButton/dsButton";
import { useAppSelector } from "@/lib/hooks";

//Support for custome function in moreInfo 
export const handleChildren = (notification: Notification) => {
    const { children, moreInfo } = notification;
    if (typeof moreInfo === 'function') {
        return (
            <div className="notificationChildren">
                <span key={`notificationGroupCustomeFuncText${Date.now()}`}>{JSON.stringify(children)}</span>
                <DsButton className="cs_moreInfo" type="text" key={`notificationGroupCustomeFuncMoreInfo${Date.now()}`}
                    onClick={moreInfo}>More info</DsButton>
            </div>
        );
    }

    return children;
};

const NotificationGroup: FunctionComponent = () => {
    const dispatch = useDispatch();
    const notifications = useAppSelector(rootSelector.notifications);
    const [notificationList, setNotificationsList] = useState<Notification[]>([]);

    useEffect(() => {
        setNotificationsList(notifications.map<Notification>((notification) => {
            return {
                id: notification.id,
                type: notification.type || NOTIFICATION_CONSTS.TYPE.ERROR,
                children: handleChildren(notification),
                onClose: () => {
                    notification.onClose && notification.onClose();
                    dispatch(removeNotification(notification.id));
                },
                moreInfo: typeof notification.moreInfo === 'function' ? undefined : notification.moreInfo
            }
        }));
    }, [notifications, dispatch])

    return <NotificationPanel className="notificationGroup"
        notifications={notificationList}
        isFooter={true}
    />
};

export default NotificationGroup;