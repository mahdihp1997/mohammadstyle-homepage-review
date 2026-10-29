# Local review fonts

The owner explicitly authorized using fonts in Downloads during Task 01.

- `app/fonts/iransans-regular.woff2`: supplied `IRANSansWeb(FaNum).woff2` (31,304 bytes).
- `app/fonts/iransans-bold.woff2`: supplied `IRANSansWeb(FaNum)_Bold.woff2` (28,856 bytes).
- `app/fonts/kahroba-variable.woff2`: supplied `Telegram Desktop/Kahroba-Pro.zip`, entry `180-Kahroba-v1.0-Pro/180-Kahroba-v1.0-Pro/Variable/woff2(web)/weight axis only/Kahroba-VF-wght[wght,100,50].woff2` (81,748 bytes). Matching TTF metadata confirms the weight axis runs from 100 to 900, default 400. Width and contrast are the supplied neutral 100/50 instance.

Kahroba is used for Persian headings/brand/service titles; IRANSans is used for body copy and controls. Both are self-hosted using `next/font/local` with swap and fallback metrics; no font CDN request is made. Existing English editorial labels retain their serif treatment.

Yekan files found locally were Yekan Bakh, not a verified IRANYekan family; they were not added. Original Downloads files and archive remain unchanged.

This records owner-supplied sources and internal-review authorization, not proof of a public webfont license. No license document was found in the Kahroba archive. Public licensing should be confirmed before any later public launch.
