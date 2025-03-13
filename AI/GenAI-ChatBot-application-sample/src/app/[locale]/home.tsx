'use client';

import React from 'react';
import styles from './global.module.scss';
import LoginForm, { LoginType } from "./components/loginForm/loginForm";
import ChatBot from '@/app/[locale]/svgs/login/chatBot.png'
import Cloud from '@/app/[locale]/svgs/login/cloud.png'
import Image from 'next/image';
import { _Classes } from '@/utils/cssHelper.util';
import { useAppSelector } from '@/lib/hooks';
import rootSelector from '@/lib/selectors/root.selector';
import { useState } from "react";
import { useTranslation } from 'react-i18next';

const Home = () => {
  const { t } = useTranslation('home');
  const { accessToken, isSuccess } = useAppSelector(rootSelector.auth);
  const [loginType, setLoginType] = useState<LoginType | undefined>(undefined);
  return (
    <div className={_Classes(styles.genAi, loginType === 'AD' ? styles.isHidden : '')}>
      {(!accessToken && isSuccess) && <>
        <LoginForm onLoginSuccess={
          setLoginType
        } />
        <div className={styles.welcomeContent}>
          <Image
            src={ChatBot}
            alt="chatBot"
            width={1124}
            height={794}
            priority
            className={styles.chatBotImage} />
          <span className={_Classes(styles.Semibold_43, styles.title)}>{t('genAI.home.title')}</span>
          <span className={`${styles.Regular_20} ${styles.subTitle}`}>{t('genAI.home.subTitle')}</span>
          <Image
            src={Cloud}
            alt="clouds"
            width={982}
            height={284}
            priority
            className={styles.cloudsImage} />
        </div>
      </>}
    </div>
  )
}

export default Home;