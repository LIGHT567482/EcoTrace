# EcoTrace - Web App

React 19 + Vite single-page app for EcoTrace (see the [root README](../README.md) for the full system).

After sign-in or registration, users land on `/`, which shows the home dashboard for their role: consumers see disposal, rewards and carbon analytics; collectors see assigned and available pickup metrics; recyclers see incoming and processed shipment metrics; and administrators see the system reports dashboard.

On small screens, the navigation collapses behind a top-right menu button. Dashboard summary tiles remain in two columns on narrow screens.

Notifications expand to show details and request links. Users can mark them read, delete them individually, or clear all notifications.

```bash
npm install
npm run dev        # http://localhost:5173
npm run build      # production build → dist/
npm run lint       # oxlint
```

Talks to the Django API at `VITE_API_URL` (default `http://localhost:8000/api`). The logo used in the header, footer, sidebar, auth card and landing page is `public/bg.png`; the browser favicon is `public/favicon.png` (circular "e" mark cropped from the same logo).
