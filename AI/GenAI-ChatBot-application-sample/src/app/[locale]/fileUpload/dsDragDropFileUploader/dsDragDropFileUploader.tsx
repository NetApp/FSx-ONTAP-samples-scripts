import { forwardRef, useEffect, useRef, useState } from 'react';
import './dsDragDropFileUploader.scss';
import { _Classes } from '@/utils/cssHelper.util';
import { DsBaseComponentProps, Message } from "../../components/dsComponents/dsTypes";
import { DsMessageContainer } from '../../components/dsComponents/dsMessageContainer/dsMessageContainer';
import { DsTypography } from '../../components/dsComponents/dsTypography/dsTypography';
import DsInputFileUploader, { UploadedFile } from '../dsInputFileUploader/dsInputFileUploader';
import { DsBaseFileUploadProps } from '../dsSingleFileUpload/dsSingleFileUpload';
import { DsListOfFilesForUpload, UploadedFileProp } from '../dsMultipleFileUpload/dsListOfFilesForUpload/dsListOfFilesForUpload';

export interface DsDragDropFileUploaderProps extends DsBaseComponentProps, DsBaseFileUploadProps {
    acceptMultiple?: boolean,
    filesInQueue?: UploadedFileProp[]
    isDisabled?: boolean,
    placeholder?: string,
    message?: Message,
    onChange?: (files?: UploadedFile[]) => void,
    onDragOver?: (event: React.DragEvent<HTMLDivElement>) => void,
    onDragStart?: (event: React.DragEvent<HTMLDivElement>) => void,
    onDrop?: (event: React.DragEvent<HTMLDivElement>, files?: UploadedFile[]) => void,
    onDropFailed?: (files?: UploadedFile[]) => void
    onDragLeave?: (event: React.DragEvent<HTMLDivElement>) => void,
}

export const DsDragDropFileUploader = forwardRef<HTMLDivElement, DsDragDropFileUploaderProps>(({
    onChange = () => { },
    onDragOver = () => { },
    onDragStart = () => { },
    onDrop = () => { },
    onDropFailed = () => { },
    onDragLeave = () => { },
    onClick,
    acceptableTypes,
    className,
    acceptMultiple = false,
    filesInQueue = [],
    isDisabled,
    placeholder,
    style,
    message,
    typographyVariant = 'Regular_14',
    ...rest
}: DsDragDropFileUploaderProps, ref) => {
    const inputFileRef = useRef<HTMLInputElement>(null);

    const [files, setFiles] = useState<UploadedFileProp[]>(filesInQueue);
    const [isDragOver, setIsDragOver] = useState(false);

    useEffect(() => {
        setFiles(prevFiles => JSON.stringify(filesInQueue) !== JSON.stringify(prevFiles) ? filesInQueue : prevFiles);
    }, [filesInQueue])

    const handleDragClick = () => {
        if (inputFileRef.current) {
            const inputFile = inputFileRef.current as HTMLButtonElement;
            if (!inputFile) return;
            inputFile.click();
        }
    };

    const handleDragOver = (event: React.DragEvent<HTMLDivElement>) => {
        event.preventDefault();
        event.stopPropagation();
        onDragOver(event);
        setIsDragOver(true);
    }

    const handleFileChange = (files: UploadedFileProp[]) => {
        setFiles(files);
        onChange(files)
    }

    const handleDrop = (event: React.DragEvent<HTMLDivElement>) => {
        event.preventDefault();
        event.stopPropagation();
        setIsDragOver(false);
        const files = event.dataTransfer.files;
        const dataList: UploadedFileProp[] = [];
        const failedDataList: UploadedFileProp[] = [];

        Array.from(files).forEach((file, index) => {
            const data = new FormData();
            data.append('file', file);

            const uploadedFile: UploadedFileProp = {
                id: index.toString(),
                data,
                fileName: file.name,
                size: file.size,
                fileType: file.type,
                imageURLs: file.type.startsWith('image/') ? [URL.createObjectURL(file)] : [],
            };

            if (acceptableTypes && !acceptableTypes.some(type => file.name.endsWith(type))) {
                failedDataList.push(uploadedFile);
            } else {
                dataList.push(uploadedFile);
            }
        })

        if (dataList.length > 0) {
            setFiles(dataList);
            onChange(dataList);
            onDrop(event, dataList);
        }

        if (failedDataList.length > 0) {
            onDropFailed(failedDataList);
        }
    }
    // function handleFiles(file: File) {
    //     // for (let i = 0; i < files.length; i++) {
    //     //     const file = files[i];
    //     if (file.type.startsWith('image/png')) { // Only process PNGs
    //         const reader = new FileReader();
    //         reader.readAsDataURL(file);
    //         reader.onloadend = function () {
    //             const img = document.createElement('img');
    //             if (typeof reader.result === 'string') {
    //                 img.src = reader.result;
    //             }
    //             img.classList.add('thumbnail');
    //             return reader.result;
    //         };
    //     }
    //     return '';
    //     // }
    // }

    return (
        <div className={_Classes('dsDragDropFileUploader', className, { isDisabled })}
            style={style}
            ref={ref}
            onClick={onClick}
            {...rest}>
            <div className='dragDropContainerWithMessage'>
                <div className={_Classes('dragDropContainer', { isDragOver })}
                    onClick={() => handleDragClick()}
                    onDragOver={event => handleDragOver(event)}
                    onDrop={event => handleDrop(event)}
                    onDragEnd={() => { setIsDragOver(false); onDragLeave; }}
                    onDragLeave={() => { setIsDragOver(false); onDragLeave; }}
                    onDragStart={onDragStart}>
                    <DsInputFileUploader ref={inputFileRef} onChange={handleFileChange} acceptableTypes={acceptableTypes} acceptMultiple={acceptMultiple} />
                    <DsTypography className="placeholder" variant={typographyVariant}>{placeholder}</DsTypography>
                </div>
                {message && <DsMessageContainer message={message} />}
            </div>
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
    );
});