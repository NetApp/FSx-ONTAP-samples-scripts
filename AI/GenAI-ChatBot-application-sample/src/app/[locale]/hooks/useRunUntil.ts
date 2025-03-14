import { useEffect, useRef } from 'react';

const useRunUntil = (callback: () => any, runWhile: boolean = false) => {
    const isRun = useRef(false);
    useEffect(() => {
        if (!isRun.current) {
            callback();
            isRun.current = runWhile;
        }
    }, [isRun, callback, runWhile]);
};

export default useRunUntil;