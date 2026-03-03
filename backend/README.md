# FastAPI Backend Skeleton (for `take2` frontend)

This folder contains a starter FastAPI backend designed to support the current frontend screens in `take2`:

- Dashboard / health metrics
- Inventory
- Billing
- Reports
- Settings
- Scan stock confirmation

## Quick start

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

Open docs at:
- Swagger UI: `http://127.0.0.1:8000/docs`
- ReDoc: `http://127.0.0.1:8000/redoc`

## Project structure

```text
backend/
  app/
    main.py
    core.py
    db.py
    models/
      schemas.py
    routers/
      health.py
      inventory.py
      billing.py
      reports.py
      settings.py
      scan.py
  tests/
```

## Notes

- This is an in-memory skeleton (no external database yet).
- APIs are versioned under `/api/v1`.
- You can replace `app/db.py` with a real database layer later without changing route signatures.


## Quick endpoint checks (after server starts)

```bash
curl http://127.0.0.1:8000/
curl http://127.0.0.1:8000/api/v1/health
curl http://127.0.0.1:8000/api/v1/inventory
```

## Run tests

```bash
cd backend
python -m unittest discover -s tests -v
```

> Note: API contract tests are automatically skipped when `fastapi` is not installed in the environment.
