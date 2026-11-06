from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.db import connection
from django.http import JsonResponse
from django.urls import include, path


def health(_request):
    """Liveness probe that also proves the database is reachable.

    A 200 means the API and the database are both answering, so clients
    (mobile offline queue, web, Render health checks) only go "online"
    when requests can actually be served.
    """
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            cursor.fetchone()
    except Exception:
        return JsonResponse(
            {"status": "error", "database": "unreachable"}, status=503
        )
    return JsonResponse({"status": "ok", "database": "up"})


urlpatterns = [
    path("", health),
    path("health/", health),
    path("api/health/", health),
    path("admin/", admin.site.urls),
    path("api/auth/", include("apps.core.auth_urls")),
    path("api/", include("apps.core.urls")),
    path("api/", include("apps.waste.urls")),
    path("api/", include("apps.rewards.urls")),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
