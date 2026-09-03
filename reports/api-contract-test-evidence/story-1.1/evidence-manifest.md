# API & Contract Testing Gate — Story 1.1

**Endpoints**: `GET /api/billing/upgrade-preview`, `POST /api/billing/upgrade`
**Command**: `pytest src/backend/tests -q --junitxml=...`
**Result**: 29/29 tests pass (16 unit + 13 API-contract-specific)

| Checklist item | Status | Evidence |
|---|---|---|
| Functional / happy path | PASS | test_preview_response_code_200_on_success, test_upgrade_response_code_200_on_success |
| Response-code validation | PASS | 200/401/402/409/422 all exercised |
| Role-based authorization (401 unauthenticated) | PASS | test_preview_response_code_401_unauthenticated, test_upgrade_response_code_401_unauthenticated |
| Role-based authorization (403 insufficient role) | N/A | App has no role/permission model on any endpoint — see test_role_based_authorization_not_applicable |
| Error-response validation (standard format + codes) | PASS | test_already_premium_error_shape, test_unauthenticated_error_shape, test_upgrade_response_code_402_on_decline |
| Request validation (required fields, data types) | PASS | test_upgrade_request_validation_missing_email_field, test_upgrade_request_validation_wrong_type, test_preview_request_validation_missing_query_param |
| Response contract/schema validation | PASS | test_preview_response_schema, test_upgrade_success_response_schema |
