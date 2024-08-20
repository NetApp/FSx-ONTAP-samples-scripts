import { ChangeEvent, CSSProperties, ReactNode, SyntheticEvent } from "react";

export type BaseVariant = 'Default';
export type AlertType = 'info' | 'error' | 'warning';
export type TriggerType = 'hover' | 'click';
export type SelectionType = 'single' | 'multi'

export type TypographyVariant =
    | 'Regular_40'
    | 'Semibold_32'
    | 'Regular_32'
    | 'Semibold_24'
    | 'Regular_24'
    | 'Semibold_20'
    | 'Regular_20'
    | 'Semibold_16'
    | 'Regular_16'
    | 'Regular_14'
    | 'Semibold_14'
    | 'Semibold_13'
    | 'Regular_13'
    | 'Regular_12';


export interface WithChildren {
    /** Text or ReactNodes to render inside the card */
    children: ReactNode
}

export interface DsExpandableComponent {
    isExpanded?: boolean,
    onExpandChange?: (isExpanded: boolean) => void
}

export interface DsSelectableComponent<elementType extends HTMLElement> {
    id: string,
    isSelected?: boolean,
    onSelect?: (id: string, event: ChangeEvent<elementType>) => void
}

export interface Message {
    type: AlertType,
    value: string | JSX.Element,
    tooltipValue?: string
}

export interface DsBaseComponentProps {
    className?: string,
    typographyVariant?: TypographyVariant,
    style?: CSSProperties,
    onClick?: (event: SyntheticEvent) => void
}

export interface DropDownCustomeItem<T> {
    formatOptionLabel?: (option: T) => JSX.Element
}

export interface DsComponentProps<variant extends 'Default' | string = 'Default'> extends DsBaseComponentProps {
    /** The title of the component */
    title?: ReactNode,
    /** Component variation */
    variant?: BaseVariant | variant,
    isDisabled?: boolean,
    disabledReason?: string,
    isLoading?: boolean,
    message?: Message
}