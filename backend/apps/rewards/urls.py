from django.urls import path
from rest_framework.routers import DefaultRouter

from .views import RedeemView, RedemptionViewSet, WalletStatsView, WalletView

router = DefaultRouter()
router.register("redemptions", RedemptionViewSet, basename="redemptions")

urlpatterns = [
    path("wallet/", WalletView.as_view(), name="wallet"),
    path("wallet/redeem/", RedeemView.as_view(), name="wallet_redeem"),
    path("wallet/stats/", WalletStatsView.as_view(), name="wallet_stats"),
] + router.urls
