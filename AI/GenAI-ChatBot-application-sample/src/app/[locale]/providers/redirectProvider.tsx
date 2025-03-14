'use client';

import { ROUTES } from "@/app/[locale]/consts";
import { initialState as authInitialState, setAuth } from "@/lib/slices/auth.slice";
import { setKnowledgeBaseId } from "@/lib/slices/KnowledgeBase.slice";
import { Auth } from "@/lib/store.types";
import { usePathname, useRouter } from "next/navigation";
import { ReactNode, useEffect } from "react"
import { useDispatch } from "react-redux";

interface RedirectProviderProps {
    children: ReactNode;
}

const RedirectProvider = ({ children }: RedirectProviderProps) => {
    const router = useRouter();
    const pathname = usePathname();
    const dispatch = useDispatch();

    useEffect(() => {
        dispatch(setKnowledgeBaseId(process.env.NEXT_PUBLIC_KNOWLEDGE_BASE_ID!));
    }, [dispatch])

    useEffect(() => {
        const authFromStorage = localStorage.getItem('genAi');
        const auth = authFromStorage ? JSON.parse(authFromStorage) as Auth : authInitialState;

        if (!auth.accessToken) {
            router.replace(ROUTES.BASE)
        } else {
            dispatch(setAuth(auth))

            if (pathname === ROUTES.BASE) {
                router.push(`${ROUTES.BASE}${ROUTES.CHAT}`)
            }
        }

        dispatch(setAuth({ ...auth, isSuccess: true }));
    }, [router, pathname, dispatch])

    return children;
}

export default RedirectProvider