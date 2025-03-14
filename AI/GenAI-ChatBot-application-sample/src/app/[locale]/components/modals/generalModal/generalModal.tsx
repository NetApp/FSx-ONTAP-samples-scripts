import React, { ReactElement } from 'react';
import {
    DialogContent,
    DialogFooter,
    DialogHeader,
    DialogLayout
} from '../../dsComponents/Dialog/DialogLayout';
import { DsButton, DsButtonProps } from '../../dsComponents/dsButton/dsButton';

interface GeneralModalProps {
    title: string,
    children: ReactElement,
    buttons: DsButtonProps[],
    className?: string,
    error?: string
}

const GeneralModal = ({ title, children, buttons, className, error }: GeneralModalProps) => {
    return (
        <DialogLayout className={className}>
            <DialogHeader>{title}</DialogHeader>
            <DialogContent>{children}</DialogContent>
            <DialogFooter error={error}>
                {buttons.map((button, index) => {
                    const { variant, onClick = () => { }, isThin, children, ...props } = button;

                    return (
                        <DsButton key={index}
                            variant={variant}
                            isThin={isThin}
                            onClick={event => onClick(event)}
                            {...props}  >
                            {children}
                        </DsButton>
                    )
                })}
            </DialogFooter>
        </DialogLayout>
    )
}

export default GeneralModal;