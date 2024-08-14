import { Amplify, Auth, Hub } from "aws-amplify";
import useRunOnce from "../hooks/useRunOnce";
import awsConfig from "../cognito/aws-configs";
import { useEffect, useState } from "react";
import { AuthService } from "../auth/auth-service";
import { CognitoPayload } from "../cognito/cognito.types";
import { SignInResult } from "@/lib/api/api.types";

const CognitoSignIn = (): SignInResult => {
    const [isLoading, setIsLoading] = useState<boolean>(false);
    const [email, setEmail] = useState<string | undefined>();
    const [password, setPassword] = useState<string | undefined>();
    const [error, setError] = useState<string | undefined>();
    const [jwtToken, setJwtToken] = useState<string | undefined>();
    const [userName, setUserName] = useState<string | undefined>();

    useRunOnce(() => {
        Amplify.configure(awsConfig);
    })

    useEffect(() => {
        // Default handler for listening events
        const onHubCapsule = async (capsule: any) => {
            const { channel, payload } = capsule;

            if (channel === AuthService.CHANNEL && payload.event === AuthService.AUTH_EVENTS.LOGIN) {
                if (!payload.success) {
                    if (payload.error.code === 'UserNotConfirmedException') {

                        setError('User is not confirmed');

                        // Resending another code
                        await AuthService.resendConfirmationCode(payload.email);
                    } else {
                        setError(payload.message);
                    }
                } else {
                    const { user: { signInUserSession: { accessToken: { jwtToken }, idToken: { payload: { email } } } }, username } = payload as CognitoPayload;
                    setJwtToken(jwtToken);
                    setUserName(username || email);
                }

                setTimeout(() => {
                    setIsLoading(false);
                }, 2000);
            }
        };

        Hub.listen(AuthService.CHANNEL, (data) => {
            onHubCapsule(data);
        });

        const updateUser = async () => {
            try {
                await Auth.currentAuthenticatedUser()
            } catch {
            }
        }

        updateUser();

        return function cleanup() {
            Hub.remove(AuthService.CHANNEL, onHubCapsule);
        };
    }, []);

    const doLogin = async (email?: string, password?: string) => {
        setError(undefined);

        setEmail(email || '');
        setPassword(password || '');

        if (email && password) {
            setIsLoading(true);
            await AuthService.login(email, password);
        }
    }

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

export default CognitoSignIn;