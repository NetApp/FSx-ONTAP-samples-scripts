import { useEffect, useRef } from 'react';

const useRunOnce = (callback: () => any) => {
    const isRun = useRef(false);
    useEffect(() => {
        if (!isRun.current) {
            callback();
            isRun.current = true;
        }
    }, [isRun, callback]);
};

export default useRunOnce;
