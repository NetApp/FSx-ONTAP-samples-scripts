'use client';

import global from '@/app/global.module.scss';
import styles from './loginForm.module.scss';
import NetApp from '@/app/svgs/netApp.svg'
import { DsButton } from '../dsComponents/dsButton/dsButton';
import { _Classes } from '@/utils/cssHelper.util';
import { useEffect, useRef, useState } from 'react';
import { DsTextField } from '../dsComponents/dsTextField/dsTextField';
import CognitoSignIn from '@/app/services/cognito.service';
import { ROUTES } from '@/app/consts';
import { useRouter } from 'next/navigation';
import { useDispatch } from 'react-redux';
import { addNotification, removeNotification } from '@/lib/slices/notifications.slice';
import { NOTIFICATION_CONSTS } from '../NotificationGroup/notification.consts';
import { setAuth } from '@/lib/slices/auth.slice';
import { ClerkSignIn } from '@/app/services/clerk.service';
import {LoginProvider, SignInResultClerk, SignInResultCognito} from '@/lib/api/api.types';
import useRunUntil from '@/app/hooks/useRunUntil';

export type LoginType = 'AD' | 'UserPassword'
interface LoginFormProps {
    onLoginSuccess: (loginType:LoginType )=> void
}

const LoginForm = ({onLoginSuccess}:LoginFormProps) => {
    const loginProvider = process.env.NEXT_PUBLIC_LOGIN_PROVIDER as LoginProvider;
    const loginEternalProvider:string | undefined = process.env.NEXT_PUBLIC_LOGIN_EXTERNAL_PROVIDER;

    const emailRef = useRef<HTMLInputElement>(null);

    const dispatch = useDispatch();
    const router = useRouter();

    const [email, setEmail] = useState<string | undefined>();
    const [password, setPassword] = useState<string | undefined>();

    const { isLoading: isLoadingCog, jwtToken: jwtTokenCog, email: emailCog, password: passwordCog, userName: userNameCog, error: errorCog, doLogin: doLoginCog } = loginProvider  === 'cognito' ? CognitoSignIn() : {} as SignInResultCognito
    const { isLoading: isLoadingClerk, jwtToken: jwtTokenClerk, email: emailClerk, password: passwordClerk, userName: userNameClerk, error: errorClerk, doLogin: doLoginClerk } = loginProvider === 'clerk' ? ClerkSignIn() : {} as SignInResultClerk;

    useRunUntil(() => {
        emailRef.current?.focus();
    }, !emailRef.current);

    useEffect(() => {
        setEmail(loginProvider === 'cognito' ? emailCog : emailClerk);
        setPassword(loginProvider === 'cognito' ? passwordCog : passwordClerk);
    }, [emailCog, emailClerk, passwordCog, passwordClerk, loginProvider])

    useEffect(() => {
        if (errorCog || errorClerk) {
            dispatch(addNotification({
                id: NOTIFICATION_CONSTS.UNIQUE_IDS.USER_NOT_CONFIRMED,
                type: 'error',
                children: errorCog || errorClerk
            }))
        }
    }, [errorCog, errorClerk, dispatch])

    useEffect(() => {
        if (jwtTokenCog || jwtTokenClerk) {
            onLoginSuccess(loginEternalProvider?  'AD': 'UserPassword')
            dispatch(setAuth({
                isSuccess: true,
                accessToken: jwtTokenCog || jwtTokenClerk,
                userName: userNameClerk || userNameCog
            }));
            router.push(`${ROUTES.BASE}${ROUTES.CHAT}`);
        }
    }, [jwtTokenCog, jwtTokenClerk, router, userNameClerk, userNameCog, dispatch, loginEternalProvider, onLoginSuccess])

    const doLogin = () => {
        dispatch(removeNotification(NOTIFICATION_CONSTS.UNIQUE_IDS.USER_NOT_CONFIRMED));
        loginProvider === 'cognito' ? doLoginCog(email, password,loginEternalProvider) : doLoginClerk(email, password);
    }

    return (
        <div className={styles.loginForm}>
            <NetApp width={112} />
            <div className={styles.formContent}>
                <span className={_Classes(global.Regular_24, styles.formTitle)}>Log in to Workload Factory GenAI sample application</span>
                <span className={`${global.Regular_14}`}>Log in to NetApp GenAI Studio chatbot sample application with<br />your company user account.</span>
                {!process.env.NEXT_PUBLIC_LOGIN_EXTERNAL_PROVIDER && <>
                    <DsTextField
                    ref={emailRef}
                    title='Email'
                    className={styles.formInput}
                    onChange={event => {
                        setEmail(event?.target.value || '')

                    }}
                    onKeyDown={event => {
                        if (event.key === 'Enter') {
                            doLogin();
                        }
                    }}
                    message={email === '' ? {
                        type: 'error',
                        value: 'This field is required.'
                    } : undefined}
                />
                    <DsTextField
                        title='Password'
                        isPassword
                        className={styles.formInput}
                        onChange={event => setPassword(event?.target.value)}
                        onKeyDown={event => {
                            if (event.key === 'Enter') {
                                doLogin();
                            }
                        }}
                        message={password === '' ? {
                            type: 'error',
                            value: 'This field is required.'
                        } : undefined} />
                </>}
                <DsButton onClick={() => doLogin()} className={styles.loginButton} isLoading={isLoadingCog || isLoadingClerk}>Login</DsButton>
            </div>
        </div>
    )
}

export default LoginForm;