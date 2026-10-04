# Infrastructure agent rules

Use metadata first. Do not scan the entire repository unless the selected architecture requires it.

## Safety boundary

- Never run or recommend an automatic `terraform apply` merely because a composition resolves.
- `terraform plan` is a review artifact, not permission to deploy.
- Apply and destroy require explicit human approval.
- Never expose credentials, private keys, Terraform state, tfvars, backend credentials, OCIDs copied from private environments, or secret values.
- Prefer existing reference architectures and modules over inventing new cloud topology.
- Do not let two Terraform states own the same resource.
- Respect the documented Object Storage ownership model.
- Treat public ingress, SSH exposure, IAM expansion and cost-bearing resources as review-sensitive changes.
- Translate human constraints such as "Always Free", CPU, RAM and storage into resolver inputs; do not rely on the LLM's memory of provider limits.
- Constraint profiles must include a source and review date. Re-check provider eligibility before apply when the profile requires it.
- A valid constraint resolution is not a price quote and does not guarantee cloud capacity.

## Agent workflow

1. Read `agent/catalog.yaml`.
2. Read root `catalog.yaml`.
3. Select one architecture.
4. Extract explicit constraints: profile/budget, CPU, memory, storage and instance count.
5. Resolve requested capabilities and constraints deterministically.
6. Ask only for missing decisions that materially affect security, cost, availability or topology.
7. Produce or modify Terraform.
8. Run fmt/validate.
9. Produce a plan.
10. Stop for human review before apply.
