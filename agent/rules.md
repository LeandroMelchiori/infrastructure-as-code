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

## Agent workflow

1. Read `agent/catalog.yaml`.
2. Read root `catalog.yaml`.
3. Select one architecture.
4. Resolve requested capabilities deterministically.
5. Ask only for missing decisions that materially affect security, cost, availability or topology.
6. Produce or modify Terraform.
7. Run fmt/validate.
8. Produce a plan.
9. Stop for human review before apply.
