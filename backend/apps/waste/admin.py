from django.contrib import admin

from .models import (
    Category,
    Certificate,
    CollectionRequest,
    DropOffPoint,
    Item,
    ItemType,
    ProcessingRecord,
    RequestEvent,
)


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ("name", "slug", "is_active")
    prepopulated_fields = {"slug": ("name",)}


@admin.register(ItemType)
class ItemTypeAdmin(admin.ModelAdmin):
    list_display = ("name", "category", "reward_ugx", "is_active")
    list_filter = ("category", "is_active")


@admin.register(Item)
class ItemAdmin(admin.ModelAdmin):
    list_display = ("consumer", "item_type", "quantity", "condition", "created_at")
    list_filter = ("condition", "item_type__category")


class RequestEventInline(admin.TabularInline):
    model = RequestEvent
    extra = 0
    readonly_fields = ("status", "note", "actor", "created_at")


@admin.register(CollectionRequest)
class CollectionRequestAdmin(admin.ModelAdmin):
    list_display = (
        "reference",
        "consumer",
        "request_type",
        "status",
        "assigned_collector",
        "created_at",
    )
    list_filter = ("status", "request_type", "created_at")
    search_fields = ("reference", "consumer__phone", "consumer__full_name")
    inlines = [RequestEventInline]


@admin.register(DropOffPoint)
class DropOffPointAdmin(admin.ModelAdmin):
    list_display = ("name", "town", "address", "is_active")
    list_filter = ("town", "is_active")


@admin.register(Certificate)
class CertificateAdmin(admin.ModelAdmin):
    list_display = ("code", "issued_to", "summary", "issued_at")
    search_fields = ("code",)


@admin.register(ProcessingRecord)
class ProcessingRecordAdmin(admin.ModelAdmin):
    list_display = ("request", "recycler", "items_expected", "items_received", "method", "processed_at")
