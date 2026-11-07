import os
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.core.management import CommandError, call_command
from django.test import TestCase
from rest_framework.test import APIClient

from apps.rewards.models import Wallet, get_or_create_wallet
from apps.waste.models import (
    Category,
    CollectionRequest,
    DropOffPoint,
    Item,
    ItemType,
)

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


class StakeholderMessageTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.consumer = User.objects.create_user(
            phone="+256700222001", password="StrongPass123!", role=User.Role.CONSUMER,
            full_name="Consumer", town="Kansanga", address="Private address",
            latitude=0.3, longitude=32.6,
        )
        self.collector = User.objects.create_user(
            phone="+256700222002", password="StrongPass123!", role=User.Role.COLLECTOR,
            full_name="Collector", town="Kansanga",
        )
        self.recycler = User.objects.create_user(
            phone="+256700222003", password="StrongPass123!", role=User.Role.RECYCLER,
            full_name="Recycler", town="Makindye",
        )
        self.admin = User.objects.create_user(
            phone="+256700222004", password="StrongPass123!", role=User.Role.ADMIN,
            full_name="Admin", town="Kampala",
        )

    def test_hierarchy_messages_notify_recipients_without_exposing_private_contact_data(self):
        self.client.force_authenticate(user=self.consumer)
        contacts = self.client.get("/api/messages/contacts/")
        self.assertEqual(contacts.status_code, 200)
        self.assertEqual([contact["id"] for contact in contacts.data], [self.collector.id])
        self.assertNotIn("address", contacts.data[0])
        self.assertNotIn("latitude", contacts.data[0])

        response = self.client.post(
            "/api/messages/",
            {"recipient_id": self.collector.id, "body": "Pickup is ready."},
            format="json",
        )
        self.assertEqual(response.status_code, 201, response.content)
        self.assertTrue(
            Notification.objects.filter(
                user=self.collector,
                title="Message from Consumer",
                body="Pickup is ready.",
            ).exists()
        )
        response = self.client.post(
            "/api/messages/",
            {"recipient_id": self.admin.id, "body": "Skip the hierarchy"},
            format="json",
        )
        self.assertEqual(response.status_code, 400)

        self.client.force_authenticate(user=self.recycler)
        contacts = self.client.get("/api/messages/contacts/")
        self.assertEqual(
            {contact["id"] for contact in contacts.data}, {self.admin.id}
        )
        response = self.client.post(
            "/api/messages/",
            {"recipient_id": self.admin.id, "body": "Collection received."},
            format="json",
        )
        self.assertEqual(response.status_code, 201, response.content)


class AdminBootstrapTests(TestCase):
    @patch.dict(
        os.environ,
        {
            "ECOTRACE_ADMIN_PHONE": "+256700111050",
            "ECOTRACE_ADMIN_PASSWORD": "FirstRunAdminPass123!",
        },
    )
    def test_creates_admin_once_without_resetting_existing_password(self):
        call_command("bootstrap_admin")
        admin = User.objects.get(phone="+256700111050")
        self.assertEqual(admin.role, User.Role.ADMIN)
        self.assertTrue(admin.is_staff)
        self.assertTrue(admin.is_superuser)
        self.assertTrue(admin.check_password("FirstRunAdminPass123!"))

        admin.set_password("ChangedAdminPass123!")
        admin.save(update_fields=["password"])
        call_command("bootstrap_admin")
        admin.refresh_from_db()

        self.assertTrue(admin.check_password("ChangedAdminPass123!"))

    @patch.dict(
        os.environ,
        {
            "ECOTRACE_ADMIN_PHONE": "+256700111051",
            "ECOTRACE_ADMIN_PASSWORD": "FirstRunAdminPass123!",
        },
    )
    def test_refuses_to_promote_an_existing_non_admin(self):
        User.objects.create_user(
            phone="+256700111051",
            password="RegularUserPass123!",
            role=User.Role.CONSUMER,
        )

        with self.assertRaises(CommandError):
            call_command("bootstrap_admin")

        self.assertEqual(
            User.objects.get(phone="+256700111051").role,
            User.Role.CONSUMER,
        )


class PurgeSeedDataTests(TestCase):
    def setUp(self):
        self.seed_admin = User.objects.create_user(
            phone="+256761095861",
            password="SeedAdminPass123!",
            role=User.Role.ADMIN,
            is_staff=True,
        )
        self.demo_collector = User.objects.create_user(
            phone="+256700000011",
            password="collect12345",
            role=User.Role.COLLECTOR,
        )
        self.consumer = User.objects.create_user(
            phone="+256700000013",
            password="consumer12345",
            role=User.Role.CONSUMER,
        )
        self.category = Category.objects.create(name="Phones", slug="phones")
        self.item_type = ItemType.objects.create(
            category=self.category, name="Smartphone"
        )
        self.item = Item.objects.create(
            consumer=self.consumer, item_type=self.item_type
        )
        self.drop_off = DropOffPoint.objects.create(
            name="Kansanga Market Collection Bay", address="Kansanga"
        )
        self.request = CollectionRequest.objects.create(
            consumer=self.consumer,
            dropoff_point=self.drop_off,
            request_type=CollectionRequest.Type.DROPOFF,
        )
        self.wallet = get_or_create_wallet(self.consumer)
        Notification.objects.create(
            user=self.consumer, title="Seed notice", body="Seeded message."
        )
        AuditLog.objects.create(
            actor=self.consumer,
            action="seed",
            method="POST",
            path="/api/seed/",
            status_code=201,
        )

    def test_requires_confirmation(self):
        with self.assertRaises(CommandError):
            call_command("purge_seed_data")

        self.assertTrue(User.objects.filter(pk=self.seed_admin.pk).exists())
        self.assertTrue(Item.objects.filter(pk=self.item.pk).exists())

    @patch.dict(
        os.environ,
        {
            "ECOTRACE_ADMIN_PHONE": "+256700111060",
            "ECOTRACE_ADMIN_PASSWORD": "FirstRunAdminPass123!",
        },
    )
    def test_empties_database_and_first_run_creates_the_admin(self):
        call_command("purge_seed_data", confirm=True)

        for model in (
            User,
            Category,
            ItemType,
            Item,
            CollectionRequest,
            DropOffPoint,
            Wallet,
            Notification,
            AuditLog,
        ):
            self.assertFalse(
                model.objects.exists(),
                f"{model._meta.label} still has rows after the purge",
            )

        call_command("bootstrap_admin")

        admin = User.objects.get(phone="+256700111060")
        self.assertEqual(admin.role, User.Role.ADMIN)
        self.assertTrue(admin.is_superuser)
        self.assertTrue(admin.check_password("FirstRunAdminPass123!"))
        self.assertEqual(User.objects.count(), 1)
