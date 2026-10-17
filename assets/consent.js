'use strict';
(() => {
 const panel=document.querySelector('#cookie-consent');
 if(!panel)return;
 const settings=[...document.querySelectorAll('[data-cookie-settings]')];
 const current=panel.querySelector('#cookie-current');
 const feedback=document.querySelector('#cookie-feedback');
 const key='lutera_cookie_consent_v1',version=1,lifetime=180*24*60*60*1000;
 let choice=null,returnFocus=null,feedbackTimer;
 function read(){
  try{
   const value=JSON.parse(localStorage.getItem(key));
   const now=Date.now();
   if(value?.version===version&&['accepted','rejected'].includes(value.choice)&&
      Number.isFinite(value.chosenAt)&&Number.isFinite(value.expiresAt)&&
      value.chosenAt<=now&&value.expiresAt>now&&value.expiresAt-value.chosenAt===lifetime)return value;
  }catch{}
  return null;
 }
 function show(trigger){
  clearTimeout(feedbackTimer);feedback.textContent='';
  returnFocus=trigger||null;
  current.hidden=!choice;
  current.textContent=choice?`Your current choice: optional cookies ${choice.choice}. No optional cookies are currently installed.`:'';
  panel.hidden=false;
  // Do not interrupt a first-time visitor's focus. Explicit settings requests
  // move focus to the controls; this non-modal notice leaves navigation usable.
  if(trigger)panel.querySelector('[data-cookie-choice]').focus({preventScroll:true});
 }
 function hide(){
  const focused=panel.contains(document.activeElement);
  panel.hidden=true;
  if(returnFocus?.isConnected)returnFocus.focus({preventScroll:true});
  else if(focused)settings[0]?.focus({preventScroll:true});
  returnFocus=null;
 }
 for(const button of settings){
  button.hidden=false;
  button.addEventListener('click',()=>show(button));
 }
 panel.addEventListener('click',event=>{
  const button=event.target.closest('[data-cookie-choice]');
  if(!button)return;
  const chosenAt=Date.now();
  choice={version,choice:button.dataset.cookieChoice,chosenAt,expiresAt:chosenAt+lifetime};
  let saved=true;
  try{localStorage.setItem(key,JSON.stringify(choice))}catch{saved=false}
  hide();
  feedback.textContent=(choice.choice==='rejected'?'Optional cookies rejected.':'Privacy preference accepted. No optional cookies are currently used.')+
   (saved?' You can change your choice in Cookie settings.':' Browser storage is blocked, so this choice lasts for the current page only.');
  clearTimeout(feedbackTimer);feedbackTimer=setTimeout(()=>{feedback.textContent=''},6000);
 });
 panel.addEventListener('keydown',event=>{
  if(event.key==='Escape'&&choice){event.preventDefault();hide()}
 });
 window.addEventListener('storage',event=>{
  if(event.key!==key&&event.key!==null)return;
  choice=read();
  if(choice)hide();else show();
 });
 choice=read();
 if(!choice)show();
})();
