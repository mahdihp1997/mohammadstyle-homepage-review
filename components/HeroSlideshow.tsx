"use client";
import {useEffect,useRef,useState} from 'react';

const frames=[
 {src:'/images/hero-groom.webp',alt:'آرایشگر محمد استایل در حال آماده‌سازی موی مشتری'},
 {src:'/images/salon-team.webp',alt:'محمد و مشتری با استایل مو و لباس رسمی در سالن'},
 {src:'/images/salon-light.webp',alt:'صندلی‌ها و آینه‌های سالن محمد استایل'},
] as const;

/** Ambient photography. No selection controls; reduced motion keeps the first frame. */
export default function HeroSlideshow(){
 const [current,setCurrent]=useState(0),container=useRef<HTMLDivElement>(null);
 useEffect(()=>{
  const node=container.current;if(!node)return;
  const motion=matchMedia('(prefers-reduced-motion: reduce)');let visible=false,hovered=false,timer:ReturnType<typeof setInterval>|undefined;
  const sync=()=>{clearInterval(timer);timer=undefined;if(motion.matches){setCurrent(0);return;}if(visible&&!hovered&&!document.hidden)timer=setInterval(()=>setCurrent(n=>(n+1)%frames.length),6500);};
  const enter=()=>{hovered=true;sync();},leave=()=>{hovered=false;sync();};
  const observer=new IntersectionObserver(([e])=>{visible=e.isIntersecting;sync();},{threshold:.2});observer.observe(node);
  motion.addEventListener('change',sync);document.addEventListener('visibilitychange',sync);node.addEventListener('mouseenter',enter);node.addEventListener('mouseleave',leave);
  return()=>{clearInterval(timer);observer.disconnect();motion.removeEventListener('change',sync);document.removeEventListener('visibilitychange',sync);node.removeEventListener('mouseenter',enter);node.removeEventListener('mouseleave',leave);};
 },[]);
 return <div className="hero-slideshow" ref={container}>{frames.map((frame,i)=><img key={frame.src} className={'hero-main-image hero-slide'+(i===current?' is-current':'')} src={frame.src} alt={frame.alt} aria-hidden={i!==current} fetchPriority={i===0?'high':'auto'} decoding="async"/>)}</div>;
}
