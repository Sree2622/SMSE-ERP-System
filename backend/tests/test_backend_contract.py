import importlib.util
import unittest
import uuid


FASTAPI_AVAILABLE = importlib.util.find_spec("fastapi") is not None and importlib.util.find_spec("httpx") is not None


@unittest.skipUnless(FASTAPI_AVAILABLE, "fastapi/httpx is not installed in this environment")
class BackendContractTests(unittest.TestCase):
    def setUp(self) -> None:
        from fastapi.testclient import TestClient
        from app.main import app

        self.client = TestClient(app)

    def test_root_endpoint(self) -> None:
        response = self.client.get("/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["message"], "SMSE ERP backend is running")

    def test_health_endpoint(self) -> None:
        response = self.client.get("/api/v1/health")
        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload["status"], "ok")
        self.assertIn("service", payload)
        self.assertIn("version", payload)

    def test_inventory_list_endpoint(self) -> None:
        response = self.client.get("/api/v1/inventory")
        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertIsInstance(payload, list)
        self.assertGreaterEqual(len(payload), 1)

    def test_billing_updates_inventory_stock(self) -> None:
        unique_name = f"Test Item {uuid.uuid4().hex[:8]}"
        create_item_response = self.client.post(
            "/api/v1/inventory",
            json={"name": unique_name, "stock": 10},
        )
        self.assertEqual(create_item_response.status_code, 201)
        item = create_item_response.json()

        create_bill_response = self.client.post(
            "/api/v1/billing",
            json={"items": [{"item_id": item["id"], "quantity": 3}]},
        )
        self.assertEqual(create_bill_response.status_code, 201)
        bill_payload = create_bill_response.json()
        self.assertEqual(bill_payload["items"][0]["item_id"], item["id"])

        inventory_response = self.client.get(f"/api/v1/inventory?search={unique_name}")
        self.assertEqual(inventory_response.status_code, 200)
        matched_items = inventory_response.json()
        self.assertEqual(len(matched_items), 1)
        self.assertEqual(matched_items[0]["stock"], 7)


if __name__ == "__main__":
    unittest.main()
