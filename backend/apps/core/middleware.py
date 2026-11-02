from django.contrib.auth import get_user_model

from .models import AuditLog


class AuditLogMiddleware:
    audited_methods = {"GET", "POST", "PUT", "PATCH", "DELETE"}

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        response = self.get_response(request)
        path = request.path_info
        is_api = path.startswith("/api/")
        is_django_admin = path.startswith("/admin/")
        if not is_api and not is_django_admin:
            return response
        if path.startswith("/api/audit-logs/"):
            return response
        if (
            request.method == "GET"
            and path == "/api/auth/notifications/"
            and request.GET.get("background") == "1"
        ):
            return response
        if request.method not in self.audited_methods:
            return response

        actor = self._get_actor(request, response)
        AuditLog.objects.create(
            actor=actor,
            action=f"{request.method} {path}",
            method=request.method,
            path=path,
            status_code=response.status_code,
        )
        return response

    @staticmethod
    def _get_actor(request, response):
        user = getattr(request, "user", None)
        if user is not None and user.is_authenticated:
            return user

        response_data = getattr(response, "data", None)
        user_data = response_data.get("user") if isinstance(response_data, dict) else None
        user_id = user_data.get("id") if isinstance(user_data, dict) else None
        if user_id is None:
            return None

        return get_user_model().objects.filter(pk=user_id).first()
