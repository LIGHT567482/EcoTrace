from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView

from .auth_views import (
    ChangePasswordView,
    AdminTokenObtainPairView,
    MeView,
    PhoneTokenObtainPairView,
    RegisterView,
)
from .views import (
    NotificationListView,
    clear_notifications,
    delete_notification,
    mark_all_read,
    mark_read,
)

urlpatterns = [
    path("admin/token/", AdminTokenObtainPairView.as_view(), name="admin_token_obtain"),
    path("token/", PhoneTokenObtainPairView.as_view(), name="token_obtain"),
    path(
        "token/refresh/",
        TokenRefreshView.as_view(),
        name="token_refresh",
    ),
    path("register/", RegisterView.as_view(), name="register"),
    path("me/", MeView.as_view(), name="me"),
    path("change-password/", ChangePasswordView.as_view(), name="change_password"),
    path("notifications/", NotificationListView.as_view(), name="notifications"),
    path("notifications/<int:pk>/read/", mark_read, name="notification_read"),
    path("notifications/<int:pk>/", delete_notification, name="notification_delete"),
    path("notifications/read-all/", mark_all_read, name="notifications_read_all"),
    path("notifications/clear/", clear_notifications, name="notifications_clear"),
]
