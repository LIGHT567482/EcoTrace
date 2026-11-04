from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.http import JsonResponse
from django.urls import include, path


def health(_request):
    return JsonResponse({"status": "ok"})


urlpatterns = [
    path("health/", health),
    path("admin/", admin.site.urls),
    path("api/auth/", include("apps.core.auth_urls")),
    path("api/", include("apps.core.urls")),
    path("api/", include("apps.waste.urls")),
    path("api/", include("apps.rewards.urls")),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
