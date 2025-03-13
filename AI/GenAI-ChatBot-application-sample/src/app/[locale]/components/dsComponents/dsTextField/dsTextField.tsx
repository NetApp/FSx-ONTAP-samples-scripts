import { ChangeEvent, FocusEvent, HTMLInputTypeAttribute, KeyboardEvent, RefObject, forwardRef, useEffect, useRef, useState } from "react";
import { DsComponentProps } from "../dsTypes";
import { DsTooltipInfoProps } from "../dsTooltipInfo/dsTooltipInfo";
import DsTextFieldFrame from "./dsTextFieldFrame";
import useRunOnce from "@/app/[locale]/hooks/useRunOnce";
import { _Classes } from "@/utils/cssHelper.util";

export type TextFieldVariants = 'Default' | 'underline';

export interface DsTextFieldProps extends DsComponentProps<TextFieldVariants> {
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
    isPassword?: boolean,
    isNumeric?: boolean,
    min?: number | string,
    max?: number | string
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
    isNumeric,
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
    isCleanable = true,
    min,
    max,
    ...rest
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

        if (min && value < min) setTextValue(min.toString());
        else if (max && value > max) setTextValue(max.toString());
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
        }

        if (max && event.target.value > max) setTextValue(max.toString());

        //This needs to be inside a timeout to allow the changes to take effect before sending the event
        setTimeout(() => {
            onChange(event);
        }, 0);
    }

    const handleBlur = (event: FocusEvent<HTMLInputElement>) => {
        const value = event.target.value;
        if (min && value < min) {
            setTextValue(min.toString());
        }

        //This needs to be inside a timeout to allow the changes to take effect before sending the event
        setTimeout(() => {
            onBlur(event);
            if (min && value < min) {
                handleTextChange(event);
            }
        }, 0);
    }

    const inputType = (): HTMLInputTypeAttribute => {
        if (isPassword && !showPasswordText) return 'password';
        else if (isNumeric) return 'number'

        return 'text';
    }

    return (
        <DsTextFieldFrame
            ref={ref}
            className={_Classes(className, variant)}
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
            onChvronClick={onClick}
            {...rest}>
            <input type={inputType()}
                readOnly={isInputSelect}
                ref={inputRef}
                placeholder={placeholder}
                value={textValue}
                onChange={handleTextChange}
                onBlur={handleBlur}
                onClick={onClick}
                onKeyDown={onKeyDown}
                className={`textFieldInput  ${_Classes(typographyVariant)} ${isInputSelect ? 'isInputSelect' : ''} ${isHoverActions ? 'isHoverActions' : ''} ${isCleanable ? 'isCleanable' : ''} ${isPassword ? 'isPassword' : ''}`} />
        </DsTextFieldFrame>
    )
})

DsTextField.displayName = 'DsTextField';