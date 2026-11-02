from django.urls import path
from rest_framework.routers import DefaultRouter

from .views import (
    CancelRequestView,
    CategoryViewSet,
    ClaimRequestView,
    DropOffPointViewSet,
    ItemViewSet,
    ItemTypeViewSet,
    ProcessRequestView,
    ReceiveRequestView,
    RejectRequestView,
    ReleaseRequestView,
    RequestCreateView,
    RequestDetailView,
    RequestListView,
    StatsView,
    TransitionRequestView,
)

router = DefaultRouter()
router.register("categories", CategoryViewSet, basename="categories")
router.register("item-types", ItemTypeViewSet, basename="item-types")
router.register("dropoff-points", DropOffPointViewSet, basename="dropoff-points")
router.register("items", ItemViewSet, basename="items")

urlpatterns = [
    path("requests/", RequestCreateView.as_view(), name="request_create"),
    path("requests/list/", RequestListView.as_view(), name="request_list"),
    path("requests/<int:pk>/", RequestDetailView.as_view(), name="request_detail"),
    path("requests/<int:pk>/claim/", ClaimRequestView.as_view(), name="request_claim"),
    path("requests/<int:pk>/release/", ReleaseRequestView.as_view(), name="request_release"),
    path("requests/<int:pk>/transition/", TransitionRequestView.as_view(), name="request_transition"),
    path("requests/<int:pk>/cancel/", CancelRequestView.as_view(), name="request_cancel"),
    path("requests/<int:pk>/receive/", ReceiveRequestView.as_view(), name="request_receive"),
    path("requests/<int:pk>/process/", ProcessRequestView.as_view(), name="request_process"),
    path("requests/<int:pk>/reject/", RejectRequestView.as_view(), name="request_reject"),
    path("reports/summary/", StatsView.as_view(), name="reports_summary"),
] + router.urls
