# llm2: CloudU3 Pro access and hidden base models

Date: 2026-10-06

Branch: `DJ_icon_fix`

Status: Investigation recorded; user reports a direct-model rename workaround.
No application code fix deployed. The implementation plan below is deferred.

## User-selected workaround

After this investigation, the user reported renaming the target model directly
to `cloudu3-ai-pro` to avoid maintaining a preset/base relationship. The exact
configuration change and resulting normal-user behavior have not been verified.
Renaming a display label alone would not remove the base chain; exposing the
provider-backed model directly under the desired ID can avoid that chain.

The code-fix plan is retained for reference rather than scheduled implementation.
If the workaround meets the user's needs, no hidden-base patch is required.

## Goal

Normal users should see and use `cloudu3-ai-pro`, while its base,
`cliProxy.gpt-6.1-sol`, stays hidden from the model picker. Preserve Read
permission checks on both models. Hiding is a visibility setting, not a
restriction on direct API use by an otherwise authorized user.

## Live findings

Read-only SSH inspection of llm2's `open-webui-app1` container established:

- `cloudu3-ai-pro` and `cloudu3-ai-pro-o1` reference `cliProxy.gpt-6.1-sol`.
- Initially, the base had no entry in OWUI's `model` table.
- The application logged 23 access denials in the inspected 24-hour window,
  all with `reason=base_model_unregistered`.
- Admins are allowed to traverse an unregistered base; normal users are not.
- A later database inspection showed the base registered with
  `base_model_id=NULL` and `is_active=1`. Both presets were also active.

Representative log, 2026-10-06 08:18:40 UTC, with user identity omitted:

```text
Model access denied: model_id='cloudu3-ai-pro' base_model_id='cliProxy.gpt-6.1-sol' reason=base_model_unregistered
```

The user also reported that hiding the registered base broke Pro access.
Code inspection identifies a separate missing-base path that explains this:

1. `backend/open_webui/utils/models.py` removes inactive base overrides from
   the aggregated models before writing `request.app.state.MODELS`.
2. `backend/open_webui/main.py` checks whether a preset's base is in that
   registry.
3. An absent base raises `Model not found` unless a configured fallback is
   available. Falling back is not evidence that the intended base works.

The hidden-state failure has not yet been reproduced in a controlled test.
Do not confuse it with the separately confirmed permission-denial log.

## Historical research

### April 17: unregistered provider bases were allowed through presets

Commit `50363ba66b19613a2fc0cab6a3f7f724a825135e` introduced chained
base-access checks. Its original implementation ended the chain when the
base had no database row:

```python
if base_model_info is None:
    break  # Raw provider model — no per-model ACL
```

Thus a shared preset could invoke an unregistered provider base.

### July 24: upstream restricted unregistered bases to admins

Commit `fe4b319428b58bb7c08fb3ee7b777e5644fe06be`, merged through
[upstream PR #26905](https://github.com/open-webui/open-webui/pull/26905),
changed the missing-row behavior to:

```python
if base_model_info is None:
    return user_role == 'admin'
```

The PR explicitly describes closing an access-control gap where a publicly
shared preset could expose a base unavailable to the caller directly.
Registered bases retain grant-based enforcement.

### Later changes

- `5cecb7dbfad3994228ee53d19232650400462332` (August 10) refactored hidden
  base removal from `models.remove(model)` to identity-based list filtering.
  It did not introduce removal; its original introduction date is unverified.
- `20fe43d9da621957c48fc92104bc8f1cc0d691b7` (August 25) refactored the
  existing missing-base/fallback check in the chat entry point.
- `f5fcf4c89fb27ed39825875d573446fa84aa2a5b` (September 7) added diagnostic
  denial warnings, including `base_model_unregistered`; it did not introduce
  the permission restriction.

### Documentation versus deployment

[Current upstream model documentation](https://github.com/open-webui/docs/blob/main/docs/features/workspace/models.md)
recommends an accessible hidden base beneath a shared curated preset. It
states that users need access to both, while Hide removes the base from the
picker and leaves it reachable internally.

The inspected deployment conflicts with that internal-availability behavior.
Do not remove base authorization checks to work around the registry issue.

### Why the old OpenAI connection may have worked

The Git history proves an earlier permissive path existed, but does not prove
which revision or configuration the old deployment used. Its base may also
have been registered/shared or hidden through a different mechanism.
OpenAI API-key authentication versus CLIProxy authentication is not the
demonstrated cause. The new prefixed base ID has independent OWUI permissions.

## Implementation plan

### 1. Establish the baseline

- Compare the local branch's relevant source with the deployed image.
- Trace the frontend Hide action to the toggle endpoint and confirm its
  `is_active` semantics for base overrides versus workspace presets.
- Identify existing test infrastructure and cache invalidation behavior.
- Reproduce both an unregistered-base denial and a hidden registered-base
  failure with deterministic model/provider fixtures.

### 2. Separate visibility from routing

Primary target: `backend/open_webui/utils/models.py`.

- Retain provider-backed hidden bases in the internal model registry.
- Attach registered model metadata so Read checks remain enforceable.
- Exclude hidden bases at user-facing catalog boundaries.
- Keep disabled workspace presets unavailable; do not make every inactive
  model executable.
- Prefer one authoritative registry plus visibility filtering over another
  independent cache, subject to caller analysis.

### 3. Audit catalog and execution boundaries

Review `main.py`, `routers/openai.py`, `routers/ollama.py`,
`routers/models.py`, `utils/chat.py`, `routers/tasks.py`, and
`utils/access_control/__init__.py`.

- Ensure combined and provider-specific catalogs consistently hide the base.
- Preserve admin management access to hidden records.
- Ensure per-user filtering does not overwrite shared routing state.
- Preserve checks on the preset and every base hop.
- Verify exact prefixed-ID routing, preset parameters, and system prompts.
- Preserve genuine provider-missing failures and existing fallback behavior.
- Verify visibility updates invalidate affected caches without a restart.

### 4. Regression evidence

| Scenario | Expected result |
| --- | --- |
| Shared Pro + accessible hidden base | Pro listed; base omitted |
| Authorized user chats through Pro | Provider receives intended base ID |
| User lacks Pro Read access | Denied before provider invocation |
| User lacks base Read access | Denied before provider invocation |
| Disabled Pro preset | Not listed or executable |
| Base absent from provider catalog | Genuine missing-model failure |
| Hide/unhide transition | Lists refresh; Pro continues routing correctly |
| Provider-specific model catalogs | Hidden base consistently omitted |
| Admin management | Base can be found and unhidden |
| Background title generation | Completes with valid model routing |

Run focused backend regressions and applicable repository checks. Add frontend
tests only if frontend behavior changes. A provider mock establishes routing
and authorization; an actual normal-user session establishes deployment behavior.

### 5. Build and deploy

- Review the diff for authorization changes.
- Build a uniquely tagged image from the tested revision and record its digest.
- Before deployment, back up the database and record the previous image and
  model settings. Revise this plan if a database migration becomes necessary.
- Keep the base registered, grant Read access to intended Pro users/groups,
  hide it, and leave Pro enabled/shared.
- Verify a normal-user model list, fresh Pro chat, background title generation,
  unauthorized-user denial, admin management, and application logs.

Deployment is a separate step after implementation verification.

### 6. Rollback and acceptance

Rollback: restore the previous image and previous base visibility. Restore
the database only if configuration changes require it.

Acceptance: an authorized normal user can use Pro with the intended base hidden;
catalogs omit that base; unauthorized requests remain denied. Direct API denial
for an otherwise authorized hidden base is outside this plan's scope.
