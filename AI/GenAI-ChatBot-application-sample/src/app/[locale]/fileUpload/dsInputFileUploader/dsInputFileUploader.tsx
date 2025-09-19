import { ChangeEvent, forwardRef } from 'react';
import './dsInputFileUploader.scss';

export interface UploadedFile {
    id: string,
    data: FormData,
    fileName: string,
    size: number,
    fileType: string
}

interface DsInputFileUploaderProps {
    onChange?: (file: UploadedFile[]) => void,
    acceptableTypes?: string[],
    acceptMultiple?: boolean
}

const DsInputFileUploader = forwardRef<HTMLInputElement, DsInputFileUploaderProps>(({
    onChange,
    acceptableTypes,
    acceptMultiple = false,
}: DsInputFileUploaderProps, ref) => {
    const handleFileChange = (e: ChangeEvent<HTMLInputElement>) => {
        if (e.target.files && e.target.files.length > 0 && onChange) {
            const dataList: UploadedFile[] = [];

            Array.from(e.target.files).forEach((file, index) => {
                const data = new FormData();
                data.append('file', file);

                dataList.push({
                    id: index.toString(),
                    data,
                    fileName: file.name,
                    size: file.size,
                    fileType: file.type
                });
            })

            onChange(dataList);
        }
    };

    return (
        <input
            ref={ref}
            className='dsInputFileUploader'
            type="file"
            onChange={handleFileChange}
            accept={acceptableTypes?.join(',')}
            multiple={acceptMultiple}
        />
    )
})

export default DsInputFileUploader;