# Sanitized architecture review export

Authoritative design originated in the original private project at baseline2155872cc626d7463d94500b678d875bec0e4dc6. This public branch descends only from sanitized review/phase02-booking at c21a03f54cf6b1792ab2321225300f397a642514, itself based on public main f35a5cc20ebd497b0d8fb7b96c207549f147799f. No private Git objects/history are imported.

Only docs/architecture/** derived specifications and newly generated diagram assets are transferred. The private global PROJECT_CONTEXT update is represented by a sanitized architecture snapshot, preserving the existing public frontend context/history files. All public Phase02 application/test/dependency/placeholder/system-font files are untouched.

Omitted: docs/architecture/sources/PHASE03A_REQUEST.txt (raw task), sources/PROJECT_CONTEXT_PHASE02.md (historical private context), all original client photographs, private font binaries, references, internal screenshots, environment/credentials, build/test artifacts, node_modules, scratch tooling and private Git metadata. Original app files are not recopied. Diagram SVG/PNG images are generated architecture graphics with no embedded photos/fonts/scripts. Public diagram content matches private derived specifications; there is no Booking behavior difference in03A because no Booking source is changed.

The public draft PR must target review/phase02-booking and remain unmerged. PR1 and main are not modified. SQL is review-only and never executed; OpenAPI is a proposed contract, not a running backend. No03B implementation begins until architecture approval.
