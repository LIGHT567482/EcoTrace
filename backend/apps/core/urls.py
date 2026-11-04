from django.urls import path
from rest_framework.routers import DefaultRouter

from .views import (
	AuditLogViewSet,
	StakeholderContactsView,
	StakeholderMessageListCreateView,
	StakeholderMessageReadView,
	UserViewSet,
)

router = DefaultRouter()
router.register("users", UserViewSet)
router.register("audit-logs", AuditLogViewSet, basename="audit-logs")

urlpatterns = router.urls + [
	path("messages/contacts/", StakeholderContactsView.as_view(), name="message_contacts"),
	path("messages/", StakeholderMessageListCreateView.as_view(), name="messages"),
	path("messages/<int:pk>/read/", StakeholderMessageReadView.as_view(), name="message_read"),
]
