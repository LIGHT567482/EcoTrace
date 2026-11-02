from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.test import APIClient

from .models import AuditLog, Notification

User = get_user_model()


class NotificationAPITests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            phone="+256700111021",
            password="StrongPass123!",
            full_name="Notification user",
        )
        self.other_user = User.objects.create_user(
            phone="+256700111022",
            password="StrongPass123!",
            full_name="Another user",
        )
        self.client.force_authenticate(user=self.user)

    def test_notification_includes_linked_request_id(self):
        notification = Notification.objects.create(
            user=self.user,
            request_id=123,
            title="Request update",
            body="Your request has been updated.",
        )

        response = self.client.get("/api/auth/notifications/")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["results"][0]["id"], notification.id)
        self.assertEqual(response.data["results"][0]["request_id"], 123)

    def test_notification_can_be_deleted_only_by_its_owner(self):
        notification = Notification.objects.create(
            user=self.other_user,
            title="Private notification",
        )

        response = self.client.delete(f"/api/auth/notifications/{notification.id}/")

        self.assertEqual(response.status_code, 404)
        self.assertTrue(Notification.objects.filter(pk=notification.id).exists())

    def test_user_can_delete_their_notification(self):
        notification = Notification.objects.create(
            user=self.user,
            title="Delete me",
        )

        response = self.client.delete(f"/api/auth/notifications/{notification.id}/")

        self.assertEqual(response.status_code, 204)
        self.assertFalse(Notification.objects.filter(pk=notification.id).exists())

    def test_clear_notifications_deletes_only_current_users_notifications(self):
        Notification.objects.create(user=self.user, title="Mine")
        other_notification = Notification.objects.create(
            user=self.other_user,
            title="Not mine",
        )

        response = self.client.delete("/api/auth/notifications/clear/")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["deleted"], 1)
        self.assertTrue(Notification.objects.filter(pk=other_notification.id).exists())


class AdminAuthenticationTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.admin = User.objects.create_user(
            phone="+256700111030",
            password="SecureAdminPass123!",
            full_name="Admin account",
            role=User.Role.ADMIN,
            is_staff=True,
        )
        self.consumer = User.objects.create_user(
            phone="+256700111031",
            password="ConsumerPass123!",
            full_name="Consumer account",
        )

    def test_admin_can_sign_in_through_admin_endpoint(self):
        response = self.client.post(
            "/api/auth/admin/token/",
            {"phone": self.admin.phone, "password": "SecureAdminPass123!"},
            format="json",
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["user"]["role"], User.Role.ADMIN)
        self.assertIn("access", response.data)
        self.assertIn("refresh", response.data)
        self.assertTrue(
            AuditLog.objects.filter(
                actor=self.admin,
                method="POST",
                path="/api/auth/admin/token/",
                status_code=200,
            ).exists()
        )

    def test_non_admin_is_rejected_even_when_claiming_admin_role(self):
        response = self.client.post(
            "/api/auth/admin/token/",
            {
                "phone": self.consumer.phone,
                "password": "ConsumerPass123!",
                "role": User.Role.ADMIN,
            },
            format="json",
        )

        self.assertEqual(response.status_code, 401)
        self.assertEqual(response.data["detail"], "Invalid administrator credentials.")

    def test_invalid_credential_types_are_rejected(self):
        response = self.client.post(
            "/api/auth/admin/token/",
            {"phone": [], "password": "irrelevant"},
            format="json",
        )

        self.assertEqual(response.status_code, 401)
        self.assertEqual(response.data["detail"], "Invalid administrator credentials.")

    def test_admin_api_rejects_unauthenticated_and_non_admin_users(self):
        self.assertEqual(self.client.get("/api/users/").status_code, 401)

        self.client.force_authenticate(user=self.consumer)
        self.assertEqual(self.client.get("/api/users/").status_code, 403)

    def test_write_activity_is_recorded_and_admin_can_search_audit_log(self):
        self.client.force_authenticate(user=self.consumer)
        read_response = self.client.get("/api/auth/me/")
        self.assertEqual(read_response.status_code, 200)
        self.assertTrue(
            AuditLog.objects.filter(
                actor=self.consumer,
                method="GET",
                path="/api/auth/me/",
                status_code=200,
            ).exists()
        )

        response = self.client.post("/api/auth/notifications/read-all/")
        self.assertEqual(response.status_code, 200)

        log_entry = AuditLog.objects.get(
            actor=self.consumer,
            method="POST",
            path="/api/auth/notifications/read-all/",
        )
        self.assertEqual(log_entry.status_code, 200)
        self.assertEqual(self.client.get("/api/audit-logs/").status_code, 403)

        self.client.force_authenticate(user=self.admin)
        response = self.client.get("/api/audit-logs/?q=Consumer+account")
        self.assertEqual(response.status_code, 200)
        self.assertGreaterEqual(response.data["count"], 2)
        self.assertTrue(
            any(entry["id"] == log_entry.id for entry in response.data["results"])
        )
