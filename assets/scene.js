// Three.js r180, self-hosted. Loaded only for eligible desktop visitors.
import * as THREE from './vendor/three/three.module.min.js';
export function mountScene(host) {
 const canvas=document.createElement('canvas');
 canvas.setAttribute('aria-hidden','true');
 const renderer=new THREE.WebGLRenderer({canvas,alpha:true,antialias:true,powerPreference:'low-power'});
 renderer.setPixelRatio(Math.min(devicePixelRatio,1.5));
 renderer.outputColorSpace=THREE.SRGBColorSpace;
 renderer.setClearColor(0x000000,0);
 const scene=new THREE.Scene();
 const camera=new THREE.PerspectiveCamera(35,1,.1,60);
 camera.position.set(6,4.9,8.8);camera.lookAt(0,.6,0);
 scene.add(new THREE.HemisphereLight(0xb6e3ff,0x102141,3));
 const key=new THREE.DirectionalLight(0xffffff,4);key.position.set(-3,7,5);scene.add(key);
 const cyanLight=new THREE.PointLight(0x00d4ff,28,16);cyanLight.position.set(3,3,0);scene.add(cyanLight);
 const blueLight=new THREE.PointLight(0x126bff,22,16);blueLight.position.set(-4,1,3);scene.add(blueLight);
 const assembly=new THREE.Group();scene.add(assembly);
 const mat=(color,metalness=.4,roughness=.3)=>new THREE.MeshPhongMaterial({color,shininess:Math.round((1-roughness)*70),specular:0x5d7994});
 const navy=mat(0x142740,.65),metal=mat(0x99b1cb,.8,.23),dark=mat(0x071426,.5),blue=mat(0x126bff,.65);
 const glow=new THREE.MeshBasicMaterial({color:0x00d4ff});
 const screenMat=new THREE.MeshBasicMaterial({color:0x126bff});
 function box(parent,w,h,d,material,x=0,y=0,z=0){const mesh=new THREE.Mesh(new THREE.BoxGeometry(w,h,d),material);mesh.position.set(x,y,z);parent.add(mesh);return mesh;}
 function line(points,color=0x00b5f7,opacity=.5){const geometry=new THREE.BufferGeometry().setFromPoints(points.map(v=>new THREE.Vector3(...v)));const material=new THREE.LineBasicMaterial({color,transparent:true,opacity});const mesh=new THREE.Line(geometry,material);assembly.add(mesh);return mesh;}
 // Laptop: individually modeled chassis, keyboard, hinge and illuminated screen.
 const laptop=new THREE.Group();laptop.userData.equipmentId='laptop';laptop.position.set(-1.1,.15,1);laptop.rotation.y=.15;assembly.add(laptop);
 box(laptop,2.45,.13,1.6,metal);
 box(laptop,2.2,.018,1.22,navy,0,.075,-.1);
 for(let row=0;row<5;row++)for(let col=0;col<12;col++)box(laptop,.13,.02,.115,metal,-.97+col*.176,.09,-.6+row*.16);
 box(laptop,.7,.018,.32,metal,0,.091,.44);
 const lid=new THREE.Group();lid.position.set(0,.08,-.77);lid.rotation.x=-.16;laptop.add(lid);
 box(lid,2.46,1.58,.11,metal,0,.79,0);
 box(lid,2.27,1.37,.016,dark,0,.8,.063);
 box(lid,2.13,1.22,.017,screenMat,0,.81,.076);
 // Dashboard bars and data lines are real geometry, not a video or texture download.
 for(let i=0;i<5;i++)box(lid,.18,.2+i*.11,.02,blue,-.7+i*.35,.55+i*.055,.092);
 for(let i=0;i<3;i++)box(lid,1.55-i*.28,.025,.02,glow,-i*.14,1.2-i*.09,.093);
 box(lid,.07,.025,.025,glow,0,1.49,.07);
 // Server cabinet and modular drive trays.
 const server=new THREE.Group();server.userData.equipmentId='server';server.position.set(1.35,1.08,-.65);assembly.add(server);
 box(server,1.2,2.65,1.15,navy,0,.24,0);
 box(server,1.24,.08,1.19,metal,0,1.6,0);
 for(let i=0;i<5;i++){
  box(server,1.02,.34,.05,dark,0,1.25-i*.43,.6);
  for(let j=0;j<6;j++)box(server,.07,.025,.025,metal,-.34+j*.09,1.28-i*.43,.635);
  box(server,.045,.045,.025,glow,.38,1.25-i*.43,.635);
 }
 box(server,.065,.065,.03,glow,0,-.71,.61);
 // Network switch, antennae, port lights.
 const network=new THREE.Group();network.userData.equipmentId='network';network.position.set(1.4,.01,1.7);assembly.add(network);
 box(network,1.3,.27,.75,metal);
 box(network,1.15,.18,.02,navy,0,0,.39);
 for(let i=0;i<6;i++)box(network,.11,.08,.025,glow,-.45+i*.18,0,.408);
 box(network,.045,.7,.045,navy,-.48,.44,-.22);box(network,.045,.7,.045,navy,.48,.44,-.22);
 // Disc and concentric orbital paths bind the equipment into one connected setup.
 const platform=new THREE.Mesh(new THREE.CylinderGeometry(3.12,3.12,.055,80),new THREE.MeshPhongMaterial({color:0x0a1f37,shininess:40,transparent:true,opacity:.8}));
 platform.position.y=-.3;assembly.add(platform);
 const rings=[];
 for(const [radius,color] of [[2.68,0x126bff],[3.15,0x00d4ff]]){
  const ring=new THREE.Mesh(new THREE.TorusGeometry(radius,.012,6,100),new THREE.MeshBasicMaterial({color,transparent:true,opacity:.7}));ring.rotation.x=Math.PI/2;ring.position.y=-.25;assembly.add(ring);rings.push(ring);
 }
 line([[1.4,-.21,1.7],[1.4,-.21,2.2],[-1.1,-.21,2.2],[-1.1,-.21,1]]);line([[-1.1,-.21,1],[1.35,-.21,1],[1.35,-.21,-.65]]);
 const packets=[];
 for(let i=0;i<4;i++){const mesh=new THREE.Mesh(new THREE.SphereGeometry(.045,8,6),glow);assembly.add(mesh);packets.push(mesh)}
 const particles=new THREE.Group();assembly.add(particles);
 for(let i=0;i<18;i++){const mesh=new THREE.Mesh(new THREE.BoxGeometry(.035,.035,.035),i%3?blue:glow);const angle=i*2.4;mesh.position.set(Math.cos(angle)*(2.4+i*.04),.3+(i%5)*.52,Math.sin(angle)*2.6);particles.add(mesh)}
 let width=0,height=0,frame=0,last=0,elapsed=0,inView=true,paused=false,disposed=false,tx=0,ty=0;
 const media=matchMedia('(prefers-reduced-motion: reduce)');
 function resize(){width=host.clientWidth;height=host.clientHeight;if(!width||!height)return;renderer.setSize(width,height,false);camera.aspect=width/height;camera.updateProjectionMatrix();draw()}
 const anchors=[['laptop',laptop,.8],['server',server,1],['network',network,.35]].map(([id,group,y])=>({element:host.closest('.visual').querySelector(`[data-hotspot="${id}"]`),group,y}));
 const projection=new THREE.Vector3();
 function draw(){renderer.render(scene,camera);for(const anchor of anchors){if(!anchor.element)continue;projection.set(0,anchor.y,0);anchor.group.localToWorld(projection);projection.project(camera);anchor.element.style.left=((projection.x+1)/2*width)+'px';anchor.element.style.top=((-projection.y+1)/2*height)+'px'}}
 function animate(now){frame=0;if(disposed||paused||!inView||document.hidden||media.matches)return;
  if(now-last>=32){elapsed+=Math.min((now-last)/1000,.06);last=now;
   assembly.rotation.y=THREE.MathUtils.lerp(assembly.rotation.y,tx*.26+Math.sin(elapsed*.25)*.07,.05);
   assembly.rotation.x=THREE.MathUtils.lerp(assembly.rotation.x,ty*.075,.05);
   laptop.position.y=.15+Math.sin(elapsed*.9)*.055;
   server.position.y=1.08+Math.sin(elapsed*.7+1)*.035;
   particles.rotation.y=elapsed*.035;
   packets.forEach((mesh,i)=>{const a=elapsed*.7+i*Math.PI/2;mesh.position.set(Math.cos(a)*2.68,-.19,Math.sin(a)*2.68)});
   draw();
  }
  frame=requestAnimationFrame(animate);
 }
 function sync(){if(frame){cancelAnimationFrame(frame);frame=0}if(!disposed&&!paused&&inView&&!document.hidden&&!media.matches){last=performance.now();frame=requestAnimationFrame(animate)}}
 let touchStart=null;
 function startTouch(e){if(e.pointerType==='touch')touchStart={x:e.clientX,y:e.clientY}}
 function pointer(e){if(e.pointerType==='touch')return;const r=host.getBoundingClientRect();tx=(e.clientX-r.left)/r.width-.5;ty=(e.clientY-r.top)/r.height-.5}
 function reset(){tx=0;ty=0;touchStart=null}
 const raycaster=new THREE.Raycaster(),cursor=new THREE.Vector2();
 function pick(e){if(e.pointerType==='touch'){const start=touchStart;touchStart=null;if(!start||Math.hypot(e.clientX-start.x,e.clientY-start.y)>12)return}const rect=host.getBoundingClientRect();cursor.set((e.clientX-rect.left)/rect.width*2-1,-((e.clientY-rect.top)/rect.height)*2+1);raycaster.setFromCamera(cursor,camera);const hit=raycaster.intersectObjects([laptop,server,network],true)[0];if(!hit)return;let target=hit.object;while(target&&!target.userData.equipmentId)target=target.parent;if(target)host.dispatchEvent(new CustomEvent('equipment-select',{bubbles:true,detail:{id:target.userData.equipmentId}}))}
 const observer=new IntersectionObserver(entries=>{inView=entries[0].isIntersecting;sync()},{threshold:.05});observer.observe(host);
 const resizer=new ResizeObserver(resize);resizer.observe(host);
 host.addEventListener('pointercancel',reset);host.addEventListener('pointerdown',startTouch,{passive:true});host.addEventListener('pointerup',pick);host.addEventListener('pointermove',pointer,{passive:true});host.addEventListener('pointerleave',reset);
 document.addEventListener('visibilitychange',sync);media.addEventListener('change',sync);
 function lost(e){e.preventDefault();dispose();host.dispatchEvent(new Event('scene-unavailable'))}
 canvas.addEventListener('webglcontextlost',lost);
 function dispose(){if(disposed)return;disposed=true;cancelAnimationFrame(frame);observer.disconnect();resizer.disconnect();host.removeEventListener('pointercancel',reset);host.removeEventListener('pointerdown',startTouch);host.removeEventListener('pointerup',pick);host.removeEventListener('pointermove',pointer);host.removeEventListener('pointerleave',reset);document.removeEventListener('visibilitychange',sync);media.removeEventListener('change',sync);canvas.removeEventListener('webglcontextlost',lost);const geometries=new Set(),materials=new Set();scene.traverse(o=>{if(o.geometry)geometries.add(o.geometry);if(o.material)materials.add(o.material)});geometries.forEach(g=>g.dispose());materials.forEach(m=>m.dispose());renderer.dispose();canvas.remove();anchors.forEach(({element})=>{element?.style.removeProperty('left');element?.style.removeProperty('top')})}
 resize();draw();host.append(canvas);sync();
 return {setPaused(value){paused=value;sync()},dispose};
}
