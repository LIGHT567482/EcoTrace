from django.contrib.auth import authenticate, get_user_model
from django.utils import timezone
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenObtainPairView

from .models import Notification, PasswordResetRequest
from .permissions import IsAdmin
from .serializers import (
    ChangePasswordSerializer,
    ConfirmPasswordResetSerializer,
    RegisterSerializer,
    RequestPasswordResetSerializer,
    UserSerializer,
)

User = get_user_model()


class PhoneTokenObtainPairView(TokenObtainPairView):
    def post(self, request, *args, **kwargs):
        phone = request.data.get("phone", "")
        password = request.data.get("password", "")
        user = authenticate(request, username=phone, password=password)
        if user is None:
            return Response(
                {"detail": "Invalid phone number or password."},
                status=status.HTTP_401_UNAUTHORIZED,
            )
        refresh = RefreshToken.for_user(user)
        return Response(
            {
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "user": UserSerializer(user).data,
            }
        )


class AdminTokenObtainPairView(APIView):
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "admin_login"

    def post(self, request):
        if not isinstance(request.data, dict):
            return self.invalid_credentials()
        phone = request.data.get("phone", "")
        password = request.data.get("password", "")
        if not isinstance(phone, str) or not isinstance(password, str):
            return self.invalid_credentials()
        user = authenticate(request, username=phone, password=password)
        if user is None or not (
            user.role == User.Role.ADMIN or user.is_superuser
        ):
            return self.invalid_credentials()
        refresh = RefreshToken.for_user(user)
        return Response(
            {
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "user": UserSerializer(user).data,
            }
        )

    @staticmethod
    def invalid_credentials():
        return Response(
            {"detail": "Invalid administrator credentials."},
            status=status.HTTP_401_UNAUTHORIZED,
        )


class RegisterView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        refresh = RefreshToken.for_user(user)
        return Response(
            {
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "user": UserSerializer(user).data,
            },
            status=status.HTTP_201_CREATED,
        )


class MeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(UserSerializer(request.user).data)

    def put(self, request):
        serializer = UserSerializer(request.user, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)

    patch = put


class ChangePasswordView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = ChangePasswordSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        if not request.user.check_password(serializer.validated_data["old_password"]):
            return Response(
                {"old_password": ["Current password is incorrect."]},
                status=status.HTTP_400_BAD_REQUEST,
            )
        request.user.set_password(serializer.validated_data["new_password"])
        request.user.save()
        # A password the owner just set makes outstanding reset codes stale.
        _burn_reset_codes(request.user)
        return Response({"detail": "Password changed."})


class RequestPasswordResetView(APIView):
    """Opens a reset request an administrator can relay a code from.

    The response never reveals whether the phone number has an account.
    """

    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "password_reset"

    def post(self, request):
        serializer = RequestPasswordResetSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = User.objects.filter(
            phone=serializer.validated_data["phone"], is_active=True
        ).first()
        if user is not None:
            PasswordResetRequest.objects.create(user=user)
            admins = User.objects.filter(
                role=User.Role.ADMIN, is_active=True
            ).exclude(pk=user.pk)
            Notification.objects.bulk_create(
                [
                    Notification(
                        user=admin,
                        title="Password reset requested",
                        body=(
                            f"{user.phone} asked for a password reset code. "
                            "Open Users to read the 6-digit code and share it "
                            "with them directly."
                        ),
                    )
                    for admin in admins
                ]
            )
        return Response(
            {
                "detail": (
                    "If this number matches an account, a reset request is now "
                    "waiting with your EcoTrace administrator. Ask them for the "
                    "6-digit code, then return here to choose a new password."
                )
            }
        )


class ConfirmPasswordResetView(APIView):
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "password_reset"

    def post(self, request):
        serializer = ConfirmPasswordResetSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        user = User.objects.filter(phone=data["phone"], is_active=True).first()
        pending = None
        if user is not None:
            pending = next(
                (
                    item
                    for item in user.password_reset_requests.all()[:5]
                    if item.is_pending
                ),
                None,
            )
        if pending is None or not pending.check_code(data["code"]):
            return Response(
                {
                    "code": [
                        "Invalid or expired reset code. Ask your administrator "
                        "for a new one."
                    ]
                },
                status=status.HTTP_400_BAD_REQUEST,
            )
        user.set_password(data["new_password"])
        user.save(update_fields=["password"])
        _burn_reset_codes(user)
        refresh = RefreshToken.for_user(user)
        return Response(
            {
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "user": UserSerializer(user).data,
            }
        )


class PasswordResetRequestListView(APIView):
    """Active reset requests with the code the administrator relays."""

    permission_classes = [IsAdmin]

    def get(self, request):
        cutoff = timezone.now() - PasswordResetRequest.CODE_TTL
        rows = [
            {
                "id": item.pk,
                "phone": item.user.phone,
                "user": item.user.full_name or item.user.phone,
                "role": item.user.role,
                "code": item.code,
                "requested_at": item.created_at,
                "expires_at": item.expires_at,
            }
            for item in PasswordResetRequest.objects.filter(
                consumed_at__isnull=True,
                created_at__gte=cutoff,
            ).select_related("user")
            if item.is_pending
        ]
        return Response(rows)


def _burn_reset_codes(user):
    PasswordResetRequest.objects.filter(user=user, consumed_at__isnull=True).update(
        consumed_at=timezone.now()
    )
