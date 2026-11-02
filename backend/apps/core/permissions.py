from django.contrib.auth import get_user_model
from rest_framework.permissions import BasePermission

User = get_user_model()


class IsAdmin(BasePermission):
    def has_permission(self, request, view):
        return bool(
            request.user.is_authenticated
            and (request.user.role == User.Role.ADMIN or request.user.is_superuser)
        )


class IsAdminOrRecycler(BasePermission):
    def has_permission(self, request, view):
        return bool(
            request.user.is_authenticated
            and (
                request.user.role in (User.Role.ADMIN, User.Role.RECYCLER)
                or request.user.is_superuser
            )
        )


class IsCollector(BasePermission):
    def has_permission(self, request, view):
        return bool(
            request.user.is_authenticated
            and request.user.role == User.Role.COLLECTOR
        )


class IsOwnerOrStaff(BasePermission):
    def has_object_permission(self, request, view, obj):
        owner = getattr(obj, "user", None) or getattr(obj, "consumer", None)
        if request.user.role in (
            User.Role.ADMIN,
            User.Role.COLLECTOR,
            User.Role.RECYCLER,
        ) or request.user.is_superuser:
            return True
        return owner == request.user
