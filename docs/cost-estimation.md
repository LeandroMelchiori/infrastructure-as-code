# Cost estimation

The cost engine in `tools/estimate_cost.py` estimates the modeled monthly list price for a selected infrastructure configuration.

It is intentionally separate from the LLM. Nanami should translate natural-language requirements into structured inputs, then let this tool do the arithmetic.

## Current modeled scope

For the OCI A1 single-VM architecture the engine currently models:

- A1 OCPU hours
- A1 memory GB-hours
- boot volume capacity
- boot volume performance units

The pricing catalog lives in `pricing/oci/current.yaml` and records both sources and the review date.

## Example

```bash
python tools/estimate_cost.py \
  --provider oci \
  --shape VM.Standard.A1.Flex \
  --ocpus 1 \
  --memory-gb 6 \
  --boot-volume-gb 50 \
  --json
```

To evaluate the same configuration conditionally under the conservative Always Free profile:

```bash
python tools/estimate_cost.py \
  --provider oci \
  --shape VM.Standard.A1.Flex \
  --ocpus 1 \
  --memory-gb 6 \
  --boot-volume-gb 50 \
  --profile always-free \
  --json
```

A zero-dollar result under a free profile is conditional on account eligibility, home-region rules, capacity and staying inside all tenancy-wide limits.

## Budget checks

`tools/resolve_architecture.py` integrates the estimator. A request such as a maximum monthly budget is checked against the modeled cost before Terraform is generated.

A budget check is not a bill guarantee. Capabilities outside the cost model, data transfer, taxes and provider-side pricing changes can add cost.
