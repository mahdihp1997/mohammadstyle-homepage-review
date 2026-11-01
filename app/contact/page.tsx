import SalonPage from "@/components/SalonPage";
import Icon from "@/components/Icon";
import { team } from "@/data/salon";
import { business } from "@/data/site";
export const metadata = { title: "تماس با ما | محمد استایل" };
export default function ContactPage() {
  return <SalonPage title="در ارتباط باشیم." eyebrow="GET IN TOUCH"><div className="salon-contact-grid">{team.filter(person=>person.phoneHref).map(person=><section className="salon-contact-card salon-person-contact" key={person.id}><span className="section-eyebrow">THE TEAM</span><h2>{person.name}</h2><a className="contact-phone" href={person.phoneHref!} dir="ltr">{person.phone}</a><a className="subtle-link" href="/barbers">معرفی آرایشگران</a></section>)}<section className="salon-contact-card"><Icon name="location" size={32}/><h2>سالن ممتاز پونک</h2><p>{business.location}</p><a className="btn btn-gold" href="/booking">رزرو نوبت</a></section><section className="salon-contact-card"><Icon name="instagram" size={32}/><h2>اینستاگرام محمد استایل</h2><p>نمونه‌کارها و تازه‌های مجموعه را ببینید.</p><a className="instagram-cta" href={business.instagram} target="_blank" rel="noopener noreferrer"><Icon name="instagram" size={24}/><span dir="ltr">@mohammadstyle1</span></a></section></div></SalonPage>;
}
