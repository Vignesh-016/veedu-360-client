import { Link } from "react-router-dom";
import {
  IconBrandFacebook,
  IconBrandInstagram,
  IconBrandLinkedin,
  IconBrandX,
  IconMail,
  IconMapPin,
  IconPhone,
  IconArrowRight
} from "@tabler/icons-react";

const Footer = () => {
  const companyName = import.meta.env.VITE_COMPANY_NAME || 'Veedu360';
  const contactAddress = import.meta.env.VITE_CONTACT_ADDRESS || '233 Pothigai Nagar, Perumalpuram, Tirunelveli - 627007';
  const contactPhone = import.meta.env.VITE_CONTACT_PHONE || '+91 74186 99622';
  const contactEmail = import.meta.env.VITE_CONTACT_EMAIL || 'admin@veedu360.com';
  const copyrightYear = import.meta.env.VITE_COPYRIGHT_YEAR || '2025';

  return (
    <footer className="bg-slate-900 text-slate-300 font-sans border-t border-slate-800">
      {/* Main Footer Content */}
      <div className="container max-w-7xl mx-auto px-6 py-16">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-12">

          {/* Column 1: Brand & Newsletter */}
          <div className="space-y-6">
            <div>
              <h3 className="text-2xl font-bold text-white mb-2 tracking-tight">{companyName}</h3>
              <p className="text-sm leading-relaxed text-slate-400">
                Your trusted property management platform connecting buyers, sellers, and renters with verified properties.
              </p>
            </div>

            {/* Newsletter (Visual Only) */}
            <div className="pt-2">
              <h4 className="text-xs font-bold text-white uppercase tracking-wider mb-3">Newsletter</h4>
              <div className="flex">
                <input
                  type="email"
                  placeholder="Enter your email"
                  className="bg-slate-800 text-white text-sm px-4 py-2.5 rounded-l-md focus:outline-none focus:ring-1 focus:ring-[#2C4964] w-full border border-slate-700 placeholder-slate-500"
                />
                <button className="bg-[#2C4964] hover:bg-[#1E3347] text-white px-3 rounded-r-md transition-colors">
                  <IconArrowRight size={18} />
                </button>
              </div>
            </div>

            <div className="flex gap-4 pt-2">
              {[IconBrandFacebook, IconBrandX, IconBrandInstagram, IconBrandLinkedin].map((Icon, idx) => (
                <a key={idx} href="#" className="bg-slate-800 p-2 rounded-full text-slate-400 hover:text-white hover:bg-[#2C4964] transition-all duration-300">
                  <Icon size={18} />
                </a>
              ))}
            </div>
          </div>

          {/* Column 2: Quick Links */}
          <div>
            <h3 className="text-white font-bold mb-6 text-sm uppercase tracking-wider">Quick Links</h3>
            <ul className="space-y-3 text-sm">
              <li><Link to="/" className="hover:text-white hover:translate-x-1 transition-all inline-block duration-200">Home</Link></li>
              <li><Link to="/catalogue" className="hover:text-white hover:translate-x-1 transition-all inline-block duration-200">Properties</Link></li>
              <li><Link to="/plans" className="hover:text-white hover:translate-x-1 transition-all inline-block duration-200">Visit Plans</Link></li>
              <li><Link to="/submit-property" className="hover:text-white hover:translate-x-1 transition-all inline-block duration-200">Post Property</Link></li>
              <li><Link to="/about" className="hover:text-white hover:translate-x-1 transition-all inline-block duration-200">About Us</Link></li>
            </ul>
          </div>

          {/* Column 3: Property Types */}
          <div>
            <h3 className="text-white font-bold mb-6 text-sm uppercase tracking-wider">Property Types</h3>
            <ul className="space-y-3 text-sm">
              <li><Link to="/catalogue?p_listing_types=SALE&p_property_types=HOUSE&p_house_types=APARTMENT_FLAT" className="hover:text-white hover:translate-x-1 transition-all inline-block duration-200">Apartments for Sale</Link></li>
              <li><Link to="/catalogue?p_listing_types=SALE&p_property_types=HOUSE" className="hover:text-white hover:translate-x-1 transition-all inline-block duration-200">Houses for Sale</Link></li>
              <li><Link to="/catalogue?p_listing_types=SALE&p_property_types=HOUSE&house_types=INDEPENDENT_VILLA" className="hover:text-white hover:translate-x-1 transition-all inline-block duration-200">Villas for Sale</Link></li>
              <li><Link to="/catalogue?p_listing_types=SALE&p_property_types=BUILDING" className="hover:text-white hover:translate-x-1 transition-all inline-block duration-200">Commercial for Sale</Link></li>
              <li><Link to="/catalogue?p_listing_types=SALE&p_property_types=LAND" className="hover:text-white hover:translate-x-1 transition-all inline-block duration-200">Plots for Sale</Link></li>
            </ul>
          </div>

          {/* Column 4: Contact Info */}
          <div>
            <h3 className="text-white font-bold mb-6 text-sm uppercase tracking-wider">Get in Touch</h3>
            <ul className="space-y-4 text-sm">
              <li className="flex items-start gap-3">
                <IconMapPin size={20} className="mt-0.5 text-[#D9A619] shrink-0" />
                <span className="leading-relaxed">{contactAddress}</span>
              </li>
              <li className="flex items-center gap-3">
                <div className="bg-slate-800 p-2 rounded-lg">
                  <IconPhone size={18} className="text-[#D9A619]" />
                </div>
                <span className="text-white">{contactPhone}</span>
              </li>
              <li className="flex items-center gap-3">
                <div className="bg-slate-800 p-2 rounded-lg">
                  <IconMail size={18} className="text-[#D9A619]" />
                </div>
                <span className="text-white">{contactEmail}</span>
              </li>
            </ul>
          </div>
        </div>
      </div>

      {/* Footer Bottom Bar */}
      <div className="bg-slate-950 py-6 border-t border-slate-800">
        <div className="container max-w-7xl mx-auto px-6">
          <div className="flex flex-col md:flex-row justify-between items-center gap-4 text-xs text-slate-300">
            <p>
              © {copyrightYear} <span className="text-white font-semibold">{companyName}</span>. All rights reserved.
            </p>
            <div className="flex gap-6">
              <Link to="/terms" className="hover:text-white transition-colors">Terms of Service</Link>
              <Link to="/privacy" className="hover:text-white transition-colors">Privacy Policy</Link>
              <Link to="/refund-policy" className="hover:text-white transition-colors">Refund Policy</Link>
              <Link to="/delivery-policy" className="hover:text-white transition-colors">Delivery Policy</Link>
            </div>
          </div>
        </div>
      </div>
    </footer>
  );
};

export default Footer;