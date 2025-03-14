import { Amplify, Auth, Hub } from "aws-amplify";
import useRunOnce from "../hooks/useRunOnce";
import awsConfig from "../cognito/aws-configs";
import { useEffect, useState } from "react";
import { AuthService } from "../auth/auth-service";
import { CognitoPayload } from "../cognito/cognito.types";
import { SignInResultCognito } from "@/lib/api/api.types";
import { CognitoUser } from "amazon-cognito-identity-js";
import awsConfigs from "../cognito/aws-configs";
import { useTranslation } from "react-i18next";

const isLoginEternalProvider: boolean = !!process.env.NEXT_PUBLIC_LOGIN_EXTERNAL_PROVIDER;

const CognitoSignIn = (): SignInResultCognito => {
    const { t } = useTranslation();

    const [isLoading, setIsLoading] = useState<boolean>(false);
    const [email, setEmail] = useState<string | undefined>();
    const [password, setPassword] = useState<string | undefined>();
    const [error, setError] = useState<string | undefined>();
    const [jwtToken, setJwtToken] = useState<string | undefined>();
    const [userName, setUserName] = useState<string | undefined>();

    useRunOnce(() => {
        if (awsConfig.oauth && typeof awsConfig.oauth === "string") awsConfigs.oauth = JSON.parse(awsConfigs.oauth!)
        Amplify.configure(awsConfig);
    })

    useEffect(() => {
        // Default handler for listening events
        const onHubCapsule = async (capsule: any) => {
            const { channel, payload } = capsule;

            if (channel === AuthService.CHANNEL && payload.event === AuthService.AUTH_EVENTS.LOGIN) {
                if (!payload.success) {
                    if (payload.error.code === 'UserNotConfirmedException') {

                        setError(t('genAI.messages.errors.userNotConfirmed'));

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
                const authenticatedUser: CognitoUser = await Auth.currentAuthenticatedUser()
                if (isLoginEternalProvider) {
                    Hub.dispatch(AuthService.CHANNEL, {
                        event: AuthService.AUTH_EVENTS.LOGIN,
                        // @ts-ignore
                        success: true,
                        message: "",
                        username: authenticatedUser.getUsername(),
                        user: authenticatedUser
                    });
                }
            } catch {
            }
        }

        updateUser();

        return function cleanup() {
            Hub.remove(AuthService.CHANNEL, onHubCapsule);
        };
    }, [t]);

    const doLogin = async (email?: string, password?: string, externalProviderName?: string) => {
        setError(undefined);

        setEmail(email || '');
        setPassword(password || '');

        if (externalProviderName) {
            setIsLoading(true);
            await Auth.federatedSignIn({ provider: externalProviderName as any });
        }
        else if (email && password) {
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