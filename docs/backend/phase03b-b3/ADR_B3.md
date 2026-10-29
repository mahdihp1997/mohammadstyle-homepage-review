# B3 implementation decisions for review

1. Dependency-safe commercial precursor: persist MS_COMMERCIAL_PROPOSAL_V1, reserve exact MS_QUOTE_CONTENT_V2 issuance for trusted B4 planner/relational/consent binding. Never salt or redefine the approved final hash or create fake booking FKs.
2. Explicit staff policy ranks: STAFF_SERVICE > STAFF > SERVICE > BRANCH > BUSINESS. An omitted provider does not match staff rules; a selected provider needs current temporal membership/eligibility. Mixed winners fail except a permissioned exact-service-set/exact-compatible-version-set whole policy with reason. No aggregation strategy invented.
3. Conservative business pricing epoch: all B3 configuration writes use one CAS revision; content fingerprints additionally bind server offering/service/branch/staff/membership/qualification/eligibility versions. Unrelated configuration may stale a proposal until measured refinement.
4. Durable command outbox: audit/idempotency/data and a redacted pricing.command stream event commit atomically; no external dispatcher/notification/payment is implemented. Preview does not create financial entitlement.

These engineering decisions do not approve actual prices, legal terms, real financial rounding/units, privacy/retention/history grants or B4 deployment. Existing architecture documents remain preserved historical specifications.
