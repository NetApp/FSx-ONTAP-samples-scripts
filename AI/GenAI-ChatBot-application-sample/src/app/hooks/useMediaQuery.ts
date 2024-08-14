import React, { useMemo } from 'react';

const useMediaQuery = (queries: string[]): boolean[] => {
  const mediaQueries = useMemo(()=>queries.map((query) => window?.matchMedia(query)),[queries]);
  const [match, setMatch] = React.useState(
    mediaQueries.map((mediaQuery) => mediaQuery?.matches)
  );

  React.useEffect(() => {
    const handler = () =>
      setMatch(mediaQueries.map((mediaQuery) => mediaQuery?.matches));
    mediaQueries.map((mediaQuery) =>
      mediaQuery?.addEventListener('change', handler)
    );
    return () => {
      mediaQueries.map((mediaQuery) =>
        mediaQuery?.removeEventListener('change', handler)
      );
    };
  }, [mediaQueries]);

  return match;
};

export default useMediaQuery;
