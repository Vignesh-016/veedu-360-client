import { BrowserRouter as Router, Routes, Route, useLocation } from 'react-router-dom';
import { AuthProvider } from './lib/AuthContext';
import { lazy, Suspense } from 'react';

import ErrorBoundary from './components/ErrorBoundary';
import LoadingSpinner from './components/LoadingSpinner';
import RequirePhone from './components/RequirePhone';
import ScrollToTop from './components/ScrollToTop';
import GoogleAnalytics from './components/GoogleAnalytics';

const lazyWithChunkRecovery = (importer: () => Promise<any>) => lazy(async () => {
  try {
    const module = await importer();
    sessionStorage.removeItem('veedu360-chunk-recovery');
    return module;
  } catch (error) {
    const recoveryKey = 'veedu360-chunk-recovery';
    if (!sessionStorage.getItem(recoveryKey)) {
      sessionStorage.setItem(recoveryKey, '1');
      window.location.reload();
    }
    throw error;
  }
});

const Navbar = lazyWithChunkRecovery(() => import('./components/Navbar'));
const Home = lazyWithChunkRecovery(() => import('./pages/Home'));
const Login = lazyWithChunkRecovery(() => import('./components/Login'));
const AuthCallback = lazyWithChunkRecovery(() => import('./components/AuthCallback'));
const VerifyPhone = lazyWithChunkRecovery(() => import('./pages/VerifyPhone'));
const Catalogue = lazyWithChunkRecovery(() => import('./pages/Catalogue'));
const Wishlist = lazyWithChunkRecovery(() => import('./pages/Wishlist'));
const Plans = lazyWithChunkRecovery(() => import('./pages/Plans'));
const BuyContactPlans = lazyWithChunkRecovery(() => import('./pages/BuyContactPlans'));
const PropertySubmission = lazyWithChunkRecovery(() => import('./pages/PropertySubmission'));
const NotFound = lazyWithChunkRecovery(() => import('./pages/NotFound'));
const PropertyDetailsPage = lazyWithChunkRecovery(() => import('./pages/PropertyDetailsPage'));
const Terms = lazyWithChunkRecovery(() => import('./pages/Terms'));
const Privacy = lazyWithChunkRecovery(() => import('./pages/Privacy'));
const RefundPolicy = lazyWithChunkRecovery(() => import('./pages/RefundPolicy'));
const DeliveryPolicy = lazyWithChunkRecovery(() => import('./pages/DeliveryPolicy'));
const Profile = lazyWithChunkRecovery(() => import('./pages/Profile'));
const Footer = lazyWithChunkRecovery(() => import('./components/Footer'));
const Transactions = lazyWithChunkRecovery(() => import('./pages/Transactions'));
const MyOccupiedProperties = lazyWithChunkRecovery(() => import('./pages/MyOccupiedPropertiesPage'));
const MyListedProperties = lazyWithChunkRecovery(() => import('./pages/MyListedProperties'));
const MyTicketsPage = lazyWithChunkRecovery(() => import('./pages/MyTicketsPage'));
const CreateTicket = lazyWithChunkRecovery(() => import('./pages/CreateTicket'));
const TicketDetailsPage = lazyWithChunkRecovery(() => import('./pages/TicketDetailsPage'));
const MyPropertyDetailsPage = lazyWithChunkRecovery(() => import('./pages/MyPropertyDetailsPage'));
const EditPropertyPage = lazyWithChunkRecovery(() => import('./pages/EditPropertyPage'));
const AboutUs = lazyWithChunkRecovery(() => import('./pages/AboutUs'));
const ApartmentsForSaleTirunelveli = lazyWithChunkRecovery(() => import('./pages/ApartmentsForSaleTirunelveli'));
const CommercialPropertiesForSaleTirunelveli = lazyWithChunkRecovery(() => import('./pages/CommercialPropertiesForSaleTirunelveli'));
const HousesForSaleTirunelveli = lazyWithChunkRecovery(() => import('./pages/HousesForSaleTirunelveli'));
const PlotsForSaleTirunelveli = lazyWithChunkRecovery(() => import('./pages/PlotsForSaleTirunelveli'));
const VillasForSaleTirunelveli = lazyWithChunkRecovery(() => import('./pages/VillasForSaleTirunelveli'));
const ComingSoon = lazyWithChunkRecovery(() => import('./pages/ComingSoon'));
const MyRentalApplicationsPage = lazyWithChunkRecovery(() => import('./pages/MyRentalApplicationsPage'));
const MyRentalApplicationDetailsPage = lazyWithChunkRecovery(() => import('./pages/MyRentalApplicationDetailsPage'));

import { IconBrandWhatsapp } from '@tabler/icons-react';

