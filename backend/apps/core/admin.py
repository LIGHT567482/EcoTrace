from django.contrib import admin, messages
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.http import HttpResponseRedirect
from django.urls import reverse

from .models import Notification, User

SOLE_ADMIN_MESSAGE = (
    "This is the only active administrator. "
    "Enable or create another administrator first."
)


class LastAdminProtection(Exception):
    """Raised when an admin action would remove the last active administrator."""


def _another_active_admin(user):
    return User.objects.filter(
        role=User.Role.ADMIN, is_active=True
    ).exclude(pk=user.pk).exists()


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

    def save_model(self, request, obj, form, change):
        if change:
            previous = User.objects.filter(pk=obj.pk).first()
            if previous is not None:
                was_active_admin = (
                    previous.is_active and previous.role == User.Role.ADMIN
                )
                now_active_admin = obj.is_active and obj.role == User.Role.ADMIN
                if (
                    was_active_admin
                    and not now_active_admin
                    and not _another_active_admin(previous)
                ):
                    raise LastAdminProtection(SOLE_ADMIN_MESSAGE)
        super().save_model(request, obj, form, change)

    def delete_model(self, request, obj):
        if (
            obj.is_active
            and obj.role == User.Role.ADMIN
            and not _another_active_admin(obj)
        ):
            raise LastAdminProtection(SOLE_ADMIN_MESSAGE)
        super().delete_model(request, obj)

    def delete_queryset(self, request, queryset):
        doomed_admins = list(
            queryset.filter(role=User.Role.ADMIN, is_active=True).values_list(
                "pk", flat=True
            )
        )
        if doomed_admins and not User.objects.filter(
            role=User.Role.ADMIN, is_active=True
        ).exclude(pk__in=doomed_admins).exists():
            raise LastAdminProtection(SOLE_ADMIN_MESSAGE)
        super().delete_queryset(request, queryset)

    def changeform_view(self, request, object_id=None, form_url="", extra_context=None):
        try:
            return super().changeform_view(
                request, object_id, form_url, extra_context
            )
        except LastAdminProtection as exc:
            messages.error(request, str(exc))
            if object_id:
                return HttpResponseRedirect(
                    reverse("admin:core_user_change", args=[object_id])
                )
            return HttpResponseRedirect(reverse("admin:core_user_changelist"))

    def delete_view(self, request, object_id, extra_context=None):
        try:
            return super().delete_view(request, object_id, extra_context)
        except LastAdminProtection as exc:
            messages.error(request, str(exc))
            return HttpResponseRedirect(
                reverse("admin:core_user_change", args=[object_id])
            )

    def changelist_view(self, request, extra_context=None):
        try:
            return super().changelist_view(request, extra_context)
        except LastAdminProtection as exc:
            messages.error(request, str(exc))
            return HttpResponseRedirect(reverse("admin:core_user_changelist"))


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ("user", "title", "is_read", "created_at")
    list_filter = ("is_read",)
