import { Message } from '@/app/[locale]/components/dsComponents/dsTypes';
import './dsListOfFilesForUpload.scss';
import { DsTextField } from '@/app/[locale]/components/dsComponents/dsTextField/dsTextField';
import { UploadedFile } from '../../dsInputFileUploader/dsInputFileUploader';

export interface UploadedFileProp extends UploadedFile {
    isLoading?: boolean,
    message?: Message,
    imageURLs?: string[],
}

export interface DsListOfFilesForUploadProps {
    files: UploadedFileProp[],
    loadingFileIds?: string[],
    messageFileIds?: {
        id: string,
        message: Message
    }[],
    inputFileRef: React.RefObject<HTMLInputElement | null>,
    onChange?: (files: UploadedFile[]) => void
}

export const DsListOfFilesForUpload = ({
    files,
    loadingFileIds,
    messageFileIds,
    inputFileRef,
    onChange = () => { }
}: DsListOfFilesForUploadProps) => {
    return (
        <div className="dsListOfFilesForUpload">
            {files.map((file) => {
                const { id, fileName } = file;

                return <DsTextField
                    key={id}
                    onChange={event => {
                        if (!event?.target.value) {
                            inputFileRef.current!.value = '';
                            onChange(files.filter(file => file.id !== id));
                        }
                    }}
                    className="fileItemName"
                    isReadOnly
                    isCleanable
                    value={fileName}
                    isLoading={loadingFileIds?.includes(id)}
                    message={messageFileIds?.find(message => message.id === id)?.message} />
            })}
        </div>
    )
}