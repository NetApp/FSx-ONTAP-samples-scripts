import React, { ChangeEvent, FocusEvent, KeyboardEvent, RefObject, forwardRef, useEffect, useRef, useState } from "react";
import { DsComponentProps } from "../dsTypes";
import { DsTooltipInfoProps } from "../dsTooltipInfo/dsTooltipInfo";
import DsTextFieldFrame, { _className } from "./dsTextFieldFrame";
import useRunOnce from "@/app/hooks/useRunOnce";

export interface DsTextFieldProps<variant extends 'Default' | string = 'Default'> extends DsComponentProps<variant> {
    isOptional?: boolean,
    tooltip?: Omit<DsTooltipInfoProps, 'title'>,
    value?: string,
    /** Event for text input change */
    onChange?: (event?: ChangeEvent<HTMLInputElement>) => void,
    onBlur?: (event: FocusEvent<HTMLInputElement>) => void,
    onKeyDown?: (event: KeyboardEvent<HTMLInputElement>) => void,
    placeholder?: string,
    isReadOnly?: boolean,
    countLimiting?: number,
    isCleanable?: boolean,
    isPassword?: boolean
};

export const DsTextField = forwardRef<HTMLInputElement, DsTextFieldProps>(({
    className = '',
    message,
    isDisabled,
    disabledReason,
    isLoading,
    isOptional,
    isReadOnly,
    isPassword,
    tooltip,
    onClick = () => { },
    onChange = () => { },
    onBlur = () => { },
    onKeyDown = () => { },
    style = {},
    title,
    typographyVariant = 'Regular_14',
    value = '',
    placeholder,
    countLimiting = 0,
    variant = 'Default',
    isCleanable = true
}: DsTextFieldProps, ref) => {
    const inputRef = useRef<HTMLInputElement>(null);

    const [textValue, setTextValue] = useState<string | undefined>(value)
    const [isInputSelect, setIsInputSelect] = useState<boolean>(false);
    const [isHoverActions, setIsHoverActions] = useState<boolean>(false);
    const [isShowClean, setIsShowClean] = useState<boolean>();
    const [showPasswordText, setShowPasswordText] = useState<boolean>(false);

    useRunOnce(() => {
        if ((ref as RefObject<HTMLDivElement>)?.current) {
            const thisInput = (ref as RefObject<HTMLDivElement>)?.current;
            thisInput?.addEventListener('focus', () => {
                inputRef.current?.focus();
            })
        }
    })

    useEffect(() => {
        setIsShowClean(textValue ? isCleanable : false);
    }, [isCleanable, textValue])

    useEffect(() => {
        setTextValue(value);
    }, [value])

    useEffect(() => {
        setTimeout(() => {
            const thisRef = ref as RefObject<HTMLInputElement>;
            setIsInputSelect(thisRef?.current?.getAttribute('isInputSelect') === 'true');
        }, 0);
    });

    const handleTextChange = (event: ChangeEvent<HTMLInputElement>) => {
        const valueLength = event.target.value.length;

        if ((!countLimiting || valueLength <= countLimiting)) {
            setTextValue(event.target.value);
            onChange(event);
        }
    }

    return (
        <DsTextFieldFrame
            ref={ref}
            className={`${className}`}
            message={message}
            countLimiting={countLimiting}
            isDisabled={isDisabled}
            disabledReason={disabledReason}
            isLoading={isLoading}
            isOptional={isOptional}
            isReadOnly={isReadOnly}
            style={style}
            title={title}
            tooltip={tooltip}
            value={textValue}
            variant={variant}
            onActionsHover={setIsHoverActions}
            resetValue={() => {
                setTextValue('');
                onChange();
                inputRef.current?.focus();
            }}
            showChevron={isInputSelect}
            isCleanable={isShowClean}
            isPassword={isPassword}
            onShowHidePassword={setShowPasswordText}
            onChvronClick={onClick}>
            <input type={isPassword && !showPasswordText ? 'password' : 'text'}
                readOnly={isInputSelect}
                ref={inputRef}
                placeholder={placeholder}
                value={textValue}
                onChange={handleTextChange}
                onBlur={onBlur}
                onClick={onClick}
                onKeyDown={onKeyDown}
                className={`textFieldInput  ${_className(typographyVariant)} ${isInputSelect ? 'isInputSelect' : ''} ${isHoverActions ? 'isHoverActions' : ''} ${isCleanable ? 'isCleanable' : ''} ${isPassword ? 'isPassword' : ''}`} />
        </DsTextFieldFrame>
    )
})

DsTextField.displayName = 'DsTextField';