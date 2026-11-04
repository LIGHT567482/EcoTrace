from django.contrib.auth import get_user_model
from django.db.models import Q
from rest_framework import status, viewsets
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .permissions import IsAdmin
from .models import AuditLog, Notification, StakeholderMessage
from .serializers import (
    AdminUserSerializer,
    AuditLogSerializer,
    CreateStakeholderMessageSerializer,
    NotificationSerializer,
    StakeholderContactSerializer,
    StakeholderMessageSerializer,
    UserSerializer,
)

User = get_user_model()

MESSAGE_ROLES = {
    User.Role.CONSUMER: (User.Role.COLLECTOR,),
    User.Role.COLLECTOR: (User.Role.CONSUMER, User.Role.RECYCLER),
    User.Role.RECYCLER: (User.Role.COLLECTOR, User.Role.ADMIN),
    User.Role.ADMIN: (User.Role.RECYCLER,),
}


def get_message_contacts(user):
    contacts = User.objects.filter(
        is_active=True, role__in=MESSAGE_ROLES.get(user.role, ())
    ).exclude(pk=user.pk)
    if user.role in (User.Role.CONSUMER, User.Role.COLLECTOR):
        contacts = contacts.filter(town__iexact=user.town)
    elif user.role == User.Role.RECYCLER:
        contacts = contacts.filter(
            Q(role=User.Role.ADMIN) | Q(town__iexact=user.town)
        )
    return contacts.order_by("full_name", "phone")


class StakeholderContactsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(
            StakeholderContactSerializer(
                get_message_contacts(request.user), many=True
            ).data
        )


class StakeholderMessageListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        messages = StakeholderMessage.objects.filter(
            Q(sender=request.user) | Q(recipient=request.user)
        ).select_related("sender", "recipient")
        contact_id = request.query_params.get("with")
        if contact_id:
            if not get_message_contacts(request.user).filter(pk=contact_id).exists():
                return Response(status=status.HTTP_404_NOT_FOUND)
            messages = messages.filter(
                Q(sender=request.user, recipient_id=contact_id)
                | Q(sender_id=contact_id, recipient=request.user)
            )
        messages.filter(recipient=request.user, is_read=False).update(is_read=True)
        results = list(messages.order_by("-created_at", "-id")[:100])
        results.reverse()
        return Response({"results": StakeholderMessageSerializer(results, many=True).data})

    def post(self, request):
        input_serializer = CreateStakeholderMessageSerializer(data=request.data)
        input_serializer.is_valid(raise_exception=True)
        recipient = get_message_contacts(request.user).filter(
            pk=input_serializer.validated_data["recipient_id"]
        ).first()
        if recipient is None:
            return Response(
                {"recipient_id": ["You can only message an active stakeholder in your hierarchy and town."]},
                status=status.HTTP_400_BAD_REQUEST,
            )
        message = StakeholderMessage.objects.create(
            sender=request.user,
            recipient=recipient,
            body=input_serializer.validated_data["body"],
        )
        Notification.objects.create(
            user=recipient,
            title=f"Message from {request.user.full_name or request.user.phone}",
            body=message.body,
        )
        return Response(
            StakeholderMessageSerializer(message).data,
            status=status.HTTP_201_CREATED,
        )


class StakeholderMessageReadView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        message = StakeholderMessage.objects.filter(
            pk=pk, recipient=request.user
        ).first()
        if message is None:
            return Response(status=status.HTTP_404_NOT_FOUND)
        if not message.is_read:
            message.is_read = True
            message.save(update_fields=["is_read"])
        return Response(StakeholderMessageSerializer(message).data)


class UserViewSet(viewsets.ModelViewSet):
    queryset = User.objects.all().order_by("-date_joined")
    permission_classes = [IsAdmin]

    def get_queryset(self):
        queryset = super().get_queryset()
        search = self.request.query_params.get("q", "").strip()
        role = self.request.query_params.get("role")
        active = self.request.query_params.get("active")
        if search:
            queryset = queryset.filter(
                Q(full_name__icontains=search)
                | Q(phone__icontains=search)
                | Q(town__icontains=search)
            )
        if role:
            queryset = queryset.filter(role=role)
        if active in ("true", "false"):
            queryset = queryset.filter(is_active=active == "true")
        return queryset

    def get_serializer_class(self):
        if self.action in ("create", "update", "partial_update"):
            return AdminUserSerializer
        return UserSerializer

    def create(self, request, *args, **kwargs):
        serializer = AdminUserSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        password = request.data.get("password")
        if not password:
            return Response(
                {"password": ["This field is required."]},
                status=status.HTTP_400_BAD_REQUEST,
            )
        user = User.objects.create_user(
            phone=serializer.validated_data["phone"],
            password=password,
            full_name=serializer.validated_data.get("full_name", ""),
            role=serializer.validated_data.get("role", User.Role.CONSUMER),
            town=serializer.validated_data.get("town", "Kansanga"),
            address=serializer.validated_data.get("address", ""),
            is_active=serializer.validated_data.get("is_active", True),
        )
        return Response(UserSerializer(user).data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=["post"], url_path="toggle-active")
    def toggle_active(self, request, pk=None):
        user = self.get_object()
        user.is_active = not user.is_active
        user.save(update_fields=["is_active"])
        return Response(UserSerializer(user).data)


class AuditLogViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = AuditLogSerializer
    permission_classes = [IsAdmin]
    queryset = AuditLog.objects.select_related("actor").all()

    def get_queryset(self):
        queryset = super().get_queryset()
        search = self.request.query_params.get("q", "").strip()
        method = self.request.query_params.get("method")
        status_code = self.request.query_params.get("status")
        date_from = self.request.query_params.get("from")
        date_to = self.request.query_params.get("to")
        if search:
            queryset = queryset.filter(
                Q(action__icontains=search)
                | Q(path__icontains=search)
                | Q(actor__full_name__icontains=search)
                | Q(actor__phone__icontains=search)
            )
        if method:
            queryset = queryset.filter(method=method.upper())
        if status_code:
            queryset = queryset.filter(status_code=status_code)
        if date_from:
            queryset = queryset.filter(created_at__date__gte=date_from)
        if date_to:
            queryset = queryset.filter(created_at__date__lte=date_to)
        return queryset


class NotificationListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        qs = request.user.notifications.all()[:50]
        data = NotificationSerializer(qs, many=True).data
        unread = request.user.notifications.filter(is_read=False).count()
        return Response({"count": unread, "results": data})


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def mark_read(request, pk):
    notification = Notification.objects.filter(pk=pk, user=request.user).first()
    if notification is None:
        return Response(status=status.HTTP_404_NOT_FOUND)
    notification.is_read = True
    notification.save(update_fields=["is_read"])
    return Response(NotificationSerializer(notification).data)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def mark_all_read(request):
    updated = request.user.notifications.filter(is_read=False).update(is_read=True)
    return Response({"updated": updated})


@api_view(["DELETE"])
@permission_classes([IsAuthenticated])
def delete_notification(request, pk):
    deleted, _ = request.user.notifications.filter(pk=pk).delete()
    if not deleted:
        return Response(status=status.HTTP_404_NOT_FOUND)
    return Response(status=status.HTTP_204_NO_CONTENT)


@api_view(["DELETE"])
@permission_classes([IsAuthenticated])
def clear_notifications(request):
    deleted, _ = request.user.notifications.all().delete()
    return Response({"deleted": deleted})
