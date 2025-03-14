import moment from 'moment';
import { ReactElement } from 'react';

export interface ValueSymbole {
    value: number | string | ReactElement,
    symbol: string
}

export const formatBytes = (bytes: number, decimals = 2): ValueSymbole => {
    if (!+bytes) return { value: 0, symbol: 'Bytes' }

    const k = 1024
    const dm = decimals < 0 ? 0 : decimals
    const sizes = ['Bytes', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB', 'EiB', 'ZiB', 'YiB']

    const i = Math.floor(Math.log(Math.abs(bytes)) / Math.log(k))

    return { value: parseFloat((bytes / Math.pow(k, i)).toFixed(dm)), symbol: sizes[i] }
}

export const formatNumberWithSymbol = (number: number, digits: number): ValueSymbole => {
    if (number >= 1e3 && number < 1e6) return { value: +(number / 1e3).toFixed(digits), symbol: "K" };
    if (number >= 1e6 && number < 1e9) return { value: +(number / 1e6).toFixed(digits), symbol: "M" };
    if (number >= 1e9 && number < 1e12) return { value: +(number / 1e9).toFixed(digits), symbol: "B" };
    if (number >= 1e12 && number < 1e15) return { value: +(number / 1e12).toFixed(digits), symbol: "T" };
    if (number >= 1e15 && number < 1e18) return { value: +(number / 1e15).toFixed(digits), symbol: "P" };
    if (number >= 1e18) return { value: +(number / 1e18).toFixed(digits), symbol: "E" };

    return { value: +(number).toFixed(digits), symbol: '' };
}

export const flattenObject = (obj: any) => {
    const flattened: any = {}

    Object.keys(obj).forEach((key) => {
        const value = obj[key]

        if (typeof value === 'object' && value !== null && !Array.isArray(value)) {
            Object.assign(flattened, flattenObject(value))
        } else {
            flattened[key] = value
        }
    })

    return flattened
}

export const addSpaceBetweenDigitsAndStrings = (inputString: string): string => {
    return inputString.replace(/([a-zA-Z]+)|(\d+)|(-)/g, (match, p1, p2, p3) => {
        if (p1) {
            return p1 + ' ';
        } else if (p2) {
            return p2 + ' ';
        } else if (p3) {
            return ' ' + p3 + ' ';
        }
        return match;
    });
}

export const formatDate = (date: number, short?: boolean) => {
    return !short ? moment(date).format('MMM DD, YYYY H:mm') : moment(date).format('MMM DD, YYYY');
}
