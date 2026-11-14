import re
from io import StringIO

from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.test import TestCase
from rest_framework.test import APIClient

from apps.core.models import Notification
from apps.rewards.models import Wallet
from apps.waste.models import (
    Certificate,
    CollectionRequest,
    DropOffPoint,
    Item,
    ItemType,
    Category,
)

User = get_user_model()


def make_user(phone, role, password="testpass123"):
    return User.objects.create_user(
        phone=phone, password=password, role=role, full_name=phone, town="Kansanga"
    )


class EcoTraceFlowTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.consumer = make_user("+256700111001", User.Role.CONSUMER)
        self.collector = make_user("+256700111002", User.Role.COLLECTOR)
        self.recycler = make_user("+256700111003", User.Role.RECYCLER)
        self.admin = make_user("+256700111004", User.Role.ADMIN)
        self.category = Category.objects.create(name="Phones", slug="phones")
        self.item_type = ItemType.objects.create(
            category=self.category,
            name="Smartphone",
            points_per_item=3000,
            reward_ugx=3000,
            carbon_factor_kg=21.0,
        )

    def login(self, user):
        self.client.force_authenticate(user=user)

    def test_register_and_login(self):
        resp = self.client.post(
            "/api/auth/register/",
            {
                "phone": "+256700999888",
                "password": "StrongPass123!",
                "full_name": "New User",
            },
            format="json",
        )
        self.assertEqual(resp.status_code, 201, resp.content)
        self.assertIn("access", resp.data)
        resp = self.client.post(
            "/api/auth/token/",
            {"phone": "+256700999888", "password": "StrongPass123!"},
            format="json",
        )
        self.assertEqual(resp.status_code, 200, resp.content)

    def test_pickup_request_accepts_map_location_without_address(self):
        self.login(self.consumer)
        item = Item.objects.create(
            consumer=self.consumer, item_type=self.item_type, quantity=1
        )
        partial_location = self.client.post(
            "/api/requests/",
            {
                "request_type": "PICKUP",
                "item_ids": [item.id],
                "latitude": 0.3172,
            },
            format="json",
        )
        self.assertEqual(partial_location.status_code, 400)

        resp = self.client.post(
            "/api/requests/",
            {
                "request_type": "PICKUP",
                "item_ids": [item.id],
                "latitude": 0.3172,
                "longitude": 32.5816,
            },
            format="json",
        )

        self.assertEqual(resp.status_code, 201, resp.content)
        self.assertEqual(resp.data["pickup_address"], "")
        self.assertEqual(resp.data["latitude"], 0.3172)
        self.assertEqual(resp.data["longitude"], 32.5816)

    def test_full_disposal_flow_credits_wallet(self):
        self.login(self.consumer)
        item = Item.objects.create(
            consumer=self.consumer, item_type=self.item_type, quantity=2
        )
        resp = self.client.post(
            "/api/requests/",
            {
                "request_type": "PICKUP",
                "item_ids": [item.id],
                "pickup_address": "Plot 1, Kansanga",
            },
            format="json",
        )
        self.assertEqual(resp.status_code, 201, resp.content)
        req_id = resp.data["id"]
        self.assertEqual(resp.data["status"], "PENDING")
        self.assertTrue(
            Notification.objects.filter(
                user=self.collector,
                title__startswith="New pickup request:",
                request_id=req_id,
            ).exists()
        )
        # Proposal FR4: carbon-offset estimate is shown as soon as items are logged.
        self.assertIn("carbon_kg", resp.data)
        self.assertEqual(float(resp.data["carbon_kg"]), 42.0)
        self.assertIn("carbon_kg", resp.data["items"][0])
        self.assertIn("hazardous", resp.data["items"][0])
        self.assertIn("hazardous_count", resp.data)

        self.login(self.collector)
        resp = self.client.post(f"/api/requests/{req_id}/claim/")
        self.assertEqual(resp.status_code, 200, resp.content)
        self.assertEqual(resp.data["status"], "ASSIGNED")
        self.login(self.consumer)
        notifications = self.client.get("/api/auth/notifications/")
        code_notice = next(
            item
            for item in notifications.data["results"]
            if item["title"].startswith("Pickup verification code:")
        )
        verification_code = re.search(r"\d{8}", code_notice["body"]).group()
        self.login(self.collector)
        resp = self.client.post(
            f"/api/requests/{req_id}/transition/",
            {"status": "COLLECTED"},
            format="json",
        )
        self.assertEqual(resp.status_code, 400)
        resp = self.client.post(
            f"/api/requests/{req_id}/transition/",
            {"status": "COLLECTED", "verification_code": verification_code},
            format="json",
        )
        self.assertEqual(resp.status_code, 200, resp.content)
        self.assertTrue(resp.data["pickup_confirmed"])
        resp = self.client.post(
            f"/api/requests/{req_id}/transition/",
            {"status": "IN_TRANSIT"},
            format="json",
        )
        self.assertEqual(resp.status_code, 200, resp.content)
        self.login(self.recycler)
        resp = self.client.post(
            f"/api/requests/{req_id}/receive/",
            {"items_received": 2},
            format="json",
        )
        self.assertEqual(resp.status_code, 200, resp.content)
        resp = self.client.post(
            f"/api/requests/{req_id}/process/",
            {"method": "RECYCLING"},
            format="json",
        )
        self.assertEqual(resp.status_code, 200, resp.content)
        self.assertEqual(resp.data["status"], "PROCESSED")
        self.assertTrue(resp.data["reward_credited"])
        self.assertIn("certificate", resp.data)
        self.assertIsNotNone(resp.data.get("certificate"))
        # Verified disposal snapshots the carbon estimate onto request + certificate.
        self.assertEqual(float(resp.data["carbon_kg"]), 42.0)
        self.assertEqual(float(resp.data["certificate"]["carbon_kg"]), 42.0)

        self.login(self.consumer)
        notifications = self.client.get("/api/auth/notifications/")
        self.assertEqual(notifications.status_code, 200, notifications.content)
        self.assertTrue(
            any(
                notification["request_id"] == req_id
                for notification in notifications.data["results"]
            )
        )

        wallet = Wallet.objects.get(user=self.consumer)
        self.assertEqual(wallet.balance, 0)
        self.assertEqual(wallet.points_balance, 3000)

        req = CollectionRequest.objects.get(pk=req_id)
        self.assertTrue(Certificate.objects.filter(request=req).exists())
        self.assertEqual(req.events.count(), 6)

        self.login(self.recycler)
        resp = self.client.post(
            f"/api/requests/{req_id}/process/",
            {"method": "RECYCLING"},
            format="json",
        )
        self.assertEqual(resp.status_code, 400)
        wallet.refresh_from_db()
        self.assertEqual(wallet.points_balance, 3000)

        # Reports must count the request and its carbon exactly once,
        # even though the request has multiple items (join de-duplication).
        self.login(self.admin)
        resp = self.client.get("/api/reports/summary/")
        self.assertEqual(float(resp.data["carbon_saved_kg"]), 42.0)
        kansanga = [r for r in resp.data["by_town"] if r["consumer__town"] == "Kansanga"]
        self.assertEqual(kansanga[0]["requests"], 1)
        self.assertEqual(float(kansanga[0]["carbon_kg"]), 42.0)

    def test_admin_can_create_categories_without_providing_slug(self):
        self.login(self.admin)
        response = self.client.post(
            "/api/categories/",
            {"name": "Small Appliances"},
            format="json",
        )

        self.assertEqual(response.status_code, 201, response.content)
        self.assertEqual(response.data["slug"], "small-appliances")

    def test_consumer_cannot_process(self):
        self.login(self.consumer)
        item = Item.objects.create(
            consumer=self.consumer, item_type=self.item_type, quantity=1
        )
        resp = self.client.post(
            "/api/requests/",
            {"request_type": "DROPOFF", "item_ids": [item.id]},
            format="json",
        )
        req_id = resp.data["id"]
        resp = self.client.post(f"/api/requests/{req_id}/process/")
        self.assertEqual(resp.status_code, 403)

    def test_role_scoped_request_lists(self):
        item = Item.objects.create(
            consumer=self.consumer, item_type=self.item_type, quantity=1
        )
        self.login(self.consumer)
        self.client.post(
            "/api/requests/",
            {"request_type": "PICKUP", "item_ids": [item.id], "pickup_address": "X"},
            format="json",
        )
        self.login(self.collector)
        resp = self.client.get("/api/requests/list/?scope=available")
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.data["count"], 1)
        resp = self.client.get(
            "/api/requests/list/?scope=available&q=Smartphone"
        )
        self.assertEqual(resp.data["count"], 1)
        resp = self.client.get("/api/requests/list/")
        self.assertEqual(resp.data["count"], 0)

    def test_redeem_flow(self):
        wallet, _ = Wallet.objects.get_or_create(user=self.consumer)
        wallet.credit(10000, "test")
        self.login(self.consumer)
        resp = self.client.post(
            "/api/wallet/redeem/",
            {"amount": 5000, "destination": "+256700111001"},
            format="json",
        )
        self.assertEqual(resp.status_code, 201, resp.content)
        wallet.refresh_from_db()
        self.assertEqual(wallet.balance, 5000)
        resp = self.client.get("/api/wallet/")
        self.assertEqual(resp.status_code, 200)

        self.login(self.admin)
        resp = self.client.post("/api/redemptions/1/approve/")
        self.assertEqual(resp.status_code, 200, resp.content)
        self.assertEqual(resp.data["status"], "PAID")

    def test_admin_reports(self):
        self.login(self.admin)
        resp = self.client.get("/api/reports/summary/")
        self.assertEqual(resp.status_code, 200, resp.content)
        self.assertIn("total_requests", resp.data)
        self.assertIn("processed_requests", resp.data)
        # Proposal FR11: reports include estimated carbon savings and town volumes.
        self.assertIn("carbon_saved_kg", resp.data)
        self.assertIn("by_town", resp.data)

    def test_item_types_expose_carbon_and_hazard_flags(self):
        self.login(self.consumer)
        resp = self.client.get("/api/categories/")
        self.assertEqual(resp.status_code, 200, resp.content)
        categories = resp.data.get("results", resp.data)
        item_type = categories[0]["types"][0]
        self.assertIn("carbon_factor_kg", item_type)
        self.assertIn("hazardous", item_type)

    def test_hazardous_items_are_flagged(self):
        battery_type = ItemType.objects.create(
            category=self.category,
            name="Phone battery",
            reward_ugx=500,
            carbon_factor_kg=1.5,
            hazardous=True,
        )
        battery = Item.objects.create(
            consumer=self.consumer, item_type=battery_type, quantity=2
        )
        damaged = Item.objects.create(
            consumer=self.consumer,
            item_type=self.item_type,
            quantity=1,
            condition="DAMAGED",
        )
        self.login(self.consumer)
        resp = self.client.post(
            "/api/requests/",
            {
                "request_type": "PICKUP",
                "item_ids": [battery.id, damaged.id],
                "pickup_address": "Plot 2, Kansanga",
            },
            format="json",
        )
        self.assertEqual(resp.status_code, 201, resp.content)
        by_id = {i["id"]: i for i in resp.data["items"]}
        self.assertTrue(by_id[battery.id]["hazardous"])
        self.assertTrue(by_id[damaged.id]["hazardous"])
        # 2 batteries + 1 damaged smartphone
        self.assertEqual(resp.data["hazardous_count"], 3)

    def test_available_pickups_are_matched_by_town(self):
        other_town_consumer = make_user("+256700111005", User.Role.CONSUMER)
        other_town_consumer.town = "Nakawa"
        other_town_consumer.save(update_fields=["town"])
        item = Item.objects.create(
            consumer=self.consumer, item_type=self.item_type, quantity=1
        )
        far_item = Item.objects.create(
            consumer=other_town_consumer, item_type=self.item_type, quantity=1
        )
        self.login(self.consumer)
        self.client.post(
            "/api/requests/",
            {"request_type": "PICKUP", "item_ids": [item.id], "pickup_address": "X"},
            format="json",
        )
        self.login(other_town_consumer)
        self.client.post(
            "/api/requests/",
            {"request_type": "PICKUP", "item_ids": [far_item.id], "pickup_address": "Y"},
            format="json",
        )
        # Collector based in Kansanga only sees same-town pickups by default.
        self.login(self.collector)
        resp = self.client.get("/api/requests/list/?scope=available")
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.data["count"], 1)
        self.assertEqual(
            resp.data["results"][0]["consumer_detail"]["town"], "Kansanga"
        )
        # An explicit town (or "all") overrides the default matching.
        resp = self.client.get("/api/requests/list/?scope=available&town=all")
        self.assertEqual(resp.data["count"], 2)

    def test_consumer_cannot_list_all_users(self):
        self.login(self.consumer)
        resp = self.client.get("/api/users/")
        self.assertEqual(resp.status_code, 403)
        self.login(self.admin)
        resp = self.client.get("/api/users/")
        self.assertEqual(resp.status_code, 200)

    def test_points_redeem_enforces_floor_and_rejection_refunds_points(self):
        wallet, _ = Wallet.objects.get_or_create(user=self.consumer)
        wallet.credit_points(1500, "test points")
        self.login(self.consumer)
        response = self.client.post(
            "/api/wallet/redeem/",
            {"points": 999, "destination": "+256700111001"},
            format="json",
        )
        self.assertEqual(response.status_code, 400)
        response = self.client.post(
            "/api/wallet/redeem/",
            {
                "points": 1000,
                "destination": "+256700111001",
                "method": "AIRTIME",
            },
            format="json",
        )
        self.assertEqual(response.status_code, 201, response.content)
        self.assertEqual(response.data["amount"], "1000.00")
        self.assertEqual(response.data["points_redeemed"], 1000)
        wallet.refresh_from_db()
        self.assertEqual(wallet.points_balance, 500)

        self.login(self.admin)
        response = self.client.post(f"/api/redemptions/{response.data['id']}/reject/")
        self.assertEqual(response.status_code, 200)
        wallet.refresh_from_db()
        self.assertEqual(wallet.points_balance, 1500)

    def test_dropoff_processing_awards_full_policy_points(self):
        item = Item.objects.create(
            consumer=self.consumer, item_type=self.item_type, quantity=1
        )
        collection = CollectionRequest.objects.create(
            consumer=self.consumer,
            request_type=CollectionRequest.Type.DROPOFF,
            status=CollectionRequest.Status.RECEIVED,
        )
        collection.items.set([item])
        self.login(self.recycler)
        response = self.client.post(
            f"/api/requests/{collection.id}/process/",
            {"method": "RECYCLING"},
            format="json",
        )
        self.assertEqual(response.status_code, 200, response.content)
        self.assertEqual(response.data["points_earned"], 3000)
        wallet = Wallet.objects.get(user=self.consumer)
        self.assertEqual(wallet.points_balance, 3000)

    def test_admin_can_update_reward_policy(self):
        self.login(self.admin)
        response = self.client.patch(
            "/api/wallet/policy/",
            {
                "minimum_redemption_points": 2500,
                "ugx_per_point": "2.00",
                "pickup_points_percent": 25,
                "dropoff_points_percent": 100,
            },
            format="json",
        )
        self.assertEqual(response.status_code, 200, response.content)
        self.assertEqual(response.data["minimum_redemption_points"], 2500)
        response = self.client.patch(
            "/api/wallet/policy/",
            {"pickup_points_percent": 100, "dropoff_points_percent": 100},
            format="json",
        )
        self.assertEqual(response.status_code, 400)
        self.login(self.consumer)
        response = self.client.patch(
            "/api/wallet/policy/", {"minimum_redemption_points": 1}, format="json"
        )
        self.assertEqual(response.status_code, 403)

    def test_collector_can_alert_local_recyclers_of_full_dropoff(self):
        point = DropOffPoint.objects.create(
            name="Full bay", address="Kansanga", town="Kansanga"
        )
        self.login(self.collector)
        response = self.client.post(
            f"/api/dropoff-points/{point.id}/capacity-alert/",
            {"details": "Bay is full"},
            format="json",
        )
        self.assertEqual(response.status_code, 200, response.content)
        self.assertEqual(response.data["notified"], 1)
        self.assertTrue(
            Notification.objects.filter(
                user=self.recycler,
                title="Full drop-off point: collection needed",
            ).exists()
        )


