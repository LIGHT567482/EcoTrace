from django.contrib import admin

from .models import Redemption, Wallet, WalletTransaction


@admin.register(Wallet)
class WalletAdmin(admin.ModelAdmin):
    list_display = ("user", "balance", "updated_at")
    search_fields = ("user__phone",)


@admin.register(WalletTransaction)
class WalletTransactionAdmin(admin.ModelAdmin):
    list_display = ("wallet", "kind", "amount", "balance_after", "reason", "created_at")
    list_filter = ("kind",)


@admin.register(Redemption)
class RedemptionAdmin(admin.ModelAdmin):
    list_display = ("user", "amount", "method", "destination", "status", "created_at")
    list_filter = ("status", "method")
