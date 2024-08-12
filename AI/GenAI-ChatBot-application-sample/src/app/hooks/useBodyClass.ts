import { useEffect } from 'react';

const useBodyClass = (className: string) => {
  useEffect(() => {
    if (className) {
      document.body.classList.add(className);
    }

    return () => {
      document.body.classList.remove(className);
    };
  }, [className]);
};

export default useBodyClass;
