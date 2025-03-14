'use client';

import React, { CSSProperties, ReactNode, useCallback, useContext, useEffect, useRef, useState } from 'react';
import styles from './Dialog.module.scss';
import { columnsType, FlexLayout } from '../FlexLayout';

// @ts-ignore
const DialogContext = React.createContext<DialogContextProps>(null);

export interface DialogContextProviderProps {
  /** Context provider */
  children: ReactNode
}

export type DialogContextProps = {
  /** Callback used to show a dialog */
  setDialog: (dialog: ReactNode, isDisableClose?: boolean) => Promise<unknown> | undefined,
  /** Callback used to change the ability to close with click outside or using escape */
  setDisableClose: (isClosingAllowed: boolean) => void,
  /** Callback used to close the dialog, and pass data */
  closeDialog: (data?: any) => void,
};

export type DialogStateProps = {
  /** The dialog that should be shown */
  dialog: ReactNode,
  /** Should be allowed to close dialog with esc or by clicking outside of the dialog? */
  isDisableClose?: boolean,
  /** Custom styles for the dialog wrapper */
  style?: CSSProperties,
  /** How many columns on the grid should it fit (Default 6) */
  columns?: columnsType
};

/** On confirm dialog, this object will be used to transfer data from the dialog to the page that opened the dialog */
export type DialogAnswer = any

export const DialogContextProvider = ({ children }: DialogContextProviderProps) => {
  const modalRef = useRef<HTMLDivElement>(null);
  const [shownDialog, setShownDialog] = useState<DialogStateProps>({
    dialog: null,
    isDisableClose: false,
    style: undefined,
    columns: undefined
  });
  const promise = useRef<(data?: any) => Promise<any>>(null);

  const closeDialog = useCallback((props?: DialogAnswer) => {
    setShownDialog({ dialog: null });
    promise?.current && promise.current(props);
  }, []);

  const closeDialogHandler = useCallback((e: KeyboardEvent) => {
    if (shownDialog.isDisableClose) {
      return;
    }
    // @ts-ignore
    if (e.keyCode === 8 && e!.target!.nodeName !== 'INPUT' && e.target.nodeName !== 'TEXTAREA') {
      e.preventDefault();
    }

    if (e.keyCode === 27) {
      closeDialog();
    }
  }, [shownDialog.isDisableClose, closeDialog]);

  useEffect(() => {
    if (!shownDialog.dialog) return;
    if (shownDialog.isDisableClose) return;
    document.addEventListener('keydown', closeDialogHandler);
    return () => {
      document.removeEventListener('keydown', closeDialogHandler);
    };
  }, [shownDialog, closeDialogHandler]);

  const setDialog = (dialog: ReactNode, isDisableClose?: boolean) => {
    if (shownDialog.dialog === dialog) {
      return;
    }

    setShownDialog({ dialog, style: ({ opacity: 0 }), isDisableClose });

    setTimeout(() => {
      setShownDialog(prevState => ({
        ...prevState,
        style: {
          opacity: 1
        }
      }));
    }, 100);

    return new Promise((res: any) => {
      promise.current = res;
    });
  };

  const setDisableClose = useCallback((bool: boolean) => {
    setShownDialog((prevState) => ({ ...prevState, isDisableClose: bool }));
  }, [setShownDialog]);

  const content = shownDialog.dialog;

  return (
    <DialogContext.Provider value={{ setDialog, setDisableClose, closeDialog }}>
      {children}
      {content ? (
        <FlexLayout isContainer={true} className={styles.dialog}>
          <div className={styles.mask} onClick={shownDialog.isDisableClose ? () => {
          } : closeDialog} />
          <FlexLayout className={styles.modal} ref={modalRef} columns={shownDialog.columns || 6}
            style={shownDialog.style}>
            {content}
          </FlexLayout>
        </FlexLayout>) : null}
    </DialogContext.Provider>

  );
};

export const useDialog = () => {
  return useContext(DialogContext);
};
