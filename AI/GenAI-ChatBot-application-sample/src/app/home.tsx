'use client';

import React from 'react';
import styles from './global.module.scss';
import LoginForm, { LoginType } from "./components/loginForm/loginForm";
import ChatBot from '@/app/svgs/login/chatBot.png'
import Cloud from '@/app/svgs/login/cloud.png'
import Image from 'next/image';
import { _Classes } from '@/utils/cssHelper.util';
import { useAppSelector } from '@/lib/hooks';
import rootSelector from '@/lib/selectors/root.selector';
import { useState } from "react";

const Home = () => {
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
          <span className={_Classes(styles.Semibold_43, styles.title)}>Welcome to Workload factory GenAI sample chatbot</span>
          <span className={`${styles.Regular_20} ${styles.subTitle}`}>By incorporating your enterprise data, GenAI Studio chatbot will understand industry-specific language, generate tailored responses, provide insights, and assist with documentation.</span>
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