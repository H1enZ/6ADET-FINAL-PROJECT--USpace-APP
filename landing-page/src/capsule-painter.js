// Canvas port of the active Flutter _Scene and CustomPainters, not the legacy
// seal_opening.dart effect. Coordinates are the original 360 logical-pixel scene.
const W=360, H=W*1.42;
const colors = { light:'#F3E2C2',paper:'#E9D3AE',deep:'#D8B988',ink:'#2E1B0F',soft:'#6B4A30' };
const path = (points) => {const p=new Path2D();points.forEach(([x,y],i)=>i?p.lineTo(x,y):p.moveTo(x,y));p.closePath();return p;};
const gradient = (ctx,x,y,w,h,stops) => {const g=ctx.createLinearGradient(x,y,x+w,y+h);stops.forEach(([t,c])=>g.addColorStop(t,c));return g;};
const circle = (ctx,x,y,r,color) => {ctx.beginPath();ctx.arc(x,y,r,0,Math.PI*2);ctx.fillStyle=color;ctx.fill();};
const cache=new Map();
function paper(w,h,seed=23,edge=.45) {
  const key=[Math.round(w),Math.round(h/4)*4,seed,edge].join(':'); if(cache.has(key)) return cache.get(key);
  if(cache.size>128)cache.delete(cache.keys().next().value);
  const c=document.createElement('canvas');c.width=Math.ceil(w*2);c.height=Math.ceil(h*2);const ctx=c.getContext('2d');ctx.scale(2,2);
  // Texture distribution is deterministic; Dart and JS random generators differ.
  let n=seed; const random=()=>{n=(Math.imul(n,1664525)+1013904223)>>>0;return n/4294967296;};
  ctx.fillStyle=gradient(ctx,0,0,w,h,[[0,colors.light],[.55,colors.paper],[1,colors.deep]]);ctx.fillRect(0,0,w,h);
  for(let i=0;i<Math.max(6,Math.min(48,Math.round(w*h/14000)));i++) {
    const x=random()*w,y=random()*h,r=40+random()*90,light=random()<.4;
    const g=ctx.createRadialGradient(x,y,0,x,y,r);g.addColorStop(0,light?'#F3E2C259':'#6B4A3014');g.addColorStop(1,'#6B4A3000');circle(ctx,x,y,r,g);
  }
  ctx.strokeStyle='#6B4A3014';ctx.lineWidth=.7;
  for(let i=0;i<Math.max(40,Math.min(420,Math.round(w*h/1600)));i++){const x=random()*w,y=random()*h,a=random()*Math.PI,l=2+random()*6;ctx.beginPath();ctx.moveTo(x,y);ctx.lineTo(x+Math.cos(a)*l,y+Math.sin(a)*l);ctx.stroke();}
  for(let i=0;i<Math.max(5,Math.min(40,Math.round(w*h/15000)));i++){const x=random()*w,y=random()*h,r=.6+random()*1.2;for(let j=0;j<3;j++)circle(ctx,x+(random()-.5)*r*2.2,y+(random()-.5)*r*2.2,r*(.4+random()*.6),'#8A552852');}
  ctx.fillStyle=gradient(ctx,0,0,Math.min(28*edge,w),0,[[0,'#2E1B0F80'],[1,'#2E1B0F00']]);ctx.fillRect(0,0,28*edge,h);
  ctx.fillStyle=gradient(ctx,0,h,0,-44*edge,[[0,'#2E1B0F80'],[1,'#2E1B0F00']]);ctx.fillRect(0,h-44*edge,w,44*edge);
  const g=ctx.createRadialGradient(w,0,0,w,0,96*edge);g.addColorStop(0,'#2E1B0F73');g.addColorStop(1,'#2E1B0F00');circle(ctx,w,0,96*edge,g);
  cache.set(key,c);return c;
}
function parchment(ctx,w,h,seed,edge,clip) {ctx.save();if(clip)ctx.clip(clip);ctx.drawImage(paper(w,h,seed,edge),0,0,w,h);ctx.restore();}
function ribbon(ctx,w,h,bow) {
  ctx.fillStyle=gradient(ctx,0,0,w,0,[[0,'#7E2446'],[.5,'#B8456F'],[1,'#7E2446']]);ctx.fillRect(0,0,w,h);
  if(bow<.6)return;const k=(bow-.6)/.4,cx=w/2,cy=w*1.4,s=w*1.6*k;
  for(const side of [-1,1]){const p=new Path2D();p.moveTo(cx,cy);p.bezierCurveTo(cx+side*s*.4,cy-s*.55,cx+side*s,cy-s*.5,cx+side*s*.95,cy-s*.05);p.bezierCurveTo(cx+side*s*.9,cy+s*.3,cx+side*s*.4,cy+s*.2,cx,cy);ctx.fillStyle='#B8456F';ctx.fill(p);ctx.strokeStyle='#7E2446';ctx.lineWidth=1.2;ctx.stroke(p);ctx.fillStyle='#A23A62';ctx.fill(path([[cx+side*s*.05,cy+s*.05],[cx+side*s*.45,cy+s*.85],[cx+side*s*.3,cy+s*.8],[cx+side*s*.2,cy+s*.95]]));}
  ctx.beginPath();ctx.ellipse(cx,cy,s*.16,s*.14,0,0,Math.PI*2);ctx.fillStyle='#9B3159';ctx.fill();
}
function seal(ctx,size,f) {
  const outerAlpha=ctx.globalAlpha;
  const c=size/2,r=size*.44,p=new Path2D();
  for(let i=0;i<=120;i++){const t=i/120*2*Math.PI-Math.PI/2,k=1+.055*Math.cos(5*(t+Math.PI/2))+.022*Math.sin(3*t+.7)+.014*Math.cos(7*t+1.3);const x=c+Math.cos(t)*r*k,y=c+Math.sin(t)*r*k;i?p.lineTo(x,y):p.moveTo(x,y);}p.closePath();
  ctx.shadowColor='#0007';ctx.shadowBlur=size*.05;ctx.shadowOffsetY=2;
  const g=ctx.createRadialGradient(c-r*.35,c-r*.42,0,c,c,r*1.1);[[0,'#C9483E'],[.38,'#A42B25'],[.78,'#7A1A17'],[1,'#4A0E0C']].forEach(([t,col])=>g.addColorStop(t,col));ctx.fillStyle=g;ctx.fill(p);ctx.shadowBlur=0;ctx.shadowOffsetY=0;
  ctx.strokeStyle='#4A0E0C8c';ctx.lineWidth=size*.012;ctx.stroke(p);
  for(const [dx,dy,col,lw] of [[.012,.014,'#4A0E0CB3',.05],[-.008,-.009,'#F0907F8C',.03],[0,0,'#A42B25',.03]]){ctx.globalAlpha=outerAlpha*f.emboss;ctx.beginPath();ctx.arc(c+size*dx,c+size*dy,r*.74,0,Math.PI*2);ctx.strokeStyle=col;ctx.lineWidth=size*lw;ctx.stroke();}
  circle(ctx,c,c,r*.66,'#7A1A17');
  const sprig=new Path2D('M30 56 C18 46 14 34 18 20 C20 12 26 6 32 4');
  const leaves=['M19 30 C10 28 6 22 8 16 C14 18 18 22 19 30Z','M22 18 C16 12 16 6 20 2 C24 6 24 12 22 18Z','M18 42 C8 42 4 36 4 30 C10 32 15 36 18 42Z','M24 50 C26 42 32 38 36 40 C34 46 30 50 24 50Z'];
  for(const side of [1,-1]){ctx.save();if(side<0){ctx.translate(c*2,0);ctx.scale(-1,1);}ctx.translate(c-r*.62,c-r*.42);ctx.scale(r*.34/40,r*.6/60);ctx.strokeStyle='#F0907F';ctx.lineWidth=3;ctx.stroke(sprig);ctx.fillStyle='#C9483E';leaves.forEach(d=>ctx.fill(new Path2D(d)));ctx.restore();}
  ctx.font=`700 ${r*.92}px "Playfair Display Variable", Georgia`;ctx.textAlign='center';ctx.textBaseline='middle';
  for(const [dx,dy,col] of [[.012,.014,'#4A0E0C'],[-.008,-.009,'#F0907F'],[0,0,'#A42B25']]){ctx.fillStyle=col;ctx.fillText('U',c+size*dx,c+r*.02+size*dy);}
  ctx.globalAlpha=outerAlpha;
  if(f.sealGlow){const glow=ctx.createRadialGradient(c,c,0,c,c,r*1.1);glow.addColorStop(0,`rgba(255,194,122,${.35*f.sealGlow})`);glow.addColorStop(1,'#FFC27A00');circle(ctx,c,c,r*1.1,glow);}
  ctx.save();ctx.globalAlpha=.26;ctx.beginPath();ctx.ellipse(c-r*.42,c-r*.55,r*.31,r*.12,0,0,Math.PI*2);ctx.fillStyle='white';ctx.fill();ctx.restore();
  if(f.crack){const points=[[-.08,-1.02],[.1,-.55],[-.12,-.1],[.12,.35],[-.04,1.02]].map(([x,y])=>[c+x*r,c+y*r]);const lengths=points.slice(1).map((p,i)=>Math.hypot(p[0]-points[i][0],p[1]-points[i][1]));let left=lengths.reduce((a,b)=>a+b,0)*f.crack;ctx.beginPath();ctx.moveTo(...points[0]);for(let i=0;i<lengths.length&&left>0;i++){const k=Math.min(1,left/lengths[i]);ctx.lineTo(points[i][0]+(points[i+1][0]-points[i][0])*k,points[i][1]+(points[i+1][1]-points[i][1])*k);left-=lengths[i];}ctx.lineCap='round';ctx.strokeStyle='#FFD9A080';ctx.lineWidth=size*.06;ctx.shadowBlur=size*.03;ctx.shadowColor='#FFD9A0';ctx.stroke();ctx.shadowBlur=0;ctx.strokeStyle='#FFF4DE';ctx.lineWidth=size*.018;ctx.stroke();}
}
function candle(ctx,t){const w=W*.42,h=W*.5,bw=w*.2,bh=h*.78;ctx.translate(w*.12,h*.16);ctx.rotate(-.66);ctx.fillStyle=gradient(ctx,-bw/2,0,bw,0,[[0,'#C9B79A'],[.35,'#F4EAD6'],[.5,'#FFF7EA'],[.7,'#E9DCC4'],[1,'#BBA88A']]);ctx.beginPath();ctx.roundRect(-bw/2,0,bw,bh,bw*.15);ctx.fill();ctx.fillStyle='#FFF6E6';ctx.fillRect(-bw/2+bw*.08,0,bw*.3,bh*.24);ctx.strokeStyle='#2A1A12';ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(0,0);ctx.lineTo(0,-bw*.35);ctx.stroke();ctx.translate(0,-bw*.35);ctx.rotate(.66+Math.sin(t*90)*.06);const fl=1+Math.sin(t*130)*.05,p=new Path2D();p.moveTo(0,0);p.bezierCurveTo(bw*.4,-bw*.3*fl,bw*.15,-bw*.9*fl,0,-bw*1.25*fl);p.bezierCurveTo(-bw*.15,-bw*.9*fl,-bw*.4,-bw*.3*fl,0,0);ctx.fillStyle=gradient(ctx,0,0,0,-bw*1.25,[[0,'white'],[.35,'#FFE7A6'],[1,'#FFB347']]);ctx.shadowColor='#FFBE7A';ctx.shadowBlur=18;ctx.fill(p);}
function stamp(ctx){const w=W*.18,h=W*.32;ctx.fillStyle=gradient(ctx,0,0,w,0,[[0,'#3B2116'],[.5,'#6E4630'],[1,'#3B2116']]);ctx.beginPath();ctx.roundRect(w*.3,0,w*.4,h*.66,w*.2);ctx.fill();ctx.fillStyle=gradient(ctx,0,0,w,0,[[0,'#8C6A2E'],[.5,'#F1D98C'],[1,'#8C6A2E']]);ctx.beginPath();ctx.roundRect(w*.18,h*.64,w*.64,h*.1,w*.05);ctx.fill();ctx.beginPath();ctx.roundRect(0,h*.72,w,h*.22,w*.08);ctx.fill();}