class DemoDataCommandTests(TestCase):
    def test_seed_command_is_idempotent_and_does_not_change_existing_users(self):
        existing_consumer = make_user("+256700111101", User.Role.CONSUMER)
        admin = make_user("+256700111102", User.Role.ADMIN)

        call_command("seed_demo_data")
        call_command("seed_demo_data")

        demo_users = User.objects.filter(phone__startswith="+256700900")
        self.assertEqual(demo_users.count(), 3)
        for user in demo_users:
            requests = CollectionRequest.objects.filter(
                consumer=user,
                consumer_note__startswith="DEMO DATA:",
            )
            self.assertEqual(requests.count(), 3)
            self.assertFalse(user.has_usable_password())
            self.assertTrue(
                all(
                    request.status == CollectionRequest.Status.CANCELLED
                and request.items.filter(
                    notes__startswith="DEMO DATA:"
                ).exists()
                for request in requests
            )
            )

        self.assertFalse(
            CollectionRequest.objects.filter(consumer=existing_consumer).exists()
        )
        self.assertFalse(CollectionRequest.objects.filter(consumer=admin).exists())

    def test_seed_command_dry_run_does_not_write_data(self):
        output = StringIO()
        call_command("seed_demo_data", dry_run=True, stdout=output)

        self.assertIn("Would create EcoTrace Demo Consumer 001", output.getvalue())
        self.assertFalse(User.objects.filter(phone__startswith="+256700900").exists())
        self.assertFalse(
            Category.objects.filter(slug="ecotrace-demo-electronics").exists()
        )
