'use strict';
(() => {
 const header=document.querySelector('header');
 if(header)window.addEventListener('scroll',()=>header.classList.toggle('is-scrolled',window.scrollY>16),{passive:true});
 const hero=document.querySelector('[data-hero]');
 if(!hero)return;
 const media=hero.querySelector('[data-hero-media]');
 const controls=hero.querySelector('.hero-controls');
 let scenes;
 try{scenes=JSON.parse(document.getElementById('hero-scenes').textContent)}catch{return}
 if(!Array.isArray(scenes)||scenes.length<2)return;
 const reduce=matchMedia('(prefers-reduced-motion: reduce)');
 const connection=navigator.connection;
 const pause=hero.querySelector('[data-hero-pause]');
 const previous=hero.querySelector('[data-hero-previous]');
 const next=hero.querySelector('[data-hero-next]');
 const counter=hero.querySelector('[data-hero-counter]');
 const status=hero.querySelector('[data-hero-status]');
 const enquiry=document.querySelector('#enquiry-dialog');
 const images=new Map([[0,media.querySelector('img')]]);
 let current=0,userPaused=false,inView=true,timer=null,busy=false;
 const canAnimate=()=>!reduce.matches&&!connection?.saveData;
 const canRun=()=>canAnimate()&&!userPaused&&!document.hidden&&inView&&!enquiry?.open;
 function update(){
  clearTimeout(timer);timer=null;
  const running=canRun();hero.dataset.motion=running?'running':'paused';
  pause.hidden=!canAnimate();pause.setAttribute('aria-pressed',String(userPaused));
  const label=userPaused?'Play background motion':'Pause background motion';
  pause.setAttribute('aria-label',label);pause.title=label;
  hero.querySelector('[data-hero-pause-icon]').toggleAttribute('hidden',userPaused);
  hero.querySelector('[data-hero-play-icon]').toggleAttribute('hidden',!userPaused);
  if(running&&!busy)timer=setTimeout(()=>show(current+1,false),8000);
 }
 async function load(index){
  if(images.has(index))return images.get(index);
  const image=new Image();image.className='hero-slide';image.alt='';
  image.width=1920;image.height=1200;image.decoding='async';image.sizes='100vw';
  image.style.objectPosition=scenes[index].position;
  image.srcset=scenes[index].srcset;image.src=scenes[index].src;
  await image.decode();
  media.append(image);images.set(index,image);
  // Establish opacity zero before switching to the decoded image.
  await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));
  return image;
 }
 async function show(requested,manual){
  if(busy)return;
  const index=(requested+scenes.length)%scenes.length;
  busy=true;clearTimeout(timer);previous.disabled=true;next.disabled=true;
  try{
   const image=await load(index);
   // An automatic download finishing after the visitor pauses must not switch.
   if(!manual&&!canRun())return;
   for(const [key,other] of images)other.classList.toggle('is-active',key===index);
   current=index;counter.textContent=`${index+1} / ${scenes.length}`;
   counter.setAttribute('aria-label',`Image ${index+1} of ${scenes.length}`);
   if(manual)status.textContent=`Image ${index+1} of ${scenes.length}: ${scenes[index].name}.`;
  }catch{
   if(manual)status.textContent='That image could not load. The current image remains visible.';
  }finally{busy=false;previous.disabled=false;next.disabled=false;update()}
 }
 pause.addEventListener('click',()=>{userPaused=!userPaused;update()});
 previous.addEventListener('click',()=>show(current-1,true));
 next.addEventListener('click',()=>show(current+1,true));
 document.addEventListener('visibilitychange',update);
 window.addEventListener('pagehide',()=>clearTimeout(timer));
 window.addEventListener('pageshow',update);
 reduce.addEventListener('change',update);connection?.addEventListener('change',update);
 if('IntersectionObserver' in window)new IntersectionObserver(entries=>{inView=entries[0].isIntersecting;update()},{threshold:0}).observe(hero);
 if(enquiry)new MutationObserver(update).observe(enquiry,{attributes:true,attributeFilter:['open']});
 controls.hidden=false;update();
})();
