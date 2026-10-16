'use strict';
const menu=document.querySelector('.menu');
const nav=document.querySelector('#navigation');
function closeMenu(){nav.classList.remove('open');menu.setAttribute('aria-expanded','false')}
menu.addEventListener('click',()=>{const open=menu.getAttribute('aria-expanded')!=='true';menu.setAttribute('aria-expanded',String(open));nav.classList.toggle('open',open)});
document.addEventListener('keydown',e=>{if(e.key==='Escape'&&nav.classList.contains('open')){closeMenu();menu.focus()}});
nav.addEventListener('click',e=>{if(e.target.closest('a,button'))closeMenu()});
// The quote wizard owns its validation and submission. The contact form remains
// a native HTTPS POST with a duplicate-click guard and acknowledgement timestamp.
for(const form of document.querySelectorAll('form:not(#rfq-form)')){
 let busy=false;
 const button=form.querySelector('button[type="submit"],button:not([type])');
 form.addEventListener('submit',e=>{
  if(busy||form.elements._honey?.value){e.preventDefault();return}
  if(!form.reportValidity()){e.preventDefault();return}
  let stamp=form.querySelector('[name="privacy_acknowledged_at"]');
  if(!stamp){stamp=document.createElement('input');stamp.type='hidden';stamp.name='privacy_acknowledged_at';form.append(stamp)}
  stamp.value=new Date().toISOString();busy=true;button.disabled=true;button.textContent='Continue to verification…';
 });
 window.addEventListener('pageshow',()=>{busy=false;button.disabled=false;button.textContent='Send message'});
}
