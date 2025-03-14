'use client';

import { LoginProvider } from "@/lib/api/api.types";
import { ClerkProvider } from "@clerk/nextjs";
import { ReactNode } from "react"

const GenAiClerkProvider = ({ children }: { children: ReactNode }) => {
    const loginProvider = process.env.NEXT_PUBLIC_LOGIN_PROVIDER as LoginProvider;

    return (
        <>
            {loginProvider === 'clerk' ? <ClerkProvider>{children}</ClerkProvider> : children}
        </>
    );
}

export default GenAiClerkProvider;