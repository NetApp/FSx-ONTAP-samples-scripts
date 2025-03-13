import { SignInResultClerk } from "@/lib/api/api.types";
import { useAuth, useClerk, useSignIn, useUser } from "@clerk/nextjs";
import { useEffect, useState } from "react";
import { useTranslation } from "react-i18next";

export const ClerkSignIn = (): SignInResultClerk => {
    const { t } = useTranslation();

    const [email, setEmail] = useState<string | undefined>();
    const [password, setPassword] = useState<string | undefined>();
    const [isLoading, setIsLoading] = useState<boolean>(false);
    const [jwtToken, setJwtToken] = useState<string | undefined>();
    const [error, setError] = useState<string | undefined>();
    const [userName, setUserName] = useState<string | undefined>();

    const { isLoaded, signIn, setActive } = useSignIn();
    const { getToken } = useAuth();
    const { user } = useUser();
    const { username = null, primaryEmailAddress } = user || {};
    const { emailAddress } = primaryEmailAddress || {};

    useEffect(() => {
        if (username || emailAddress) {
            setUserName(username || emailAddress);
        }
    }, [username, emailAddress])

    const doLogin = async (email?: string, password?: string) => {
        setError(undefined);
        setEmail(email || '');
        setPassword(password || '');

        if (!isLoaded || !email || !password) {
            return;
        }

        setIsLoading(true);

        // Start the sign-in process using the email and password provided
        try {
            const signInAttempt = await signIn.create({
                identifier: email,
                password,
            });

            // If sign-in process is complete, set the created session as active
            // and redirect the user
            if (signInAttempt.status === 'complete') {
                await setActive({ session: signInAttempt.createdSessionId });
                const jwtToken = await getToken({ template: process.env.NEXT_PUBLIC_CLERK_TEMPLATE });
                setJwtToken(jwtToken || undefined);
            } else {
                // If the status is not complete, check why. User may need to
                // complete further steps.
                setError(JSON.stringify(signInAttempt, null, 2))
            }
        } catch (err: any) {
            // See https://clerk.com/docs/custom-flows/error-handling
            // for more info on error handling
            setError(t('genAI.messages.errors.incorrectUserPassword'))
        } finally {
            setTimeout(() => {
                setIsLoading(false);
            }, 2000);
        }
    };

    return {
        isLoading,
        email,
        password,
        doLogin,
        jwtToken,
        error,
        userName
    }
}

export const ClerkSignout = () => {
    const { signOut } = useClerk();
    return signOut;
}