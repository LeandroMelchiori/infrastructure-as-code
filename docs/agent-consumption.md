# AI agent consumption

This repository can be consumed by an AI agent without loading the complete Terraform codebase into the model context.

```text
user intent
   ↓
agent/catalog.yaml
   ↓
catalog.yaml
   ↓
reference architecture
   ↓
deterministic resolver
   ↓
selected Terraform only
   ↓
fmt / validate / plan
   ↓
HUMAN REVIEW
   ↓
apply
```

The LLM interprets intent and chooses from known architectures. The resolver validates known combinations. Terraform remains responsible for the actual dependency graph and plan.

For infrastructure, resolution is deliberately not deployment authorization. Any `apply` or `destroy` remains behind explicit human approval.
