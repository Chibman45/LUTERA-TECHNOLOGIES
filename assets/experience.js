'use strict';
(() => {
 const $=(s,root=document)=>root.querySelector(s);
 const $$=(s,root=document)=>[...root.querySelectorAll(s)];
 const base=new URL('../',document.currentScript.src).pathname;
 const escape=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const catalog={
  laptop:{title:'Business laptops',copy:'Portable equipment for hybrid teams, business travel and everyday work. Start with the applications your team uses and the portability they need.',points:['Match processor and memory to your applications','Consider battery, screen size and connectivity','Specify quantity and preferred operating system']},
  desktop:{title:'Desktops & all-in-ones'},workstation:{title:'Workstations'},
  server:{title:'Servers & storage',copy:'Build a foundation for shared applications, data and business workloads. Requirements depend on capacity, reliability and the systems you already use.',points:['Describe applications, users and storage requirements','Discuss backup, power and compatibility needs','Share your existing infrastructure and growth plans']},
  network:{title:'Networking equipment',copy:'Connect people, devices and workplaces with equipment suited to your environment. Start with the spaces, users and connections you need to support.',points:['Identify the spaces and users to be connected','Describe internet, wireless and wired requirements','Include existing equipment and installation needs']},
  printer:{title:'Office equipment'},accessory:{title:'Peripherals & accessories'}
 };
 const needs={office:{title:'New office setup',brief:'We are planning a new office setup. We need advice on equipment for our users, connectivity and the work the team will be doing.'},refresh:{title:'Equipment refresh',brief:'We are planning an equipment refresh. We would like to review existing devices, application requirements and suitable replacement options.'},remote:{title:'Remote team',brief:'We are equipping a remote or hybrid team. We need portable equipment and accessories suited to our applications and working arrangements.'},infrastructure:{title:'Infrastructure upgrade',brief:'We are planning an infrastructure upgrade. We need to review compute, storage, backup and network requirements alongside our existing systems.'}};
 const storageKey='lutera_equipment_v1';
 let items=[],businessNeed='',storageAvailable=true;
 function validItems(value){return Array.isArray(value)?value.filter(i=>i&&Object.hasOwn(catalog,i.id)&&Number.isSafeInteger(i.quantity)&&i.quantity>0&&i.quantity<=1000000).filter((i,n,a)=>a.findIndex(j=>j.id===i.id)===n).slice(0,8).map(i=>({id:i.id,quantity:i.quantity})):[]}
 try{const saved=JSON.parse(sessionStorage.getItem(storageKey)||'{}');items=validItems(saved.items);businessNeed=Object.hasOwn(needs,saved.need)?saved.need:''}catch{storageAvailable=false}
 const query=new URLSearchParams(location.search);
 if(query.has('items')){
  const incoming=(query.get('items')||'').slice(0,300).split(',').map(s=>{const [id,quantity]=s.split(':');return {id,quantity:Number(quantity)}});items=validItems(incoming);
 }
 if(Object.hasOwn(needs,query.get('need')))businessNeed=query.get('need');
 function persist(){try{sessionStorage.setItem(storageKey,JSON.stringify({items,need:businessNeed}));storageAvailable=true}catch{storageAvailable=false}}
 function summary(){return items.map(i=>`${catalog[i.id].title}: ${i.quantity}`).join('\n')}
 function total(){return items.reduce((n,i)=>n+i.quantity,0)}
 function quoteURL(){const params=new URLSearchParams();if(items.length)params.set('items',items.map(i=>`${i.id}:${i.quantity}`).join(','));if(businessNeed)params.set('need',businessNeed);return base+'request-quote/'+(params.size?'?'+params:'')}
 function announce(text){$('#site-announcer').textContent=text}
 let toastTimer;
 function toast(text){const el=$('.enquiry-toast');$('[data-toast-text]').textContent=text;el.hidden=false;clearTimeout(toastTimer);toastTimer=setTimeout(()=>el.hidden=true,4500);announce(text)}
 function updateCounts(){
  $$('[data-enquiry-count]').forEach(el=>{el.textContent=String(total());el.classList.toggle('has-items',items.length>0)});
  $$('[data-continue-quote]').forEach(el=>el.href=quoteURL());$('.enquiry-nav')?.setAttribute('aria-label','View enquiry list, '+total()+' items');
  const note=$('#enquiry-list-note');if(note)note.textContent=storageAvailable?'Your equipment list is kept in this browser tab. Contact details and free-text answers are not saved.':'Browser storage is unavailable. Use Continue to quote to carry this list in the page link, or copy it before leaving.';
  renderQuoteList();
 }
 // Native disclosure keeps both contact links available even without JavaScript.
 const contact=$('.floating-contact'),contactToggle=$('.floating-contact-toggle');
 function closeContact({focus=false}={}){if(!contact?.open)return;contact.open=false;if(focus)contactToggle.focus()}
 document.addEventListener('click',e=>{if(!contact?.contains(e.target))closeContact()});
 document.addEventListener('keydown',e=>{if(e.key==='Escape'&&contact?.open){closeContact({focus:true});e.preventDefault()}});
 contact?.addEventListener('focusout',e=>{if(e.relatedTarget&&!contact.contains(e.relatedTarget))closeContact()});
 const dialog=$('#enquiry-dialog');let returnFocus=null;
 function renderDrawer(){
  $('#enquiry-items').innerHTML=items.length?'<ul class="enquiry-lines">'+items.map(i=>`<li><div><b>${escape(catalog[i.id].title)}</b><button class="text-button" type="button" data-remove="${i.id}" aria-label="Remove ${escape(catalog[i.id].title)}">Remove</button></div><label>Quantity<input type="number" min="1" max="1000000" step="1" value="${i.quantity}" data-item-quantity="${i.id}" aria-label="Quantity for ${escape(catalog[i.id].title)}"></label></li>`).join('')+'</ul>':`<div class="empty-enquiry"><span aria-hidden="true">+</span><h3>Your next setup starts here.</h3><p>Add equipment from Solutions, compare options, or go straight to the quote form and describe what you need.</p></div>`;
  $('[data-clear-enquiry]').disabled=!items.length;$('[data-copy-enquiry]').disabled=!items.length;updateCounts();
 }
 function openDrawer(){closeContact();renderDrawer();returnFocus=document.activeElement;if(dialog.showModal){if(!dialog.open)dialog.showModal()}else{dialog.setAttribute('open','');dialog.setAttribute('role','dialog')}document.body.classList.add('drawer-open');$('.enquiry-toast').hidden=true;$('[data-close-enquiry]').focus()}
 function restoreFocus(){const target=returnFocus?.isConnected&&returnFocus.getClientRects().length?returnFocus:$('.enquiry-nav')?.getClientRects().length?$('.enquiry-nav'):contactToggle;target?.focus()}
 function closeDrawer(){if(dialog.close)dialog.close();else dialog.removeAttribute('open');document.body.classList.remove('drawer-open');restoreFocus()}
 dialog.addEventListener('close',()=>{document.body.classList.remove('drawer-open');restoreFocus()});
 dialog.addEventListener('click',e=>{if(e.target===dialog){const r=dialog.getBoundingClientRect();if(e.clientX<r.left||e.clientX>r.right||e.clientY<r.top||e.clientY>r.bottom)closeDrawer()}});
 document.addEventListener('click',e=>{
  const proceed=e.target.closest('[data-continue-quote]');if(proceed){const invalid=$$('[data-item-quantity]',dialog).find(input=>!input.checkValidity());if(invalid){e.preventDefault();invalid.reportValidity();return}}
  const open=e.target.closest('[data-open-enquiry]');if(open){e.preventDefault();openDrawer();return}
  if(e.target.closest('[data-close-enquiry]')){closeDrawer();return}
  const add=e.target.closest('[data-add],[data-explorer-add],[data-request]');
  if(add){const id=add.dataset.add||add.dataset.explorerAdd||add.dataset.request;if(!Object.hasOwn(catalog,id))return;const item=items.find(i=>i.id===id);if(item){if(!add.dataset.request)item.quantity=Math.min(item.quantity+1,1000000)}else items.push({id,quantity:1});persist();updateCounts();if(add.dataset.request){location.href=quoteURL()}else toast(catalog[id].title+' added to your enquiry.');return}
  const remove=e.target.closest('[data-remove]');if(remove){items=items.filter(i=>i.id!==remove.dataset.remove);persist();renderDrawer();$('[data-close-enquiry]').focus();announce('Equipment removed from your enquiry.');return}
  if(e.target.closest('[data-clear-enquiry]')){items=[];persist();renderDrawer();announce('Your equipment list is clear.');return}
 });
 dialog.addEventListener('change',e=>{if(!e.target.matches('[data-item-quantity]'))return;const item=items.find(i=>i.id===e.target.dataset.itemQuantity);const value=Number(e.target.value);if(!item)return;if(!Number.isSafeInteger(value)||value<1||value>1000000){e.target.setCustomValidity('Enter a whole number from 1 to 1,000,000.');e.target.reportValidity();return}e.target.setCustomValidity('');item.quantity=value;persist();updateCounts();announce('Equipment quantity updated.')});
 dialog.addEventListener('input',e=>{if(e.target.matches('[data-item-quantity]'))e.target.setCustomValidity('')});
 $('[data-copy-enquiry]').addEventListener('click',async()=>{try{await navigator.clipboard.writeText(summary());announce('Equipment list copied.');$('#enquiry-list-note').textContent='Equipment list copied.'}catch{let output=$('textarea',dialog);if(!output){output=document.createElement('textarea');output.readOnly=true;output.setAttribute('aria-label','Equipment list to copy');$('#enquiry-items').append(output)}output.value=summary();output.focus();output.select();$('#enquiry-list-note').textContent='Select and copy the equipment list above.'}});
 // Accessible equipment explorer: tab controls and real scene / image hotspots.
 function selectEquipment(id,{popup=false,focusTab=false}={}){
  if(!['laptop','server','network'].includes(id))return;
  const data=catalog[id];const selected=$(`[data-explore="${id}"]`);
  $$('[data-explore]').forEach(button=>{const active=button===selected;button.setAttribute('aria-selected',String(active));button.tabIndex=active?0:-1});
  if(selected){$('#equipment-panel').setAttribute('aria-labelledby',selected.id);if(focusTab)selected.focus();$('[data-explorer-title]').textContent=data.title;$('[data-explorer-copy]').textContent=data.copy;$('[data-explorer-points]').innerHTML=data.points.map(s=>'<li>'+escape(s)+'</li>').join('');$('[data-explorer-add]').dataset.explorerAdd=id;$('#equipment-panel [data-request]').dataset.request=id;$('.explorer-orbit > .icon').innerHTML=selected.querySelector('.icon').innerHTML;}
  $$('[data-hotspot]').forEach(el=>el.setAttribute('aria-expanded',String(popup&&el.dataset.hotspot===id)));
  const panel=$('#hotspot-detail');if(popup&&panel){panel.hidden=false;$('[data-hotspot-title]').textContent=data.title;$('[data-hotspot-copy]').textContent=data.copy;const request=$('[data-hotspot-request]');request.dataset.request=id;request.dataset.hotspotRequest=id;request.focus({preventScroll:true});panel.scrollIntoView({block:'nearest',behavior:matchMedia('(prefers-reduced-motion:reduce)').matches?'auto':'smooth'})}
 }
 $$('[data-explore]').forEach(button=>button.addEventListener('click',()=>selectEquipment(button.dataset.explore)));
 function tabKeyboard(container,selector,activate){container?.addEventListener('keydown',e=>{if(!['ArrowLeft','ArrowRight','ArrowUp','ArrowDown','Home','End'].includes(e.key)||!e.target.matches(selector))return;e.preventDefault();const buttons=$$(selector,container);const current=buttons.indexOf(e.target);let index=e.key==='Home'?0:e.key==='End'?buttons.length-1:(current+(['ArrowLeft','ArrowUp'].includes(e.key)?-1:1)+buttons.length)%buttons.length;activate(buttons[index]);buttons[index].focus()})}
 tabKeyboard($('.equipment-tabs'),'[data-explore]',b=>selectEquipment(b.dataset.explore));
 $$('[data-hotspot]').forEach(button=>button.addEventListener('click',()=>selectEquipment(button.dataset.hotspot,{popup:true})));
 document.addEventListener('equipment-select',e=>selectEquipment(e.detail.id,{popup:true}));
 function closeHotspot(){const panel=$('#hotspot-detail');if(!panel||panel.hidden)return;const selected=$('[data-hotspot][aria-expanded="true"]');panel.hidden=true;$$('[data-hotspot]').forEach(el=>el.setAttribute('aria-expanded','false'));selected?.focus()}
 $('.hotspot-close')?.addEventListener('click',closeHotspot);
 document.addEventListener('keydown',e=>{if(e.key==='Escape')closeHotspot()});
 // Comparisons retain at least two columns, preserving meaningful comparison.
 $$('[data-compare]').forEach(box=>box.addEventListener('change',()=>{if($$('[data-compare]:checked').length<2){box.checked=true;$('.compare-feedback').textContent='Keep at least two equipment types selected to compare.';return}$('.compare-feedback').textContent='Comparison updated.';$$('[data-compare-col]').forEach(cell=>{cell.hidden=!$(`[data-compare="${cell.dataset.compareCol}"]`).checked})}));
 const stages=[
  {title:'Start with the work it needs to do.',copy:'Share equipment types, users, applications, quantities and the location. A clear business goal is a good starting point if the specification is still open.',checks:['Your equipment or service requirements','Estimated quantities and delivery region','Preferred timing and optional budget guidance']},
  {title:'Turn requirements into suitable options.',copy:'We review the brief and clarify specifications, compatibility and scope. Alternatives can be discussed against your priorities; availability is confirmed individually.',checks:['Existing systems and application needs','Essential specifications versus preferences','Questions about setup or compatibility']},
  {title:'Review the details before deciding.',copy:'Consider the written quotation, including the proposed specification, price, scope and terms. Ask for clarification before committing to supply or services.',checks:['Proposed models and specifications','Warranty, payment and delivery terms','Any assumptions or service exclusions']},
  {title:'Agree the scope and the way forward.',copy:'Supply, delivery and service arrangements are agreed separately in writing. An online enquiry does not reserve equipment or place an order.',checks:['Written acceptance of agreed terms','Delivery and contact arrangements','The agreed installation or support scope']}
 ];
 for(const timeline of $$('[data-timeline]')){
  function setStage(button){const index=Number(button.dataset.stage),stage=stages[index];$$('[data-stage]',timeline).forEach(b=>{const active=b===button;b.setAttribute('aria-selected',String(active));b.tabIndex=active?0:-1});$('#stage-panel',timeline).setAttribute('aria-labelledby',button.id);$('[data-stage-label]',timeline).textContent=String(index+1).padStart(2,'0')+' / '+button.textContent.trim().replace(/^\d+\s*/, '').toUpperCase();$('[data-stage-title]',timeline).textContent=stage.title;$('[data-stage-copy]',timeline).textContent=stage.copy;$('[data-stage-checks]',timeline).innerHTML=stage.checks.map(s=>'<li>'+escape(s)+'</li>').join('')}
  $$('[data-stage]',timeline).forEach(button=>button.addEventListener('click',()=>setStage(button)));tabKeyboard($('.timeline-tabs',timeline),'[data-stage]',setStage);
 }
 // Three-step quote wizard. No personal/free-text draft is put in storage.
 const form=$('#rfq-form');let step=0,busy=false;
 function renderQuoteList(){const slot=$('[data-quote-list]');if(!slot)return;slot.innerHTML=items.length?'<ul>'+items.map(i=>'<li><span>'+escape(catalog[i.id].title)+'</span><b>× '+i.quantity+'</b></li>').join('')+'</ul>':'<p>No equipment selected yet. Describe your requirements below, or add items from Solutions.</p>';if(form){form.elements.equipment_list.value=summary();if(!form.elements.quantity.dataset.edited)form.elements.quantity.value=items.length?String(total()):'';renderReview()}}
 function formBrief(){if(!form)return '';const f=form.elements;return ['Business need: '+(needs[f.project_type.value]?.title||f.project_type.value||'Not specified'),'Service: '+f.service_category.options[f.service_category.selectedIndex].text,'Equipment list:\n'+(summary()||'No equipment selected'),'Requirements: '+f.requirements.value,'Total quantity: '+(f.quantity.value||'Not specified'),'Budget: '+(f.budget_range.value||'Not specified'),'Delivery region: '+(f.delivery_city_or_region.value||'Not specified'),'Preferred date: '+(f.needed_by.value||'Not specified'),'Additional notes: '+(f.additional_notes.value||'None')].join('\n\n')}
 function renderReview(){if(!form)return;$('[data-review-summary]').innerHTML='<pre>'+escape(formBrief())+'</pre>';form.elements.enquiry_summary.value=formBrief()}
 if(form){
  const steps=$$('[data-quote-step]',form),next=$('[data-wizard-next]'),back=$('[data-wizard-back]'),submit=$('#rfq-submit'),status=$('#wizard-status');
  form.noValidate=true;form.classList.add('wizard-enabled');next.hidden=false;
  const date=form.elements.needed_by,tomorrow=new Date();tomorrow.setDate(tomorrow.getDate()+1);date.min=`${tomorrow.getFullYear()}-${String(tomorrow.getMonth()+1).padStart(2,'0')}-${String(tomorrow.getDate()).padStart(2,'0')}`;
  function quantityRequired(){const q=form.elements.quantity;q.required=['hardware','procurement'].includes(form.elements.service_category.value);q.previousElementSibling.innerHTML='Total equipment quantity'+(q.required?' *':' <small>(optional)</small>')}
  function showStep(index,{focus=true}={}){step=index;steps.forEach((el,i)=>el.hidden=i!==step);$$('.wizard-progress li').forEach((li,i)=>{li.toggleAttribute('aria-current',i===step);if(i===step)li.setAttribute('aria-current','step');li.classList.toggle('is-complete',i<step)});back.hidden=step===0;next.hidden=step===2;submit.hidden=step!==2;status.textContent='';renderReview();if(focus){steps[step].tabIndex=-1;steps[step].focus({preventScroll:true});steps[step].scrollIntoView({block:'start',behavior:matchMedia('(prefers-reduced-motion:reduce)').matches?'auto':'smooth'})}}
  function firstInvalid(root){const controls=$$('input,select,textarea',root);for(const input of controls){input.removeAttribute('aria-invalid');if(input===date)input.setCustomValidity(date.value&&date.value<date.min?'Choose a future date.':'');if(!input.checkValidity())return input}return null}
  function flagInvalid(input){input.setAttribute('aria-invalid','true');status.textContent='Please check '+(input.labels?.[0]?.textContent.trim()||'the highlighted field')+'. '+input.validationMessage;input.focus();input.reportValidity()}
  next.addEventListener('click',()=>{const invalid=firstInvalid(steps[step]);if(invalid){flagInvalid(invalid);return}showStep(Math.min(step+1,2))});
  back.addEventListener('click',()=>showStep(Math.max(step-1,0)));
  form.addEventListener('keydown',e=>{if(e.key==='Enter'&&step<2&&e.target.tagName==='INPUT'){e.preventDefault();next.click()}});
  form.elements.service_category.addEventListener('change',quantityRequired);
  form.elements.quantity.addEventListener('input',()=>form.elements.quantity.dataset.edited='true');
  form.elements.project_type.addEventListener('change',()=>{businessNeed=Object.hasOwn(needs,form.elements.project_type.value)?form.elements.project_type.value:'';persist()});
  form.addEventListener('input',e=>{e.target.removeAttribute('aria-invalid');if(e.target===date)date.setCustomValidity('');renderReview()});
  if(businessNeed){form.elements.project_type.value=businessNeed;form.elements.requirements.value=needs[businessNeed].brief;form.elements.service_category.value='procurement'}
  if(['procurement','hardware','consulting','support','other'].includes(query.get('category')))form.elements.service_category.value=query.get('category');
  else if(items.length)form.elements.service_category.value='procurement';
  quantityRequired();showStep(0,{focus:false});
  form.addEventListener('submit',e=>{
   if(busy||form.elements._honey.value){e.preventDefault();return}
   for(let i=0;i<steps.length;i++){const invalid=firstInvalid(steps[i]);if(invalid){e.preventDefault();showStep(i);flagInvalid(invalid);return}}
   // Invalid list quantities in an open drawer must not silently enter the email.
   if(dialog.open&&$$('[data-item-quantity]',dialog).some(input=>!input.checkValidity())){e.preventDefault();return}
   renderReview();let stamp=form.querySelector('[name="privacy_acknowledged_at"]');if(!stamp){stamp=document.createElement('input');stamp.type='hidden';stamp.name='privacy_acknowledged_at';form.append(stamp)}stamp.value=new Date().toISOString();busy=true;submit.disabled=true;submit.textContent='Continue to verification…';
  });
  addEventListener('pageshow',()=>{busy=false;submit.disabled=false;submit.textContent='Submit quote request'});
 }
 if(location.pathname===base+'thank-you/'){items=[];businessNeed='';persist()}
 persist();renderDrawer();updateCounts();
 // Quote quick actions carry the list even if session storage is blocked.
 $$('a[href]').forEach(a=>{if(a.pathname===base+'request-quote/'&&!a.search)a.addEventListener('click',()=>a.href=quoteURL())});
})();