export function createCapsulePainter(canvas) {
  const ctx=canvas.getContext('2d');let lastFrame,lastTime,lastOpening,lastLocked,allowText=true;
  const lw=W*.8*.86,ph=lw*.36;
  const written=document.createElement('canvas');written.width=Math.ceil(lw*2);written.height=Math.ceil(ph*3*2);const pen=written.getContext('2d');pen.scale(2,2);pen.drawImage(paper(lw,ph*3,41,.3),0,0,lw,ph*3);pen.fillStyle=colors.ink;pen.font=`600 ${lw*.07}px "Playfair Display Variable", Georgia`;pen.fillText('For our future selves',lw*.08,lw*.13);pen.font=`italic ${lw*.058}px Georgia`;['A little love, saved for later.','Today’s words.','Tomorrow’s butterflies.'].forEach((line,i)=>pen.fillText(line,lw*.08,lw*.26+i*lw*.10));
  function sheet(f,x,y,scale) {
    ctx.save();ctx.translate(x+lw/2,y+ph*1.5);ctx.scale(scale,scale);ctx.translate(-lw/2,-ph*1.5);
    if(allowText)ctx.drawImage(written,0,ph*2,lw*2,ph*2,0,ph,lw,ph);
    else ctx.drawImage(paper(lw,ph,42,.3),0,ph,lw,ph);
    for(const [index,fold,top] of [[0,f.fold1,true],[2,f.fold3,false]]) {
      const angle=Math.PI*.985*fold*(top?-1:1),cos=Math.cos(angle),sin=Math.sin(angle),hinge=top?ph:ph*2;
      const back=Math.abs(angle)>Math.PI/2||!allowText,source=back?paper(lw,ph,41+index,.3):written;
      if(fold<.001){ctx.drawImage(source,0,(back?0:index*ph)*2,lw*2,ph*2,0,index*ph,lw,ph);continue;}
      // Project narrow strips through Flutter's Matrix4(perspective=.0016).
      for(let row=0;row<60;row++){const sy=ph*row/60,sh=ph/60,dy=top?sy-ph:sy,den=1+.0016*sin*dy;const yy=hinge+cos*dy/den;ctx.save();ctx.translate(lw/2,yy);ctx.scale(1/den,cos/(den*den));ctx.drawImage(source,0,(back?sy:index*ph+sy)*2,lw*2,sh*2,-lw/2,0,lw,sh+.05);ctx.restore();}
    }
    if(f.ribbon>0&&f.ribbonOff<1){ctx.save();ctx.globalAlpha=1-f.ribbonOff;ctx.translate(lw/2-lw*.05+f.ribbonOff*lw*.5,ph);ctx.rotate(f.ribbonOff*.3);ribbon(ctx,lw*.1,ph*f.ribbon,f.ribbon);ctx.restore();}ctx.restore();
  }
  function draw(f,t,opening=true,locked=false){lastFrame=f;lastTime=t;lastOpening=opening;lastLocked=locked;allowText=!locked;
    const dpr=Math.min(devicePixelRatio||1,2);if(canvas.width!==W*dpr){canvas.width=W*dpr;canvas.height=Math.ceil(H*dpr);}ctx.setTransform(dpr,0,0,dpr,0,0);ctx.clearRect(0,0,W,H);
    const ew=W*.8,eh=ew*.62,ex=(W-ew)/2,ey=H-eh-W*.08+(1-f.envelope)*W*.1*(opening?0:1)+f.envelopeDrop*W*.25;
    const apex=eh*.56,depth=apex*Math.cos(Math.PI*(1-f.flapClosed)),sx=W/2,sy=ey+apex;
    const env=(front)=>{ctx.save();ctx.translate(ex,ey);ctx.globalAlpha=f.envelope;if(!front){ctx.shadowColor='#0008';ctx.shadowBlur=10;ctx.shadowOffsetY=5;ctx.fillStyle=colors.paper;ctx.fillRect(0,0,ew,eh);ctx.shadowBlur=0;ctx.shadowOffsetY=0;parchment(ctx,ew,eh,23,.45);ctx.fillStyle='#6B4A301f';ctx.fillRect(0,0,ew,eh);if(depth<0){ctx.save();ctx.clip(path([[0,0],[ew,0],[ew/2,depth]]));ctx.translate(0,depth);parchment(ctx,ew,-depth,25,.4);ctx.restore();}}else{parchment(ctx,ew,eh,27,.45,path([[0,eh*.18],[ew/2,eh*.6],[ew,eh*.18],[ew,eh],[0,eh]]));ctx.strokeStyle='#6B4A3059';ctx.lineWidth=1;for(const [x,y] of [[0,eh*.18],[ew,eh*.18],[0,eh],[ew,eh]]){ctx.beginPath();ctx.moveTo(x,y);ctx.lineTo(ew/2,eh*.6);ctx.stroke();}if(depth>0){const flap=path([[0,0],[ew,0],[ew/2,depth]]);parchment(ctx,ew,Math.max(depth,1),29,.4,flap);ctx.stroke(flap);}}ctx.restore();};
    if(f.envelope>0)env(false);
    const inside=ey+eh*.18-ph;const y=opening?inside+(W*.56-inside)*f.letterOut:W*.12+(inside-W*.12)*f.letterIn;
    if(!((opening?f.letterOut<.02:f.letterIn>.98)&&f.envelope>=1&&f.flapClosed>=1))sheet(f,(W-lw)/2,y,opening?.9+.1*f.letterOut:1-.1*f.letterIn);
    if(f.envelope>0)env(true);
    if(f.glow>0){const g=ctx.createRadialGradient(sx,sy,0,sx,sy,W*.4);g.addColorStop(0,`rgba(255,190,130,${.38*f.glow})`);g.addColorStop(1,'#FFA05A00');circle(ctx,sx,sy,W*.4,g);}
    if(f.seal>0&&f.envelope>0){ctx.save();ctx.globalAlpha=f.seal*f.envelope;ctx.translate(sx,sy+(opening?(1-f.seal)*W*.04:0));ctx.scale(opening?1:f.pool,opening?1-(1-f.seal)*.3:f.pool);ctx.translate(-W*.11,-W*.11);seal(ctx,W*.22,f);ctx.restore();}
    f.drops.forEach((drop,i)=>{if(drop>0){const x=sx-W*.02+(i-1)*W*.012,y=sy-W*.46+W*.46*drop-W*.03;ctx.fillStyle='#A42B25';ctx.fill(path([[x+W*.02,y+W*.021],[x+W*.034,y+W*.047],[x+W*.02,y+W*.06],[x+W*.006,y+W*.047]]));}});
    if(f.candle>0){ctx.save();ctx.globalAlpha=f.candle;ctx.translate(sx-W*.05+(1-f.candle)*W*.25,sy-W*.46-W*.08-(1-f.candle)*W*.2);candle(ctx,t);ctx.restore();}
    if(f.stamp>0){ctx.save();ctx.globalAlpha=Math.min(1,f.stamp*20);ctx.translate(sx-W*.09,-W*.1+(sy-W*.3+W*.1)*f.stamp);stamp(ctx);ctx.restore();}
  }
  document.fonts.ready.then(()=>{if(lastFrame)draw(lastFrame,lastTime,lastOpening,lastLocked);});
  return draw;
}
