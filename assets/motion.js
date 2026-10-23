'use strict';
(() => {
 const header=document.querySelector('header');
 if(header)window.addEventListener('scroll',()=>header.classList.toggle('is-scrolled',window.scrollY>16),{passive:true});
 const hero=document.querySelector('[data-hero]');
 if(!hero)return;
 const media=hero.querySelector('[data-hero-media]');
 let scenes;
 try{scenes=JSON.parse(document.getElementById('hero-scenes').textContent)}catch{return}
 if(!Array.isArray(scenes)||scenes.length<2)return;
 const reduce=matchMedia('(prefers-reduced-motion: reduce)');
 const connection=navigator.connection;
 const enquiry=document.querySelector('#enquiry-dialog');
 const images=new Map([[0,media.querySelector('img')]]);
 let nextScene=1,inView=true,timer=null,busy=false;
 const canAnimate=()=>!reduce.matches&&!connection?.saveData;
 const canRun=()=>canAnimate()&&!document.hidden&&inView&&!enquiry?.open;
 function update(){
  clearTimeout(timer);timer=null;
  const running=canRun();hero.dataset.motion=running?'running':'paused';
  if(running&&!busy)timer=setTimeout(showNext,8000);
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
 async function showNext(){
  if(busy||!canRun())return;
  const index=nextScene;
  nextScene=(index+1)%scenes.length;
  busy=true;clearTimeout(timer);
  try{
   await load(index);
   // A download finishing after motion is suspended must not switch images.
   if(!canRun())return;
   for(const [key,image] of images)image.classList.toggle('is-active',key===index);
  }catch{
   // Preserve the current photo and try the following scene on the next cycle.
  }finally{busy=false;update()}
 }
 document.addEventListener('visibilitychange',update);
 window.addEventListener('pagehide',()=>clearTimeout(timer));
 window.addEventListener('pageshow',update);
 reduce.addEventListener('change',update);connection?.addEventListener('change',update);
 if('IntersectionObserver' in window)new IntersectionObserver(entries=>{inView=entries[0].isIntersecting;update()},{threshold:0}).observe(hero);
 if(enquiry)new MutationObserver(update).observe(enquiry,{attributes:true,attributeFilter:['open']});
 update();
})();
