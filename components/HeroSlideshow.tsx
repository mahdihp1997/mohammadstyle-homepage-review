"use client";
import {useEffect,useRef,useState,type PointerEvent} from 'react';

const frames=[
 {id:'groom',src:'/images/hero-groom.webp',alt:'آرایشگر محمد استایل در حال آماده‌سازی موی مشتری'},
 {id:'craft',src:'/images/barber-process.webp',alt:'جزئیات آماده‌سازی و اصلاح مو در سالن'},
 {id:'team',src:'/images/salon-team.webp',alt:'محمد و مشتری با استایل مو و لباس رسمی در سالن'},
 {id:'studio',src:'/images/salon-light.webp',alt:'صندلی‌ها و آینه‌های سالن محمد استایل'},
] as const;

/** Ambient photography. No selection controls; reduced motion keeps the first frame. */
export default function HeroSlideshow(){
 const [current,setCurrent]=useState(0),container=useRef<HTMLDivElement>(null);
 const gesture=useRef<{id:number;x:number;y:number}|null>(null),keyboardFocused=useRef(false),restart=useRef<()=>void>(()=>{});
 const [navigation,setNavigation]=useState<'auto'|'pointer'|'keyboard'>('auto');
 const finishGesture=()=>{gesture.current=null;restart.current();};
 function release(e:PointerEvent<HTMLDivElement>){
  const g=gesture.current;if(!g||g.id!==e.pointerId)return;
  const dx=e.clientX-g.x,dy=e.clientY-g.y;
  if(Math.abs(dx)>=44&&Math.abs(dx)>Math.abs(dy)*1.2){setNavigation('pointer');setCurrent(n=>(n+(dx<0?1:-1)+frames.length)%frames.length);}
  finishGesture();
 }
 useEffect(()=>{
  const node=container.current;if(!node)return;
  const motion=matchMedia('(prefers-reduced-motion: reduce)');let visible=false,timer:ReturnType<typeof setInterval>|undefined;
  const sync=()=>{clearInterval(timer);timer=undefined;if(!motion.matches&&visible&&!document.hidden&&!gesture.current&&!keyboardFocused.current)timer=setInterval(()=>{setNavigation('auto');setCurrent(n=>(n+1)%frames.length);},3200);};
  restart.current=sync;
  const observer=new IntersectionObserver(([e])=>{visible=e.isIntersecting;sync();},{threshold:.2});observer.observe(node);
  motion.addEventListener('change',sync);document.addEventListener('visibilitychange',sync);
  return()=>{clearInterval(timer);observer.disconnect();motion.removeEventListener('change',sync);document.removeEventListener('visibilitychange',sync);restart.current=()=>{};};
 },[]);
 return <div className="hero-slideshow" data-navigation={navigation} ref={container} role="group" aria-label="عکس‌های سالن؛ با کشیدن به چپ و راست یا کلیدهای جهت عکس را عوض کنید" tabIndex={0}
  onPointerDown={e=>{if(!e.isPrimary||e.button!==0)return;keyboardFocused.current=false;gesture.current={id:e.pointerId,x:e.clientX,y:e.clientY};restart.current();e.currentTarget.setPointerCapture(e.pointerId);}}
  onPointerUp={release} onPointerCancel={finishGesture} onLostPointerCapture={finishGesture}
  onFocus={e=>{keyboardFocused.current=e.currentTarget.matches(':focus-visible');restart.current();}} onBlur={()=>{keyboardFocused.current=false;restart.current();}}
  onKeyDown={e=>{if(!['ArrowLeft','ArrowRight','Home','End'].includes(e.key))return;e.preventDefault();keyboardFocused.current=true;setNavigation('keyboard');setCurrent(n=>e.key==='Home'?0:e.key==='End'?frames.length-1:(n+(e.key==='ArrowLeft'?1:-1)+frames.length)%frames.length);restart.current();}}
 >{frames.map((frame,i)=><img key={frame.id} data-hero-frame={frame.id} className={'hero-main-image hero-slide'+(i===current?' is-current':'')} src={frame.src} alt={frame.alt} aria-hidden={i!==current} fetchPriority={i===0?'high':'auto'} decoding="async" draggable={false}/>)}</div>;
}
