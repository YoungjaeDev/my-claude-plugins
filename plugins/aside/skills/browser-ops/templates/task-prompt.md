Goal: {goal}
Target: {observed_or_user_provided_url}; account alias={account_alias}; browser profile={profile_alias}.
Allowed domains/actions: {allowed_scope}.
Forbidden actions: {forbidden_actions}.
Success criteria: {observable_success_criteria}.
Relevant playbook hints (recheck against current page): {redacted_excerpt}.

Use a built-in Aside site skill if relevant. Stay inside the authorized scope. Do not send, purchase, delete, or change settings unless this request authorizes it and required approvals are satisfied. Do not expose credentials or authentication codes. If login/manual approval blocks progress, stop and identify the needed user action. Verify the actual resulting page/file state, then return actions, evidence, unresolved items, and the actual session ID if available. Do not repeat a potentially accepted mutation without checking its target state.
