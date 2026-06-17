import type React from "react";
import { createContext, useContext, useState, useCallback } from "react";
import { IconAlertTriangle, IconCheck, IconInfoCircle, IconX } from "@tabler/icons-react";

type NotificationType = "success" | "error" | "info" | "warning";

interface Notification {
  id: string;
  type: NotificationType;
  title: string;
  message?: string;
}

interface NotificationContextType {
  notifications: Notification[];
  showNotification: (type: NotificationType, title: string, message?: string) => void;
  dismissNotification: (id: string) => void;
  showSuccessNotification: (title: string, message?: string) => void;
  showErrorNotification: (title: string, message?: string) => void;
  showWarningNotification: (title: string, message?: string) => void;
  showInfoNotification: (title: string, message?: string) => void;
}

const NotificationContext = createContext<NotificationContextType | undefined>(undefined);

export function NotificationProvider({ children }: { children: React.ReactNode }) {
  const [notifications, setNotifications] = useState<Notification[]>([]);

  const dismissNotification = useCallback((id: string) => {
    setNotifications((prev) => prev.filter((notification) => notification.id !== id));
  }, []);

  const showNotification = useCallback((type: NotificationType, title: string, message?: string) => {
    const id = Math.random().toString(36).substring(2, 9);
    setNotifications((prev) => [...prev, { id, type, title, message }]);

    // Auto-dismiss after 5 seconds
    setTimeout(() => {
      dismissNotification(id);
    }, 5000);

    return id;

  }, [dismissNotification]);


  // Helper functions
  const showSuccessNotification = useCallback((title: string, message?: string) => {
    showNotification('success', title, message);
  }, [showNotification]);

  const showErrorNotification = useCallback((title: string, message?: string) => {
    showNotification('error', title, message);
  }, [showNotification]);

  const showWarningNotification = useCallback((title: string, message?: string) => {
    showNotification('warning', title, message);
  }, [showNotification]);

  const showInfoNotification = useCallback((title: string, message?: string) => {
    showNotification('info', title, message);
  }, [showNotification]);


  return (
    <NotificationContext.Provider value={{ notifications, showNotification, dismissNotification, showSuccessNotification, showErrorNotification, showWarningNotification, showInfoNotification }}>
      {children}
      <NotificationOverlay />
    </NotificationContext.Provider>
  );
}

export function useNotification() {
  const context = useContext(NotificationContext);
  if (context === undefined) {
    throw new Error("useNotification must be used within a NotificationProvider");
  }
  return context;
}

function NotificationOverlay() {
  const { notifications, dismissNotification } = useNotification();

  if (notifications.length === 0) return null;

  return (
    <div className="fixed top-4 right-4 z-[100] flex flex-col gap-2">
      {notifications.map((notification) => (
        <div
          key={notification.id}
          className={`flex items-start gap-3 rounded-lg p-4 shadow-lg transition-all duration-300 animate-in fade-in slide-in-from-top-5 w-80 border bg-[#2563EB] text-white `}
        >
          <div className="flex-shrink-0">
            {notification.type === "success" && (
              <div className="rounded-full bg-[#2563EB] p-1">
                <IconCheck className="h-5 w-5 text-white" />
              </div>
            )}
            {notification.type === "error" && (
              <div className="rounded-full bg-gray-100 p-1">
                <IconX className="h-5 w-5 text-gray-600" />
              </div>
            )}
            {notification.type === "warning" && (
              <div className="rounded-full bg-gray-100 p-1">
                <IconAlertTriangle className="h-5 w-5 text-gray-600" />
              </div>
            )}
            {notification.type === "info" && (
              <div className="rounded-full bg-gray-100 p-1">
                <IconInfoCircle className="h-5 w-5 text-gray-600" />
              </div>
            )}
          </div>
          <div className="flex-1">
            {/* --- Text Color Adjustments --- */}
            <h3 className={'font-medium text-white'}>{notification.title}</h3>
            {notification.message && <p className={`mt-1 text-sm text-white/80`}>{notification.message}</p>}
          </div>
          <button
            onClick={() => dismissNotification(notification.id)}
            className={`ml-auto -mx-1.5 -my-1.5 flex-shrink-0 rounded-md p-1.5 inline-flex h-8 w-8 text-white/70 hover:text-white hover:bg-white/10 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-white/50`}>
            <span className="sr-only">Dismiss</span>
            <IconX className="h-5 w-5" />
          </button>
        </div>
      ))}
    </div>
  );
}