from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin

from .models import Notification, User


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display = ("phone", "full_name", "role", "town", "is_active")
    list_filter = ("role", "is_active", "town")
    search_fields = ("phone", "full_name")
    ordering = ("-date_joined",)
    fieldsets = (
        (None, {"fields": ("phone", "password")}),
        ("Profile", {"fields": ("full_name", "role", "town", "address", "latitude", "longitude")}),
        ("Permissions", {"fields": ("is_active", "is_staff", "is_superuser", "groups")}),
        ("Dates", {"fields": ("last_login", "date_joined")}),
    )
    add_fieldsets = (
        (None, {"fields": ("phone", "full_name", "role", "password1", "password2")}),
    )


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ("user", "title", "is_read", "created_at")
    list_filter = ("is_read",)
