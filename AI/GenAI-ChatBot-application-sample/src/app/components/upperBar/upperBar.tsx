'use client';

import { _Classes } from '@/utils/cssHelper.util';
import styles from './upperBar.module.scss';
import UserIcon from '@/app/svgs/useIcon.svg';
import { DsTypography } from '../dsComponents/dsTypography/dsTypography';
import { DsButton } from '../dsComponents/dsButton/dsButton';
import { AuthService } from '@/app/auth/auth-service';
import { useRouter } from 'next/navigation';
import { ROUTES } from '@/app/consts';
import { useDispatch } from 'react-redux';
import { resetAuth } from '@/lib/slices/auth.slice';
import { resetChat } from '@/lib/slices/chat.slice';
import { apiSlice } from '@/lib/api/api.slice';
import { LoginProvider } from '@/lib/api/api.types';
import { ClerkSignout } from '@/app/services/clerk.service';
import { useAppSelector } from '@/lib/hooks';
import rootSelector from '@/lib/selectors/root.selector';

const UpperBar = () => {
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
            <DsTypography variant='Semibold_20'>Workload Factory GenAI sample application</DsTypography>
            <div className='userNameContainer'>
                <DsButton className='dsButton' type='text' icon={<UserIcon width={24} />} variant='secondary' dropDown={{
                    items: [
                        {
                            id: 'logout',
                            label: 'Log out',
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