import React, { ReactNode, useContext } from 'react';
import './ThemeProvider.scss';
import useMediaQuery from '@/app/[locale]/hooks/useMediaQuery';
import { calculateBreakpointWidth } from '@/utils/cssHelper.util';
import useBodyClass from '@/app/[locale]/hooks/useBodyClass';

export interface ThemeProviderProps {
  /** Your app */
  children: ReactNode;
  /** Is Your app will be rendered as an Iframe? */
  isIframe: boolean;
  /** Which theme should be used? light or dark? */
  theme: 'light' | 'dark';
}

interface sharedContextProps {
  theme: string;
  screenResolution: ResolutionType;
}

const ThemeContext = React.createContext<sharedContextProps>({
  theme: 'regular',
  screenResolution: 'largeResolution'
});

export type ResolutionType =
  | 'largeResolution'
  | 'mediumResolution'
  | 'smallResolution';

const useCalculateScreenResolution = (isIframe: boolean): ResolutionType => {
  const mediumResolutionBreakpoint = calculateBreakpointWidth(
    '--Medium_Resolution_Breakpoint',
    isIframe
  );
  const smallResolutionBreakpoint = calculateBreakpointWidth(
    '--Small_Resolution_Breakpoint',
    isIframe
  );
  const [isMediumResolution, isSmallResolution] = useMediaQuery([
    `(width<= ${mediumResolutionBreakpoint})`,
    `(width<= ${smallResolutionBreakpoint})`
  ]);

  if (isSmallResolution) {
    return 'smallResolution';
  }
  if (isMediumResolution) {
    return 'mediumResolution';
  }
  return 'largeResolution';
};

/** ThemeProvider should wrap your app in index.js, it is used to declare the css variables of the design system, including animations, colors and shadow */
export const ThemeProvider = ({
  children,
  isIframe = true,
  theme = 'light'
}: ThemeProviderProps) => {
  const screenResolution = useCalculateScreenResolution(isIframe);
  useBodyClass(theme === 'light' ? 'light-theme' : 'dark-theme');
  return (
    <ThemeContext.Provider
      value={{
        theme,
        screenResolution
      }}
    >
      {children}
    </ThemeContext.Provider>
  );
};

export const useThemeProvider = () => {
  return useContext(ThemeContext);
};
