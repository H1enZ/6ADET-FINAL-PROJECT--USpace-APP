import { OPEN_MS, SEAL_MS, openingAt, sealingAt } from './capsule-frames.js';
import { createCapsulePainter } from './capsule-painter.js';
const reduced=window.matchMedia('(prefers-reduced-motion: reduce)');
const stage=document.createElement('section');stage.className='capsule-experience';stage.hidden=true;stage.setAttribute('aria-label','Time Capsule envelope demo');
stage.innerHTML=`<p class="capsule-dedication">A little love, saved for later.</p>
  <div class="capsule-scene app-ceremony"><canvas class="capsule-canvas" width="720" height="1023" aria-hidden="true"></canvas></div>
  <div class="capsule-interface" id="capsule-interface" hidden></div>
  <div class="capsule-controls"><button class="button capsule-toggle" type="button" aria-expanded="false" aria-controls="capsule-interface">Open envelope</button><button class="button button-outline capsule-seal" type="button" hidden>Seal again</button></div>
  <p class="capsule-status" role="status">A little love, waiting to be opened.</p>
  <label class="capsule-scenario-label" for="capsule-scenario">Explore a demo</label><select id="capsule-scenario"><option value="ready">Ready to open</option><option value="locked">Still waiting · locked example</option></select>
  <p class="capsule-disclosure">Interactive demo · Fictional sample letter. Your real capsules keep their release dates and account access rules.</p>`;
document.querySelector('#preview-panel').append(stage);
const canvas=stage.querySelector('canvas'),draw=createCapsulePainter(canvas),toggle=stage.querySelector('.capsule-toggle'),seal=stage.querySelector('.capsule-seal'),content=stage.querySelector('.capsule-interface'),scenario=stage.querySelector('select'),status=stage.querySelector('.capsule-status');
const release=Date.now()+7*86400000;
let progress=0,mode='opening',direction=0,raf=0,last=0,timer;
function paint(){draw(mode==='sealing'?sealingAt(progress):openingAt(progress),progress,mode!=='sealing',scenario.value==='locked');stage.dataset.progress=progress.toFixed(5);stage.dataset.ceremony=mode;}
function updateCountdown(){const el=content.querySelector('.capsule-countdown');if(!el)return;const min=Math.max(0,Math.ceil((release-Date.now())/60000));el.textContent=`${Math.floor(min/1440)}d · ${String(Math.floor(min%1440/60)).padStart(2,'0')}h · ${String(min%60).padStart(2,'0')}m`;}
function renderContent(){clearInterval(timer);if(scenario.value==='locked'){
  content.innerHTML='<span class="icon icon-lock capsule-lock" aria-hidden="true"></span><h4>Not quite time, my love.</h4><p>The letter stays protected until its release date.</p><p class="capsule-countdown"></p><p class="capsule-release"></p><p class="capsule-content-note">Locked demo · No protected letter has been loaded.</p>';
  content.querySelector('.capsule-release').textContent=`Demo release: ${new Intl.DateTimeFormat('en',{dateStyle:'medium',timeStyle:'short'}).format(release)}`;updateCountdown();timer=setInterval(updateCountdown,1000);
}else content.replaceChildren();}
function conceal(){content.hidden=true;toggle.setAttribute('aria-expanded','false');}
function settle(){direction=0;last=0;if(mode==='sealing'||progress===0){mode='opening';progress=0;stage.dataset.state='sealed';toggle.textContent='Open envelope';seal.hidden=true;conceal();status.textContent='Sealed. Safe for a little later.';}else{stage.dataset.state='open';toggle.textContent='Close envelope';seal.hidden=false;reveal();}paint();}
function tick(now){if(!last)last=now;progress=Math.max(0,Math.min(1,progress+(now-last)/(mode==='sealing'?SEAL_MS:OPEN_MS)*direction));last=now;paint();if(progress===0&&direction<0||progress===1&&direction>0)settle();else raf=requestAnimationFrame(tick);}
function run(dir){cancelAnimationFrame(raf);direction=dir;last=0;conceal();seal.hidden=true;stage.dataset.state=mode==='sealing'?'sealing':dir>0?'opening':'closing';toggle.textContent=dir>0?'Close envelope':'Open envelope';status.textContent=mode==='sealing'?'Folding, tying the ribbon, and sealing with wax…':dir>0?'Warm light, a lifted seal, a letter unfolding…':'Folding the letter back into its envelope…';if(reduced.matches){progress=dir>0?1:0;settle();}else raf=requestAnimationFrame(tick);}
function change(){if(mode==='sealing'){cancelAnimationFrame(raf);mode='opening';progress=0;settle();return;}run(direction===1||progress===1?-1:1);}
function reveal(){if(progress!==1||mode!=='opening')return;const locked=scenario.value==='locked';content.hidden=!locked;toggle.setAttribute('aria-expanded',String(locked));status.textContent=locked?'Envelope opened. This demo letter remains locked.':'Your letter is open.';}
toggle.addEventListener('click',change);canvas.addEventListener('click',()=>{if(progress===1)reveal();else if(!direction)change();});
seal.addEventListener('click',()=>{mode='sealing';progress=0;run(1);});
function reset(){cancelAnimationFrame(raf);mode='opening';progress=0;settle();}
scenario.addEventListener('change',()=>{reset();renderContent();});
reduced.addEventListener('change',()=>{if(reduced.matches&&direction){cancelAnimationFrame(raf);progress=direction>0?1:0;settle();}});
export function showCapsulePreview(visible){stage.hidden=!visible;document.querySelector('#preview-panel').classList.toggle('shows-capsule',visible);if(visible){document.querySelector('.preview-device').hidden=true;renderContent();paint();}else{clearInterval(timer);reset();}}
paint();
