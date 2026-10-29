# Visual review diagrams

Actual Graphviz SVG/PNG renders from editable DOT sources, generated2026-10-29. Start with rendered/overview.png. The six required views are database-erd, backend-modules, booking-flow, policy-resolution, payment-sequence and multi-branch-model. Extra state/concurrency views explain lifecycle and races. SVG is the zoomable source of detail; the bounded ERD PNG is only a thumbnail.

ERD has all72 tables and254 FK edges; dashed light-gray edges are shared business/actor relations. All business columns shown; audit columns remain in the complete dictionary/SQL. FK edge is child→parent; composite IDs in labels/tooltips. These are logical design relationships, not Nest import arrows. Module graph uses caller→callee arrows and has a machine-checked dependency DAG. Payment sequence time moves down. No photos, private fonts or visual mockups are embedded.

Every box is proposed architecture, not deployed infrastructure or backend test evidence. The technical documents govern details; read VALIDATION_MATRIX.md for future executable test cases.
