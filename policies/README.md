# Constraint profiles

Constraint profiles translate human requirements such as "keep this inside Always Free" into deterministic infrastructure guardrails.

A profile is **not** a price quote and is **not** deployment authorization. It records reviewed provider constraints, their source and the date they were last checked.

## OCI Always Free

`oci/always-free.yaml` currently constrains the OCI A1-based single-VM reference architecture using the current OCI Free Tier documentation.

Agents must re-check provider eligibility, account entitlement, home region and capacity before deployment.
