import { forwardRef, useEffect, useRef, useState } from "react";
import './dsMultipleFileUpload.scss';
import { _Classes } from '@/utils/cssHelper.util';
import { DsButton, DsButtonProps } from "../../components/dsComponents/dsButton/dsButton";
import DsInputFileUploader, { UploadedFile } from "../dsInputFileUploader/dsInputFileUploader";
import { DsBaseFileUploadProps } from "../dsSingleFileUpload/dsSingleFileUpload";
import { DsListOfFilesForUpload, UploadedFileProp } from "./dsListOfFilesForUpload/dsListOfFilesForUpload";

export interface DsMultipleFileUploadProps extends DsBaseFileUploadProps, DsButtonProps {
    onChange?: (files?: UploadedFile[]) => void,
    acceptMultiple?: boolean,
    filesInQueue?: UploadedFileProp[]
    "data-testid"?: string,
    id?: string,
}

export const DsMultipleFileUpload = forwardRef<HTMLDivElement, DsMultipleFileUploadProps>(({
    onChange,
    acceptableTypes,
    className,
    "data-testid": testId,
    id,
    acceptMultiple = true,
    isDisabled = false,
    filesInQueue = [],
    ...rest
}: DsMultipleFileUploadProps, ref) => {
    const inputFileRef = useRef<HTMLInputElement>(null);

    const [files, setFiles] = useState<UploadedFileProp[]>(filesInQueue);

    useEffect(() => {
        setFiles(prevFiles => JSON.stringify(filesInQueue) !== JSON.stringify(prevFiles) ? filesInQueue : prevFiles);
    }, [filesInQueue])

    const handleFileChange = (files: UploadedFileProp[]) => {
        setFiles(files);
        if (onChange) onChange(files)
    }

    const openDialog = () => {
        if (inputFileRef.current) {
            const inputFile = inputFileRef.current as HTMLButtonElement;
            if (!inputFile) return;
            inputFile.click();
        }
    };

    return (
        <div className={_Classes(`dsMultipleFileUpload`, className)} ref={ref} data-testid={testId} id={id}>
            <DsInputFileUploader ref={inputFileRef} onChange={handleFileChange} acceptableTypes={acceptableTypes} acceptMultiple={acceptMultiple} />
            <DsButton isDisabled={isDisabled} {...rest} onClick={event => {
                if (rest.onClick) rest.onClick(event);
                openDialog();
            }} />
            {!isDisabled && <DsListOfFilesForUpload
                files={files}
                inputFileRef={inputFileRef}
                loadingFileIds={files.filter(file => file.isLoading).map(file => file.id)}
                messageFileIds={files.filter(file => file.message).map(file => {
                    return {
                        id: file.id,
                        message: file.message!
                    }
                })}
                onChange={handleFileChange} />}
        </div>
    )
})