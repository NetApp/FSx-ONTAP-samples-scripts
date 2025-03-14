import React, { useEffect, useMemo } from "react";
import styles from './deleteChatModal.module.scss';
import { useDialog } from "../../dsComponents/Dialog";
import GeneralModal from "../generalModal/generalModal";
import { DsButtonProps } from "../../dsComponents/dsButton/dsButton";
import { DsTypography } from "../../dsComponents/dsTypography/dsTypography";
import { useDeleteChatMutation } from "@/lib/api/chatApi.slice";

interface ConfirmModalProps {
    chatIds: string[],
    chatMessage?: string,
    variant: 'All' | 'single',
    knowledgeBaseId: string
}

const DeleteChatModal = ({ chatIds, chatMessage, variant, knowledgeBaseId }: ConfirmModalProps) => {
    const i18DefaultPath = "aiChat.chatbot.history.menu.messages";
    const { closeDialog } = useDialog();

    const [deleteChat, { isLoading, isSuccess }] = useDeleteChatMutation();
    // const [getMessages] = useLazyGetMessagesQuery();


    useEffect(() => {
        if (isSuccess) {
            // getMessages({ accountId: accountId!, deploymentId, knowledgeBaseId });
            closeDialog();
        }
    }, [isSuccess, closeDialog, knowledgeBaseId]);

    const buttons: DsButtonProps[] = useMemo(() => {
        return [
            {
                children: 'Delete',
                isThin: true,
                isLoading,
                variant: 'primary',
                onClick: () => {
                    deleteChat({
                        chatParams: {
                            knowledgeBaseId
                        },
                        chatId: chatIds[0]
                    })
                }
            },
            {
                children: 'Cancel',
                isThin: true,
                variant: 'secondary',
                onClick: () => closeDialog(false)
            }
        ]
    }, [chatIds, isLoading, knowledgeBaseId, deleteChat, closeDialog]);

    return (
        <GeneralModal title={variant === 'All' ? 'Delete chat history' : 'Delete chat'} buttons={buttons} className={styles.deleteChatModal}>
            <DsTypography variant="Regular_14">{variant === 'All' ? 'Are you sure you want to delete chat history?' : `Are you sure you want to delete chat `}<b>{`\"${chatMessage}\"?`}</b></DsTypography>
        </GeneralModal>
    )
}

export default DeleteChatModal;