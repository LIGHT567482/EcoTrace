import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { createBrowserRouter, Navigate, RouterProvider } from "react-router-dom";
import "./styles.css";
import { AuthProvider, useAuth } from "./auth";
import Layout from "./components/Layout";
import Landing from "./pages/Landing";
import RolesPage from "./pages/RolesPage";
import ImpactPage from "./pages/ImpactPage";
import MapPage from "./pages/MapPage";
import AuthPage from "./pages/AuthPage";
import AdminLoginPage from "./pages/AdminLoginPage";
import ItemsPage from "./pages/consumer/ItemsPage";
import NewRequestPage from "./pages/consumer/NewRequestPage";
import RequestsPage from "./pages/RequestsPage";
import RequestDetailPage from "./pages/RequestDetailPage";
import WalletPage from "./pages/consumer/WalletPage";
import DropOffsPage from "./pages/DropOffsPage";
import NotificationsPage from "./pages/NotificationsPage";
import CollectorTasks from "./pages/collector/CollectorTasks";
import CollectorAvailable from "./pages/collector/CollectorAvailable";
import RecyclerIncoming from "./pages/recycler/RecyclerIncoming";
import AdminDashboard from "./pages/admin/AdminDashboard";
import AdminHomeDashboard from "./pages/admin/AdminHomeDashboard";
import HomeDashboard from "./pages/HomeDashboard";
import UsersPage from "./pages/admin/UsersPage";
import RedemptionsPage from "./pages/admin/RedemptionsPage";
import CategoriesPage from "./pages/admin/CategoriesPage";
import AuditTrailPage from "./pages/admin/AuditTrailPage";

function Home() {
  const { user, loading } = useAuth();
  if (loading) return <div className="center-page">Loading…</div>;
  if (!user) return <Landing />;
  if (user.role === "ADMIN") return <AdminHomeDashboard />;
  return <HomeDashboard />;
}

function Protected({ children, roles, loginPath = "/login" }) {
  const { user, loading } = useAuth();
  if (loading) return <div className="center-page">Loading…</div>;
  if (!user) return <Navigate to={loginPath} replace />;
  if (roles && !roles.includes(user.role)) return <Navigate to="/" replace />;
  return children;
}

const router = createBrowserRouter([
  {
    element: <Layout />,
    children: [
      { path: "/", element: <Home /> },
      { path: "/roles", element: <RolesPage /> },
      { path: "/impact", element: <ImpactPage /> },
      { path: "/login", element: <AuthPage /> },
      { path: "/register", element: <AuthPage /> },
      { path: "/admin/login", element: <AdminLoginPage /> },
      {
        path: "/items",
        element: (
          <Protected roles={["CONSUMER"]}>
            <ItemsPage />
          </Protected>
        ),
      },
      {
        path: "/requests/new",
        element: (
          <Protected roles={["CONSUMER"]}>
            <NewRequestPage />
          </Protected>
        ),
      },
      { path: "/requests", element: <RequestsPage /> },
      { path: "/requests/:id", element: <RequestDetailPage /> },
      {
        path: "/wallet",
        element: (
          <Protected roles={["CONSUMER"]}>
            <WalletPage />
          </Protected>
        ),
      },
      { path: "/dropoffs", element: <DropOffsPage /> },
      { path: "/map", element: <MapPage /> },
      {
        path: "/notifications",
        element: (
          <Protected>
            <NotificationsPage />
          </Protected>
        ),
      },
      {
        path: "/tasks",
        element: (
          <Protected roles={["COLLECTOR"]}>
            <CollectorTasks />
          </Protected>
        ),
      },
      {
        path: "/available",
        element: (
          <Protected roles={["COLLECTOR"]}>
            <CollectorAvailable />
          </Protected>
        ),
      },
      {
        path: "/incoming",
        element: (
          <Protected roles={["RECYCLER", "ADMIN"]}>
            <RecyclerIncoming />
          </Protected>
        ),
      },
      {
        path: "/admin",
        element: (
          <Protected roles={["ADMIN"]} loginPath="/admin/login">
            <AdminDashboard />
          </Protected>
        ),
      },
      {
        path: "/users",
        element: (
          <Protected roles={["ADMIN"]} loginPath="/admin/login">
            <UsersPage />
          </Protected>
        ),
      },
      {
        path: "/redemptions",
        element: (
          <Protected roles={["ADMIN"]} loginPath="/admin/login">
            <RedemptionsPage />
          </Protected>
        ),
      },
      {
        path: "/categories",
        element: (
          <Protected roles={["ADMIN"]} loginPath="/admin/login">
            <CategoriesPage />
          </Protected>
        ),
      },
      {
        path: "/audit",
        element: (
          <Protected roles={["ADMIN"]} loginPath="/admin/login">
            <AuditTrailPage />
          </Protected>
        ),
      },
      { path: "*", element: <Navigate to="/" replace /> },
    ],
  },
]);

createRoot(document.getElementById("root")).render(
  <StrictMode>
    <AuthProvider>
      <RouterProvider router={router} />
    </AuthProvider>
  </StrictMode>
);