// Layout component that conditionally renders Navbar and Footer
function AppLayout({ children }: { children: React.ReactNode }) {
  const location = useLocation();
  const hideNavFooter = ['/login', '/auth/callback'].includes(location.pathname);

  return (
    <>
      {!hideNavFooter && <Navbar />}
      <div className={`app ${!hideNavFooter ? 'md:pt-0' : ''}`}>
        <main className="content">
          {children}
        </main>
      </div>
      {!hideNavFooter && <Footer />}
      <a
        href="https://wa.me/919566034213"
        target="_blank"
        rel="noopener noreferrer"
        className="fixed bottom-6 left-6 z-50 bg-[#25D366] hover:bg-[#20ba5a] text-white p-3.5 rounded-full shadow-lg hover:shadow-xl transform hover:scale-110 transition-all duration-300 flex items-center justify-center group"
        aria-label="Contact us on WhatsApp"
        title="Chat with us on WhatsApp"
      >
        <IconBrandWhatsapp size={28} />
        <span className="max-w-0 overflow-hidden whitespace-nowrap group-hover:max-w-xs transition-all duration-300 ease-in-out font-medium text-sm pl-0 group-hover:pl-2">
          Chat with Us
        </span>
      </a>
    </>
  );
}


function App() {
  return (
    <Router>
      <AuthProvider>
        <ScrollToTop />
        <GoogleAnalytics />
        <ErrorBoundary>
          <Suspense fallback={<div className="flex justify-center items-center h-screen"><LoadingSpinner /></div>}>
            <AppLayout>
              <Routes>
                <Route path="/login" element={<Login />} />
                <Route path="/auth/callback" element={<AuthCallback />} />

                <Route path="/verifyphone" element={<VerifyPhone />} />
                <Route path="/terms" element={<Terms />} />
                <Route path="/privacy" element={<Privacy />} />
                <Route path="/refund-policy" element={<RefundPolicy />} />
                <Route path="/delivery-policy" element={<DeliveryPolicy />} />
                <Route path="/about" element={<AboutUs />} />
                <Route path="/apartments-for-sale-in-tirunelveli" element={<ApartmentsForSaleTirunelveli />} />
                <Route path="/commercial-properties-for-sale-in-tirunelveli" element={<CommercialPropertiesForSaleTirunelveli />} />
                <Route path="/houses-for-sale-in-tirunelveli" element={<HousesForSaleTirunelveli />} />
                <Route path="/plots-for-sale-in-tirunelveli" element={<PlotsForSaleTirunelveli />} />
                <Route path="/villas-for-sale-in-tirunelveli" element={<VillasForSaleTirunelveli />} />
                <Route path="/coming-soon/:category" element={<ComingSoon />} />

                {/* Routes requiring login AND phone */}
                <Route
                  path="/"
                  element={<RequirePhone><Home /></RequirePhone>}
                />
                <Route
                  path="/catalogue"
                  element={<RequirePhone><Catalogue /></RequirePhone>}
                />
                <Route
                  path="/property/:propertyId"
                  element={<RequirePhone><PropertyDetailsPage /></RequirePhone>}
                />
                <Route
                  path="/wishlist"
                  element={<RequirePhone><Wishlist /></RequirePhone>}
                />
                <Route
                  path="/plans"
                  element={<RequirePhone><Plans /></RequirePhone>}
                />
                <Route
                  path="/buy-contact-plans"
                  element={<RequirePhone><BuyContactPlans /></RequirePhone>}
                />
                <Route
                  path="/submit-property"
                  element={<RequirePhone><PropertySubmission /></RequirePhone>}
                />
                <Route
                  path="/profile"
                  element={<RequirePhone><Profile /></RequirePhone>}
                />
                <Route
                  path="/transactions"
                  element={<RequirePhone><Transactions /></RequirePhone>}
                />
                <Route
                  path="/my-properties"
                  element={<RequirePhone><MyListedProperties /></RequirePhone>}
                />
                <Route
                  path="/my-properties/:propertyId"
                  element={<RequirePhone><MyPropertyDetailsPage /></RequirePhone>}
                />
                <Route
                  path="/my-properties/edit/:propertyId"
                  element={<RequirePhone><EditPropertyPage /></RequirePhone>}
                />
                <Route
                  path="/my-rentals"
                  element={<RequirePhone><MyOccupiedProperties /></RequirePhone>}
                />
                <Route
                  path="/my-tickets"
                  element={<RequirePhone><MyTicketsPage /></RequirePhone>}
                />
                <Route
                  path="/create-ticket"
                  element={<RequirePhone><CreateTicket /></RequirePhone>}
                />
                <Route
                  path="/ticket/:ticketId"
                  element={<RequirePhone><TicketDetailsPage /></RequirePhone>}
                />
                <Route
                  path="/my-applications"
                  element={<RequirePhone><MyRentalApplicationsPage /></RequirePhone>}
                />
                <Route
                  path="/my-applications/:applicationId"
                  element={<RequirePhone><MyRentalApplicationDetailsPage /></RequirePhone>}
                />

                {/* Catch-all Not Found route */}
                <Route path="*" element={<NotFound />} />
              </Routes>
            </AppLayout>
          </Suspense>
        </ErrorBoundary>
      </AuthProvider>
    </Router>
  )
}

export default App;
