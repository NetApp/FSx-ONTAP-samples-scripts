import { forwardRef, useRef, useState } from "react";
import './dsSingleFileUpload.scss';
import Upload from "@/app/[locale]/svgs/upload.svg";
import { _Classes } from '@/utils/cssHelper.util';
import { DsTextField, DsTextFieldProps } from "../../components/dsComponents/dsTextField/dsTextField";
import DsInputFileUploader, { UploadedFile } from "../dsInputFileUploader/dsInputFileUploader";

export interface DsBaseFileUploadProps {
    /** File type that can be selected eg '.pdf', '.docx', '.png', '.jpeg' */
    acceptableTypes?: string[]
    "data-testid"?: string,
    id?: string,
}

export interface DsFileUploadProps extends DsBaseFileUploadProps, Omit<DsTextFieldProps, 'onChange' | 'isReadOnly' | 'countLimiting' | 'isPassword' | 'isNumeric' | 'min' | 'max' | 'actions'> {
    onChange?: (args?: UploadedFile) => void,
}

export const DsSingleFileUpload = forwardRef<HTMLDivElement, DsFileUploadProps>(({
    onChange,
    placeholder,
    acceptableTypes,
    className,
    "data-testid": testId,
    id,
    ...rest
}: DsFileUploadProps, ref) => {
    const inputFileRef = useRef<HTMLInputElement>(null);
    const [fileName, setFileName] = useState('');

    const handleFileChange = (file: UploadedFile) => {
        setFileName(file.fileName);
        if (onChange) onChange(file)
    }

    return (
        <div className={_Classes(`dsSingleFileUpload`, className)} ref={ref} data-testid={testId} id={id}>
            <DsInputFileUploader ref={inputFileRef} onChange={files => handleFileChange(files[0])} acceptableTypes={acceptableTypes} />
            <DsTextField className="uploadFileInput"
                {...rest}
                isReadOnly={true}
                isCleanable
                placeholder={placeholder}
                onChange={() => {
                    if (inputFileRef.current) {
                        inputFileRef.current.value = '';
                        setFileName('');
                        if (onChange) onChange();
                    }
                }}
                value={fileName} />
        </div>
    )
})