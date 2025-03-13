import { useEffect, useState } from "react"

export const useRefDimensions = (current: HTMLElement | null): { width: number, height: number, top: number, bottom: number } => {
    const [dimensions, setDimensions] = useState({ width: 0, height: 0, top: 0, bottom: 0 })
    useEffect(() => {
        const timer = setInterval(() => {
            setTimeout(() => {
                if (current) {
                    const boundingRect = current.getBoundingClientRect()
                    const { width, height, top, bottom } = boundingRect
                    setDimensions(dimensions => {
                        const newDimentions = { width: Math.round(width), height: Math.round(height), top: Math.round(top), bottom: Math.round(bottom) };
                        return JSON.stringify(dimensions) !== JSON.stringify(newDimentions) ? newDimentions : dimensions;
                    })
                }
            }, 0);
        }, 10);

        return () => clearInterval(timer);
    }, [current])

    return dimensions
}