import global from '../../global.module.scss';
import styles from './inputText.module.scss';
import { ChangeEvent } from 'react';

interface InputTextProps {
    title: string,
    value?: string,
    isPassword?: boolean,
    onChange?: (event?: ChangeEvent<HTMLInputElement>) => void,
    className?: string
}

const InputText = ({ title, onChange, value, isPassword, className = '' }: InputTextProps) => {
    return (
        <div className={`${className} ${styles.inputText}`}>
            <span className={global.Regular_14}>{title}</span>
            <input type={isPassword ? 'password' : 'text'} value={value} onChange={onChange} className={`${styles.textFieldInput} ${global.Regular_14}`} />
        </div>
    )
}

export default InputText;