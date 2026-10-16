// Native navigation and normal scrolling remain in charge of the experience.
(() => {
 'use strict';
 const reduced=matchMedia('(prefers-reduced-motion:reduce)');
 const desktop=matchMedia('(min-width:1024px)');
 const tablet=matchMedia('(min-width:768px)');
 const pointer=matchMedia('(any-pointer:fine)');
 const phone=/iPhone|iPod|Android.*Mobile|Windows Phone/i.test(navigator.userAgent);
 let keyboardNavigation=false;
 const sceneEligible=()=>!phone&&(desktop.matches||(tablet.matches&&(pointer.matches||keyboardNavigation)));
 const root=document.documentElement;
 const motionAllowed=()=>!reduced.matches&&!navigator.connection?.saveData;
 let scheduleStory=()=>{};
 function capabilities(){root.classList.toggle('cinema-capable',motionAllowed()&&sceneEligible())}
 for(const media of [reduced,desktop,tablet,pointer])media.addEventListener('change',capabilities);
 addEventListener('keydown',e=>{if(e.isTrusted&&e.key==='Tab'&&!keyboardNavigation){keyboardNavigation=true;capabilities();scheduleStory()}});
 navigator.connection?.addEventListener('change',capabilities);capabilities();
 const nativeTransitions='onpageswap' in window&&'ViewTransition' in window;
 const base=new URL('../',document.currentScript.src).pathname;
 let navigationTimer=0,navigating=false,destination=null;
 function resetNavigation(){clearTimeout(navigationTimer);navigating=false;destination=null;root.classList.remove('cinema-leaving','cinema-arriving')}
 function enter(){if(navigating)return;resetNavigation();if(!motionAllowed()||nativeTransitions)return;root.classList.add('cinema-arriving');navigationTimer=setTimeout(resetNavigation,600)}
 // Browsers without cross-document transitions use a brief CSS curtain. Keep
 // native anchors, downloads, external links and modified clicks untouched.
 document.addEventListener('click',e=>{
  const a=e.target.closest('a[href]');
  if(!a||e.defaultPrevented||e.button!==0||e.metaKey||e.ctrlKey||e.shiftKey||e.altKey||a.download||a.hasAttribute('download')||(a.target&&a.target!=='_self')||!motionAllowed()||nativeTransitions)return;
  const url=new URL(a.href,location.href);
  if(url.origin!==location.origin||!url.pathname.startsWith(base)||url.hash||(url.pathname===location.pathname&&url.search===location.search))return;
  if(navigating){e.preventDefault();return}
  e.preventDefault();clearTimeout(navigationTimer);navigating=true;destination=url.href;root.classList.remove('cinema-arriving');root.classList.add('cinema-leaving');
  navigationTimer=setTimeout(()=>location.assign(url.href),220);
 });
 addEventListener('pageshow',enter);
 addEventListener('pagehide',resetNavigation);
 for(const event of ['pageswap','pagereveal'])addEventListener(event,e=>{if(!motionAllowed())e.viewTransition?.skipTransition()});
 reduced.addEventListener('change',()=>{if(reduced.matches){const target=destination;resetNavigation();if(target)location.assign(target)}});
 const story=document.querySelector('[data-cinema-story]');
 if(!story)return;
 const steps=[...story.querySelectorAll('[data-story-step]')];
 const links=[...story.querySelectorAll('[data-story-link]')];
 const captions=['Discover','Design','Build & connect','Launch & support'];
 const pause=story.querySelector('[data-cinema-pause]');
 const hero=document.querySelector('.hero');
 let frame=0,paused=false,active=-1,frozenProgress=.35;
 const clamp=(n,min,max)=>Math.min(max,Math.max(min,n));
 function render(){
  frame=0;if(document.hidden)return;
  const middle=innerHeight*.55;
  let chapter=0,distance=Infinity;
  const centers=steps.map(step=>{const r=step.getBoundingClientRect();return r.top+r.height/2});
  centers.forEach((center,i)=>{const d=Math.abs(center-middle);if(d<distance){distance=d;chapter=i}});
  if(chapter!==active){active=chapter;story.dataset.chapter=String(active);links.forEach((link,i)=>{if(i===active)link.setAttribute('aria-current','step');else link.removeAttribute('aria-current')});steps.forEach((step,i)=>step.classList.toggle('is-active',i===active));story.querySelector('[data-story-number]').textContent=String(active+1).padStart(2,'0')+' / 04';story.querySelector('[data-story-caption]').textContent=captions[active]}
  const progress=clamp((middle-centers[0])/(centers[3]-centers[0]||1),0,1);
  const animate=motionAllowed()&&sceneEligible()&&!paused;
  story.classList.toggle('cinema-motion',animate);
  story.style.setProperty('--story-progress',progress.toFixed(4));
  if(animate)frozenProgress=progress;
  story.style.setProperty('--scene-progress',motionAllowed()&&sceneEligible()?frozenProgress.toFixed(4):'0.35');
  pause.hidden=!motionAllowed()||!sceneEligible();
  // Independent translate/scale properties preserve the existing hero entrance.
  const heroProgress=animate&&hero?clamp(-hero.getBoundingClientRect().top/hero.offsetHeight,0,1):0;
  hero?.style.setProperty('--hero-travel',heroProgress.toFixed(4));
 }
 function schedule(){if(!frame)frame=requestAnimationFrame(render)}
 pause.addEventListener('click',()=>{paused=!paused;pause.setAttribute('aria-pressed',String(paused));pause.textContent=paused?'Resume scene motion':'Pause scene motion';schedule()});
 addEventListener('scroll',schedule,{passive:true});addEventListener('resize',schedule,{passive:true});
 addEventListener('pageshow',schedule);document.addEventListener('visibilitychange',schedule);
 for(const media of [reduced,desktop,tablet,pointer])media.addEventListener('change',schedule);
 scheduleStory=schedule;
 navigator.connection?.addEventListener('change',schedule);
 addEventListener('pagehide',()=>{cancelAnimationFrame(frame);frame=0});
 schedule();
})();
