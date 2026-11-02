"use client";
import {useState} from 'react';
import Link from './BrandLink';
import BrandMark from './BrandMark';
import Icon from './Icon';
import type {ArticleSummary} from '@/types/article';

const publishedDate=(a:ArticleSummary)=>new Date(a.publishedAt).toLocaleDateString('fa-IR',{timeZone:'Asia/Tehran'});
export default function JournalGrid({articles}:{articles:ArticleSummary[]}) {
  const [category,setCategory]=useState('');
  const categories=[...new Set(articles.map(a=>a.category).filter(Boolean))];
  const selected=category?articles.filter(a=>a.category===category):articles;
  const [featured,...rest]=selected;
  const cover=(a:ArticleSummary)=>a.coverId?<img src={'/api/portfolio/'+a.coverId+'/DISPLAY'} alt="" loading="lazy" decoding="async"/>:<BrandMark/>;
  return <>
    <div className="journal-topline"><span>نگاهی دقیق‌تر به آراستگی</span><span>MOHAMMAD STYLE / JOURNAL</span></div>
    <div className="journal-topics" role="group" aria-label="موضوعات مجله"><button type="button" aria-pressed={!category} onClick={()=>setCategory('')}>همهٔ مطالب</button>{categories.map(c=><button key={c} type="button" aria-pressed={category===c} onClick={()=>setCategory(c)}>{c}</button>)}</div>
    <p className="sr-only" role="status">{selected.length.toLocaleString('fa-IR')} مطلب</p>
    {featured&&<article className="journal-feature">
      <Link href={'/blog/'+featured.slug} className="journal-feature-image" tabIndex={-1} aria-hidden="true">{cover(featured)}</Link>
      <div className="journal-feature-copy"><span className="journal-category">{featured.category}</span><span className="journal-feature-label">پیشنهاد تحریریه</span><h2><Link href={'/blog/'+featured.slug}>{featured.title}</Link></h2><p>{featured.summary}</p><div className="journal-meta"><span>{featured.authorName}</span><span>{publishedDate(featured)}</span></div><Link className="journal-read-link" href={'/blog/'+featured.slug}>خواندن مقاله<Icon name="arrow" size={18}/><span className="sr-only">: {featured.title}</span></Link></div>
    </article>}
    {!!rest.length&&<><div className="journal-section-title"><h2>برای استایل بعدی شما</h2><span>THE EDIT</span></div><div className="journal-grid">{rest.map(a=><article key={a.id} className="journal-card"><Link href={'/blog/'+a.slug} tabIndex={-1} aria-hidden="true" className="journal-cover">{cover(a)}</Link><div><span>{a.category||'مجلهٔ آراستگی'}</span><h3><Link href={'/blog/'+a.slug}>{a.title}</Link></h3><p>{a.summary}</p><footer><span>{publishedDate(a)}</span><Link href={'/blog/'+a.slug}>مطالعهٔ مقاله<span className="sr-only">: {a.title}</span></Link></footer></div></article>)}</div></>}
    <aside className="journal-consultation"><div><span className="contact-kicker">از خواندن تا تجربه‌کردن</span><h2>استایل مناسب شما از یک گفت‌وگو شروع می‌شود.</h2><p>ایده‌هایتان را با آرایشگران مجموعه در میان بگذارید.</p></div><Link href="/barbers" className="btn btn-ghost">آشنایی با آرایشگران</Link></aside>
  </>;
}
