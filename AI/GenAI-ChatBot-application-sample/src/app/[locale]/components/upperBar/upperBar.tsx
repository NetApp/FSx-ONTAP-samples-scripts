'use client';

import { _Classes } from '@/utils/cssHelper.util';
import styles from './upperBar.module.scss';
import UserIcon from '@/app/[locale]/svgs/useIcon.svg';
import { DsTypography } from '../dsComponents/dsTypography/dsTypography';
import { DsButton } from '../dsComponents/dsButton/dsButton';
import { AuthService } from '@/app/[locale]/auth/auth-service';
import { useRouter } from 'next/navigation';
import { ROUTES } from '@/app/[locale]/consts';
import { useDispatch } from 'react-redux';
import { resetAuth } from '@/lib/slices/auth.slice';
import { resetChat } from '@/lib/slices/chat.slice';
import { apiSlice } from '@/lib/api/api.slice';
import { LoginProvider } from '@/lib/api/api.types';
import { ClerkSignout } from '@/app/[locale]/services/clerk.service';
import { useAppSelector } from '@/lib/hooks';
import rootSelector from '@/lib/selectors/root.selector';
import { useTranslation } from 'react-i18next';

const UpperBar = () => {
    const { t } = useTranslation();
    const loginProvider = process.env.NEXT_PUBLIC_LOGIN_PROVIDER as LoginProvider;

    const dispatch = useDispatch();
    const router = useRouter();
    const { userName } = useAppSelector(rootSelector.auth);

    const clerkSignout = loginProvider === 'clerk' ? ClerkSignout() : () => { };

    const logout = () => {
        loginProvider === 'cognito' ? AuthService.signOut() : clerkSignout();

        dispatch(resetAuth());
        dispatch(resetChat());
        dispatch(apiSlice.util.resetApiState());
        router.push(ROUTES.BASE);
    }

    return (
        <div className={_Classes(styles.upperBar)}>
            <DsTypography variant='Semibold_20'>{t('genAI.title')}</DsTypography>
            <div className='userNameContainer'>
                <DsButton className='dsButton' type='text' icon={<UserIcon width={24} />} variant='secondary' dropDown={{
                    items: [
                        {
                            id: 'logout',
                            label: t('genAI.loginForm.logout'),
                            onClick: () => logout()
                        }
                    ],
                    placement: 'alignRight'
                }}>{userName}</DsButton>
            </div>
        </div>
    )
}

export default UpperBar;