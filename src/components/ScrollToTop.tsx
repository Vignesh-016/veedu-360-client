import { useEffect } from 'react';
import { useLocation } from 'react-router-dom';

const ScrollToTop = () => {
    const { pathname } = useLocation();

    useEffect(() => {
        // This will scroll the window to the top (0,0)
        window.scrollTo(0, 0);
    }, [pathname]); // The effect runs when 'pathname' changes

    return null;
};

export default ScrollToTop;