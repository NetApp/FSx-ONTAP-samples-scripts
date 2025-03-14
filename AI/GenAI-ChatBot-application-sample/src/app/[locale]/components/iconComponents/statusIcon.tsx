/* eslint-disable react/display-name */
import React, { FunctionComponent } from 'react'
import './statusIcon.scss';
import StatusDoneIcon from '@/app/[locale]/svgs/status/statusDone.svg';
import StatusFailedIcon from '@/app/[locale]/svgs/status/statusFailed.svg';
import StatusInProgressIcon from '@/app/[locale]/svgs/status/statusInProgress.svg';
import WarningIcon from '@/app/[locale]/svgs/status/statusWarning.svg';
import NoStatusIcon from "@/app/[locale]/svgs/close.svg";
import { EmbeddingStatus, ProgressStatus } from '@/lib/api/api.types';
import { DsSpinner } from '../dsComponents/dsSpinner/dsSpinner';

interface StatusIconProps {
    status: ProgressStatus | EmbeddingStatus | 'None' | 'Warning',
    onlyStatic?: boolean,
    className?: string,
    width?: number,
    height?: number
}

const StatusIcon: FunctionComponent<StatusIconProps> = ({ status, onlyStatic, className, height, width }) => {
    let StatusIcon = () => onlyStatic ? <StatusInProgressIcon className={`statusIcon ${className}`} width={width} heigth={height} /> : <DsSpinner className={`statusIcon ${className}`} />;
    switch (status) {
        case 'EMBEDDED':
        case 'DONE': {
            StatusIcon = () => <StatusDoneIcon className={`statusIcon ${className}`} width={width} heigth={height} />;
            break;
        }
        case 'FAILED': {
            StatusIcon = () => <StatusFailedIcon className={`statusIcon errorIcon ${className}`} width={width} heigth={height} />;
            break;
        }
        case 'None': {
            StatusIcon = () => <NoStatusIcon className={`statusIcon noStatusIcon ${className}`} width={width} heigth={height} />;
            break;
        }
        case 'Warning': {
            StatusIcon = () => <WarningIcon className={`statusIcon warningStatusIcon ${className}`} width={width} heigth={height} />;
            break;
        }
    }

    return (
        <StatusIcon />
    )
}

export default StatusIcon;