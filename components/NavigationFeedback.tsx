'use client';
import {useEffect,useState} from 'react';
import BrandLoader from './BrandLoader';

/** Plain document navigation only. Next Links own their pending state. The
 * server renders the actual page, so a disabled-JS visitor never gets stuck
 * behind a streaming loading boundary. No artificial minimum loading time. */
export default function NavigationFeedback(){
 const[loading,setLoading]=useState(false);
 useEffect(()=>{
  const clear=()=>setLoading(false);
  const click=(e:MouseEvent)=>{
   if(e.defaultPrevented||e.button!==0||e.metaKey||e.ctrlKey||e.shiftKey||e.altKey)return;
   const link=(e.target as Element)?.closest?.('a[href]') as HTMLAnchorElement|null;
   if(!link||link.download||(link.target&&link.target!=='_self'))return;
   const url=new URL(link.href,location.href);
   if(url.origin!==location.origin||(url.pathname===location.pathname&&url.search===location.search))return;
   setLoading(true);
  };
  const escape=(e:KeyboardEvent)=>{if(e.key==='Escape')clear();};
  document.addEventListener('click',click);window.addEventListener('pageshow',clear);window.addEventListener('popstate',clear);window.addEventListener('keydown',escape);
  return()=>{document.removeEventListener('click',click);window.removeEventListener('pageshow',clear);window.removeEventListener('popstate',clear);window.removeEventListener('keydown',escape);};
 },[]);
 return loading?<span className="page-navigation-feedback"><BrandLoader compact label="در حال باز کردن صفحه…"/></span>:null;
}
