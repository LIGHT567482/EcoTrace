from rest_framework.routers import DefaultRouter

from .views import AuditLogViewSet, UserViewSet

router = DefaultRouter()
router.register("users", UserViewSet)
router.register("audit-logs", AuditLogViewSet, basename="audit-logs")

urlpatterns = router.urls
