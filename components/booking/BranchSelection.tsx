import Icon from "@/components/Icon";
import type { BookingBranch } from "@/types/booking";

export default function BranchSelection({ branches, selected, onChange, error }: { branches: BookingBranch[]; selected: string | null; onChange: (id: string | null) => void; error: string | null }) {
  return <fieldset className="booking-fieldset" aria-describedby={error ? "booking-error" : "branch-hint"}>
    <legend className="sr-only">انتخاب شعبه</legend>
    <p className="booking-intro" id="branch-hint">از شعبه پونک شروع کنید. این انتخاب فقط مسیر نمونه را فعال می‌کند و نشان‌دهنده موجودی نوبت نیست.</p>
    <div className="booking-branch-grid">
      {branches.map(branch => <label key={branch.id} className={`booking-branch-card ${selected === branch.id ? "is-selected" : ""} ${!branch.demoConfigured ? "is-unconfigured" : ""}`}>
        {branch.image && <div className="booking-branch-image"><img src={branch.image.src} alt={branch.image.alt} /><small>{branch.image.attribution}</small></div>}
        {!branch.image && <div className="booking-branch-placeholder" aria-hidden="true"><Icon name="location" size={36} /><span>اطلاعات در انتظار تأیید</span></div>}
        <div className="booking-branch-copy"><div className="booking-choice-title"><h3>{branch.name}</h3><input name="booking-branch" type="radio" value={branch.id} checked={selected === branch.id} disabled={!branch.demoConfigured} onChange={() => onChange(branch.id)} /></div>
          <p>{branch.location ?? "نشانی و تصویر شعبه دوم هنوز تأیید نشده‌اند."}</p>
          <span className="booking-badge">{branch.demoConfigured ? "قابل انتخاب در نسخه نمایشی" : "غیرقابل انتخاب؛ پیکربندی نشده"}</span>
        </div>
      </label>)}
    </div>
    {selected && <button className="booking-text-button" type="button" onClick={() => onChange(null)}>پاک کردن انتخاب شعبه</button>}
  </fieldset>;
}
