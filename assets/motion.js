// Progressive enhancements: content remains visible when JavaScript is unavailable.
(() => {
 const reduced=matchMedia('(prefers-reduced-motion: reduce)');
 const fine=matchMedia('(hover: hover) and (pointer: fine)');
 const desktop=matchMedia('(min-width: 1025px)');
 const mobileOrTablet=!!navigator.userAgentData?.mobile||/Android|iPad|iPhone|iPod/i.test(navigator.userAgent)||(navigator.platform==='MacIntel'&&navigator.maxTouchPoints>1);
 const script=document.currentScript;
 const sceneURL=new URL('scene.js?v=experience1',script.src).href;
 const header=document.querySelector('header');
 const markScroll=()=>header.classList.toggle('is-scrolled',scrollY>20);
 addEventListener('scroll',markScroll,{passive:true});markScroll();
 let reveals=null;
 function configureReveals(){
  reveals?.disconnect();
  document.querySelectorAll('[data-reveal]').forEach(el=>{el.classList.remove('reveal-ready');el.style.removeProperty('--reveal-delay')});
  if(reduced.matches||!('IntersectionObserver' in window))return;
  reveals=new IntersectionObserver(entries=>{for(const entry of entries){if(!entry.isIntersecting)continue;entry.target.classList.add('is-revealed');reveals.unobserve(entry.target)}},{threshold:.1});
  document.querySelectorAll('section .section-head, section .card, section .category, section .step, section .bento-card, section .need-card, section .equipment-card, section .split > *, section .cta, .page-hero h1, .page-hero p').forEach((el,i)=>{
   el.dataset.reveal='';el.classList.add('reveal-ready');el.style.setProperty('--reveal-delay',`${(i%4)*65}ms`);reveals.observe(el);
  });
 }
 configureReveals();reduced.addEventListener('change',configureReveals);
 for(const card of document.querySelectorAll('.card,.category,.procurement-art')){
  card.addEventListener('pointermove',e=>{if(reduced.matches||!fine.matches)return;const r=card.getBoundingClientRect();card.style.setProperty('--tilt-x',`${-(e.clientY-r.top-r.height/2)/r.height*5}deg`);card.style.setProperty('--tilt-y',`${(e.clientX-r.left-r.width/2)/r.width*5}deg`);card.classList.add('is-tilted')},{passive:true});
  card.addEventListener('pointerleave',()=>{card.classList.remove('is-tilted');card.style.removeProperty('--tilt-x');card.style.removeProperty('--tilt-y')});
 }
 const host=document.querySelector('[data-hardware-scene]');if(!host)return;
 const button=document.querySelector('[data-motion-toggle]');
 const visual=host.closest('.visual');
 let controller=null,loading=false,failed=false,intersecting=false,userPaused=false,ready=false;
 function eligibleDesktop(){return desktop.matches&&fine.matches&&!mobileOrTablet&&!reduced.matches&&!navigator.connection?.saveData}
 function fallback(){controller?.dispose();controller=null;visual.classList.remove('scene-loaded');button.hidden=true}
 async function updateScene(){
  const eligible=eligibleDesktop();
  if(!eligible){fallback();return}
  if(controller||loading||failed||!intersecting||!ready)return;
  loading=true;
  try{
   button.disabled=true;
   const {mountScene}=await import(sceneURL);
   if(!eligibleDesktop())return;
   controller=mountScene(host);controller.setPaused(userPaused);
   visual.classList.add('scene-loaded');button.hidden=false;button.textContent=userPaused?'Resume animation':'Pause animation';
  }catch{failed=true;fallback()}finally{loading=false;button.disabled=false}
 }
 new IntersectionObserver(entries=>{intersecting=entries[0].isIntersecting;if(intersecting)updateScene()},{rootMargin:'120px'}).observe(host);
 for(const media of [reduced,desktop,fine])media.addEventListener('change',updateScene);
 host.addEventListener('scene-unavailable',()=>{failed=true;fallback()});
 button.addEventListener('click',()=>{if(!controller)return;userPaused=!userPaused;controller?.setPaused(userPaused);visual.closest('.hero').classList.toggle('motion-paused',userPaused);button.setAttribute('aria-pressed',String(userPaused));button.textContent=userPaused?'Resume animation':'Pause animation'});
 addEventListener('pagehide',fallback);
 addEventListener('pageshow',updateScene);
 function afterPaint(){const start=()=>{ready=true;updateScene()};if('requestIdleCallback' in window)requestIdleCallback(start,{timeout:2000});else setTimeout(start,300)}
 if(document.readyState==='complete')afterPaint();else addEventListener('load',afterPaint,{once:true});
})();
