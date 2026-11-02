import SalonPage from "@/components/SalonPage";
import Icon from "@/components/Icon";
import { team } from "@/data/salon";
import { business } from "@/data/site";
export const metadata = { title: "تماس با ما | محمد استایل" };
function phoneLabel(phone: string) {
  return `${phone.slice(0, 4)} ${phone.slice(4, 7)} ${phone.slice(7)}`.replace(/\d/g, d => "۰۱۲۳۴۵۶۷۸۹"[Number(d)]);
}

export default function ContactPage() {
  return <SalonPage title="در ارتباط باشیم." eyebrow="GET IN TOUCH">
    <div className="contact-layout">
      <section className="contact-direct" aria-labelledby="contact-direct-title">
        <span className="contact-kicker">یک گفت‌وگو، شروع یک استایل تازه</span>
        <h2 id="contact-direct-title">مستقیم با ما صحبت کنید.</h2>
        <p>برای مشاورهٔ استایل، پکیج دامادی و هماهنگی مراجعه با ما تماس بگیرید.</p>
        <div className="contact-people">{team.filter(person => person.phone && person.phoneHref).map(person =>
          <a className="contact-person" key={person.id} href={person.phoneHref!} aria-label={`تماس با ${person.name}، ${person.phone}`}>
            <span className="contact-person-icon"><Icon name="phone" size={22}/></span>
            <span className="contact-person-name"><strong>{person.name}</strong><span>تماس مستقیم</span></span>
            <bdi className="contact-phone" dir="ltr">{phoneLabel(person.phone!)}</bdi>
          </a>
        )}</div>
        <a className="contact-team-link" href="/barbers">آشنایی با آرایشگران مجموعه<Icon name="arrow" size={18}/></a>
      </section>
      <div className="contact-details">
        <section className="contact-location" aria-labelledby="contact-location-title">
          <span className="contact-detail-icon"><Icon name="location" size={24}/></span>
          <div><span className="contact-kicker">ملاقات در سالن</span><h2 id="contact-location-title">شعبهٔ پونک</h2>
            <address>{business.location}</address>
            <a className="btn btn-gold" href="/booking"><Icon name="calendar" size={18}/>رزرو نوبت</a>
          </div>
        </section>
        <section className="contact-social" aria-labelledby="contact-social-title">
          <div><h2 id="contact-social-title">از نزدیک‌تر دنبالمان کنید.</h2><p>تصاویر، ویدیوها و تازه‌های محمد استایل</p></div>
          <a className="instagram-cta" href={business.instagram} target="_blank" rel="noopener noreferrer"><Icon name="instagram" size={24}/><bdi dir="ltr">@mohammadstyle1</bdi><span className="sr-only">در اینستاگرام، در پنجرهٔ جدید</span></a>
        </section>
      </div>
    </div>
  </SalonPage>;
}
