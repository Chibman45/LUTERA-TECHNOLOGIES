'use strict';
// Content is visible by default. Motion is limited to short CSS state changes.
(() => {
 const header=document.querySelector('header');
 if(!header)return;
 const update=()=>header.classList.toggle('is-scrolled',window.scrollY>16);
 window.addEventListener('scroll',update,{passive:true});
 // Scroll events update the shadow without forcing startup layout.
})();
