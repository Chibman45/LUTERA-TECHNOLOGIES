'use strict';
const menu=document.querySelector('.menu');
const nav=document.querySelector('#navigation');
function closeMenu(){nav.classList.remove('open');menu.setAttribute('aria-expanded','false')}
menu.addEventListener('click',()=>{const open=menu.getAttribute('aria-expanded')!=='true';menu.setAttribute('aria-expanded',String(open));nav.classList.toggle('open',open)});
document.addEventListener('keydown',e=>{if(e.key==='Escape'&&nav.classList.contains('open')){closeMenu();menu.focus()}});
nav.addEventListener('click',e=>{if(e.target.closest('a'))closeMenu()});
const rfq=document.querySelector('#rfq-form');
if(rfq){
 const category=rfq.elements.service_category,quantity=rfq.elements.quantity,date=rfq.elements.needed_by;
 const tomorrow=new Date();tomorrow.setDate(tomorrow.getDate()+1);
 date.min=`${tomorrow.getFullYear()}-${String(tomorrow.getMonth()+1).padStart(2,'0')}-${String(tomorrow.getDate()).padStart(2,'0')}`;
 const updateQuantity=()=>{quantity.required=['hardware','procurement'].includes(category.value);quantity.previousElementSibling.innerHTML='Quantity'+(quantity.required?' *':' <small>(optional)</small>')};
 category.addEventListener('change',updateQuantity);updateQuantity();
 date.addEventListener('input',()=>date.setCustomValidity(''));
}
for(const form of document.querySelectorAll('form')){
 let busy=false;
 form.addEventListener('submit',e=>{
 const honey=form.elements._honey;
 if(busy||honey?.value){e.preventDefault();return}
 if(form===rfq){
  const date=rfq.elements.needed_by;
  if(date.value&&date.value<date.min){e.preventDefault();date.setCustomValidity('Choose a future date.');date.reportValidity();return}
 }
 if(!form.reportValidity()){e.preventDefault();return}
 let stamp=form.querySelector('[name="privacy_acknowledged_at"]');
 if(!stamp){stamp=document.createElement('input');stamp.type='hidden';stamp.name='privacy_acknowledged_at';form.append(stamp)}
 stamp.value=new Date().toISOString();
 busy=true;
 const button=form.querySelector('button[type="submit"],button:not([type])');
 button.disabled=true;button.textContent='Continue to verification…';
 // Native HTTPS submission allows the provider to show its spam check and result.
 // No on-site success message is shown before the provider processes the request.
 });
 window.addEventListener('pageshow',()=>{busy=false;const button=form.querySelector('button[type="submit"],button:not([type])');button.disabled=false;button.textContent=form===rfq?'Submit quote request ↗':'Send message ↗'});
}
