import { BrowserRouter as Router, Routes, Route, useLocation } from 'react-router-dom';
import { AuthProvider } from './lib/AuthContext';
import { lazy, Suspense } from 'react';

import ErrorBoundary from './components/ErrorBoundary';
import LoadingSpinner from './components/LoadingSpinner';
import RequirePhone from './components/RequirePhone';
import ScrollToTop from './components/ScrollToTop';

const Navbar = lazy(() => import('./components/Navbar'));
const Home = lazy(() => import('./pages/Home'));
const Login = lazy(() => import('./components/Login'));
const AuthCallback = lazy(() => import('./components/AuthCallback'));
const VerifyPhone = lazy(() => import('./pages/VerifyPhone'));
const Catalogue = lazy(() => import('./pages/Catalogue'));
const Wishlist = lazy(() => import('./pages/Wishlist'));
const Plans = lazy(() => import('./pages/Plans'));
const PropertySubmission = lazy(() => import('./pages/PropertySubmission'));
const NotFound = lazy(() => import('./pages/NotFound'));
const PropertyDetailsPage = lazy(() => import('./pages/PropertyDetailsPage'));
const Terms = lazy(() => import('./pages/Terms'));
const Privacy = lazy(() => import('./pages/Privacy'));
const RefundPolicy = lazy(() => import('./pages/RefundPolicy'));
const DeliveryPolicy = lazy(() => import('./pages/DeliveryPolicy'));
const Profile = lazy(() => import('./pages/Profile'));
const Footer = lazy(() => import('./components/Footer'));
const Transactions = lazy(() => import('./pages/Transactions'));
const MyOccupiedProperties = lazy(() => import('./pages/MyOccupiedPropertiesPage'));
const MyListedProperties = lazy(() => import('./pages/MyListedProperties'));
const MyTicketsPage = lazy(() => import('./pages/MyTicketsPage'));
const CreateTicket = lazy(() => import('./pages/CreateTicket'));
const TicketDetailsPage = lazy(() => import('./pages/TicketDetailsPage'));
const MyPropertyDetailsPage = lazy(() => import('./pages/MyPropertyDetailsPage'));
const EditPropertyPage = lazy(() => import('./pages/EditPropertyPage'));
const AboutUs = lazy(() => import('./pages/AboutUs'));
const MyRentalApplicationsPage = lazy(() => import('./pages/MyRentalApplicationsPage'));
const MyRentalApplicationDetailsPage = lazy(() => import('./pages/MyRentalApplicationDetailsPage'));

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
    </>
  );
}


function App() {
  return (
      <Router>
        <AuthProvider>
          <ScrollToTop />
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