export default function BrandLoader({ compact=false, label="در حال آماده‌سازی…" }: { compact?: boolean; label?: string }) {
  return <span className={`brand-loader${compact?" brand-loader-compact":""}`} role="status"><span className="brand-loader-glyph" aria-hidden="true"><span/></span><span>{label}</span></span>;
}
