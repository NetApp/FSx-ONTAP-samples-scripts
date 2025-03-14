import { useEffect, RefObject } from 'react';

type ScrollDirection = 'horizontal' | 'vertical' | 'all';

const useSyncScroll = (refs: RefObject<HTMLElement | null>[], scrollDirection: ScrollDirection): void => {
    useEffect(() => {
        if (!refs || refs.length === 0) return;

        const handleScroll = (sourceRef: RefObject<HTMLElement | null>) => {
            refs.forEach(ref => {
                if (ref.current && ref.current !== sourceRef.current) {
                    if ((['all', 'vertical'] as ScrollDirection[]).includes(scrollDirection)) ref.current.scrollTop = sourceRef.current!.scrollTop;
                    if ((['all', 'horizontal'] as ScrollDirection[]).includes(scrollDirection)) ref.current.scrollLeft = sourceRef.current!.scrollLeft;
                }
            });
        };

        const listeners = refs.map(ref => {
            if (ref.current) {
                const listener = () => handleScroll(ref);
                ref.current.addEventListener('scroll', listener);
                return { ref, listener };
            }
            return null;
        }).filter((listener): listener is { ref: RefObject<HTMLElement>, listener: () => void } => listener !== null);

        return () => {
            listeners.forEach(({ ref, listener }) => {
                if (ref.current) {
                    ref.current.removeEventListener('scroll', listener);
                }
            });
        };
    }, [refs, scrollDirection]);
};

export default useSyncScroll;