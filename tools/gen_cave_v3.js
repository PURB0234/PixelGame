'use strict';
// gen_cave_v3.js — hand-crafted pixel art cave portal 112x98
// Directly referencing the Stardew-style mine entrance design
const zlib = require('zlib');
const fs   = require('fs');

const W = 112, H = 98;
const img = new Uint8Array(W * H * 4); // RGBA, default transparent

function p(x, y, hex, a=255) {
  if(x<0||x>=W||y<0||y>=H) return;
  const i=(y*W+x)*4;
  img[i]  =(hex>>16)&0xFF;
  img[i+1]=(hex>>8)&0xFF;
  img[i+2]=(hex)&0xFF;
  img[i+3]=a;
}
function hline(y, x1, x2, hex, a=255) { for(let x=x1;x<=x2;x++) p(x,y,hex,a); }
function vline(x, y1, y2, hex, a=255) { for(let y=y1;y<=y2;y++) p(x,y,hex,a); }
function fill(x1,y1,x2,y2,hex,a=255) { for(let y=y1;y<=y2;y++) hline(y,x1,x2,hex,a); }

// ══════════════════════════════════════════════
// PALETTE — Stardew Valley cave portal reference
// ══════════════════════════════════════════════
// Cave interior
const BLK  = 0x0A080C;
const DBK  = 0x1A1420;
const MBK  = 0x2E2438;

// Stone: 5 tones + outline
const SO   = 0x1E1C28; // outline
const SD   = 0x3A3848; // shadow / darkest
const SM   = 0x585668; // mid-dark
const SB   = 0x747288; // base mid
const SL   = 0x9896A8; // light
const SH   = 0xBCBACC; // highlight
const SW   = 0xD4D2E0; // bright specular

// Wood: 5 tones + outline + grain
const WO   = 0x2C1808; // outline
const WD   = 0x4E2E10; // dark
const WM   = 0x7A4A1E; // mid
const WL   = 0xA86C30; // light
const WH   = 0xC88040; // highlight
const WS   = 0xE09850; // specular (top face)
const WGR  = 0x5C3614; // grain

// Moss
const MS   = 0x3A5428; // shadow moss
const MM   = 0x567840; // mid moss
const ML   = 0x78A05A; // light moss
const MH   = 0x96BC72; // highlight moss

// Ground
const GD   = 0x241C10; // ground dark
const GM   = 0x3C2E1C; // ground mid
const GL   = 0x5A4228; // ground light

// ══════════════════════════════════════════════
// STEP 1: Cave mouth — arch shape, hand-drawn
// ══════════════════════════════════════════════
// Black fill — arch opening rows (approximate arch from reference)
// Arch width at various heights:
const archRows = [
  // [y, x1, x2]
  [22, 50, 62],
  [23, 46, 66],
  [24, 43, 69],
  [25, 41, 71],
  [26, 39, 73],
  [27, 38, 74],
  [28, 37, 75],
  [29, 36, 76],
  [30, 35, 77],
  [31, 34, 78],
  [32, 34, 78],
  [33, 33, 79],
  [34, 33, 79],
  [35, 33, 79],
  [36, 33, 79],
  [37, 33, 79],
  [38, 33, 79],
  [39, 33, 79],
  [40, 33, 79],
  [41, 33, 79],
  [42, 33, 79],
  [43, 33, 79],
  [44, 33, 79],
  [45, 34, 78],
  [46, 34, 78],
  [47, 35, 77],
  [48, 35, 77],
  [49, 36, 76],
  [50, 36, 76],
  [51, 37, 75],
  [52, 38, 74],
  [53, 39, 73],
  [54, 40, 72],
  [55, 41, 71],
  [56, 42, 70],
  [57, 43, 69],
  [58, 44, 68],
  [59, 45, 67],
  [60, 46, 66],
  [61, 47, 65],
  [62, 48, 64],
  // straight sides below arch center
];
archRows.forEach(([y,x1,x2])=>hline(y,x1,x2,BLK));
// Rectangular throat below arch
fill(37,63,75,86,BLK);
// Soft BK2 inner glow
fill(39,25,73,61,DBK);
fill(43,30,69,58,MBK);

// ══════════════════════════════════════════════
// STEP 2: Big boulder shapes — hand-placed
// ══════════════════════════════════════════════
// Each boulder is drawn as a series of horizontal spans
// Format: [y, x1, x2, color]
// We define boulders as sets of spans, then shade them

function boulder(spans, specX, specY, specR, mossX, mossY) {
  // spans: array of [y, x1, x2]
  // specX,specY,specR: specular highlight center+radius
  // mossX,mossY: optional moss position (-1 = no moss)
  for(const [y,x1,x2] of spans) {
    for(let x=x1;x<=x2;x++) {
      // Determine shading from center of span
      const mx=(x1+x2)/2, my=spans[Math.floor(spans.length/2)][0];
      const relX=(x-mx)/(x2-x1+1)*2; // -1..1
      const relY=(y-my)/(spans.length)*2;
      // Light from top-left
      const lit = -relX*0.4 + -relY*0.5;
      // Shadow bottom-right
      const shd = relX*0.5 + relY*0.4;
      let c;
      if(shd>0.6)      c=SD;
      else if(shd>0.3) c=SM;
      else if(lit>0.5) c=SH;
      else if(lit>0.2) c=SL;
      else             c=SB;
      p(x,y,c);
    }
  }
  // Specular highlight
  if(specR>0) {
    for(let dy=-specR;dy<=specR;dy++)
      for(let dx=-specR;dx<=specR;dx++)
        if(dx*dx+dy*dy<=specR*specR) {
          const f=Math.sqrt(dx*dx+dy*dy)/specR;
          p(specX+dx,specY+dy, f<0.4?SW:SH);
        }
  }
  // Outline — top/sides only (1px dark border)
  const allPx = new Set(spans.map(([y,x1,x2])=>{
    const r=[];
    for(let x=x1;x<=x2;x++) r.push([x,y]);
    return r;
  }).flat().map(([x,y])=>`${x},${y}`));
  for(const s of allPx) {
    const [x,y]=s.split(',').map(Number);
    for(const [dx,dy] of [[-1,0],[1,0],[0,-1],[0,1]]) {
      if(!allPx.has(`${x+dx},${y+dy}`)) p(x+dx,y+dy,SO);
    }
  }
  // Moss
  if(mossX>=0) {
    p(mossX,mossY,ML); p(mossX+1,mossY,MM); p(mossX-1,mossY,MM);
    p(mossX,mossY-1,MH); p(mossX+1,mossY-1,ML); p(mossX-1,mossY+1,MS);
    p(mossX+2,mossY,MS); p(mossX,mossY+1,MS);
  }
}

// ── TOP CENTER boulder (crown of arch)
boulder([
  [5,46,66],[6,42,70],[7,40,72],[8,39,73],[9,39,73],[10,40,72],[11,42,70],[12,46,66]
], 52,7,2, 44,8);

// ── TOP-LEFT boulder
boulder([
  [8,26,42],[9,23,45],[10,21,47],[11,20,47],[12,20,47],[13,21,46],[14,23,44],[15,27,42]
], 25,10,2, 24,12);

// ── TOP-RIGHT boulder
boulder([
  [8,70,86],[9,67,89],[10,65,91],[11,64,91],[12,64,91],[13,65,90],[14,67,88],[15,71,86]
], 85,10,2, 83,12);

// ── MID-LEFT-TOP boulder
boulder([
  [16,16,34],[17,13,37],[18,11,39],[19,10,39],[20,10,39],[21,10,38],[22,12,36],[23,15,34],[24,18,32]
], 15,18,2, 14,20);

// ── MID-RIGHT-TOP boulder
boulder([
  [16,78,96],[17,75,99],[18,73,101],[19,72,101],[20,72,101],[21,72,100],[22,74,98],[23,77,96],[24,80,94]
], 97,18,2, 93,20);

// ── LEFT SIDE main boulder
boulder([
  [24,6,26],[25,4,29],[26,2,31],[27,2,32],[28,2,32],[29,2,32],[30,3,31],[31,5,29],[32,8,26]
], 6,26,2, -1,-1);

// ── RIGHT SIDE main boulder
boulder([
  [24,86,106],[25,83,108],[26,81,110],[27,80,110],[28,80,110],[29,80,110],[30,81,109],[31,83,107],[32,86,104]
], 106,26,2, -1,-1);

// ── MID-LEFT-LOWER boulder
boulder([
  [32,2,24],[33,0,27],[34,0,28],[35,0,29],[36,0,29],[37,0,28],[38,1,26],[39,3,23],[40,6,20]
], 3,34,2, 4,38);

// ── MID-RIGHT-LOWER boulder
boulder([
  [32,88,110],[33,85,112],[34,84,112],[35,83,112],[36,83,112],[37,84,111],[38,86,110],[39,89,109],[40,92,106]
], 109,34,2, 100,38);

// ── LOWER-LEFT boulder
boulder([
  [42,0,18],[43,0,20],[44,0,21],[45,0,22],[46,0,22],[47,0,21],[48,0,19],[49,2,17]
], 3,44,2, 2,46);

// ── LOWER-RIGHT boulder
boulder([
  [42,94,112],[43,92,112],[44,91,112],[45,90,112],[46,90,112],[47,91,112],[48,93,112],[49,95,110]
], 109,44,2, 103,46);

// ── BOTTOM-LEFT boulders
boulder([
  [60,0,20],[61,0,22],[62,0,24],[63,0,25],[64,0,25],[65,0,24],[66,0,22],[67,2,20],[68,5,17]
], 4,62,2, 3,65);

boulder([
  [66,18,36],[67,16,38],[68,15,39],[69,14,40],[70,14,40],[71,15,39],[72,17,37],[73,20,35],[74,23,33]
], 19,68,2, 18,70);

// ── BOTTOM-RIGHT boulders
boulder([
  [60,92,112],[61,90,112],[62,88,112],[63,87,112],[64,87,112],[65,88,112],[66,90,112],[67,92,110],[68,95,107]
], 108,62,2, 103,65);

boulder([
  [66,76,94],[67,74,96],[68,73,97],[69,72,98],[70,72,98],[71,73,97],[72,75,95],[73,78,93],[74,81,91]
], 93,68,2, 86,70);

// ── BOTTOM ROW boulders (across floor)
boulder([
  [76,8,30],[77,6,32],[78,5,33],[79,5,33],[80,5,33],[81,6,32],[82,8,30],[83,11,28]
], 10,78,2, 9,80);

boulder([
  [76,30,52],[77,28,54],[78,27,55],[79,26,56],[80,26,56],[81,27,55],[82,29,53],[83,32,51]
], 32,78,2, 31,80);

boulder([
  [76,60,82],[77,58,84],[78,57,85],[79,56,86],[80,56,86],[81,57,85],[82,59,83],[83,62,81]
], 62,78,2, 61,80);

boulder([
  [76,82,104],[77,80,106],[78,79,107],[79,78,108],[80,78,108],[81,79,107],[82,81,105],[83,84,103]
], 103,78,2, 97,80);

// ══════════════════════════════════════════════
// STEP 3: Wood mine frame — thick beams
// ══════════════════════════════════════════════
function thickBeam(x1,y1,x2,y2,w) {
  const dx=x2-x1,dy=y2-y1,len=Math.sqrt(dx*dx+dy*dy);
  const ux=dx/len,uy=dy/len,nx=-uy,ny=ux;
  // Fill
  for(let t=0;t<=len;t+=0.35) {
    const bx=x1+ux*t,by=y1+uy*t;
    for(let s=-w/2;s<=w/2;s+=0.35) {
      const f=Math.abs(s)/(w/2);
      let c;
      // Top face lighter (normal pointing up for horizontal, left for diagonal)
      const topFace = ny<-0.3; // normal points upward
      if(topFace) {
        if(f<0.2) c=WS; else if(f<0.45) c=WH; else if(f<0.7) c=WL; else if(f<0.88) c=WM; else c=WD;
      } else {
        if(f<0.15) c=WH; else if(f<0.4) c=WL; else if(f<0.65) c=WM; else if(f<0.85) c=WD; else c=WO;
      }
      p(Math.round(bx+nx*s),Math.round(by+ny*s),c);
    }
  }
  // Grain
  for(let t=6;t<len-3;t+=8) {
    const bx=Math.round(x1+ux*t),by=Math.round(y1+uy*t);
    p(bx,by,WGR); p(bx+Math.round(nx),by+Math.round(ny),WGR);
  }
  // Outline
  for(let t=0;t<=len;t+=0.35) {
    const bx=x1+ux*t,by=y1+uy*t;
    p(Math.round(bx+nx*(w/2+1)),Math.round(by+ny*(w/2+1)),WO);
    p(Math.round(bx-nx*(w/2+1)),Math.round(by-ny*(w/2+1)),WO);
  }
  p(Math.round(x1),Math.round(y1),WO); p(Math.round(x2),Math.round(y2),WO);
}

// Left post diagonal: bottom-left → upper
thickBeam(39,88, 45,52, 9);
// Right post diagonal: bottom-right → upper
thickBeam(73,88, 67,52, 9);
// Top horizontal beam
thickBeam(32,52, 80,52, 10);
// Left brace
thickBeam(45,66, 53,58, 5);
// Right brace
thickBeam(67,66, 59,58, 5);

// ══════════════════════════════════════════════
// STEP 4: Re-draw cave interior on top of frame
// ══════════════════════════════════════════════
archRows.forEach(([y,x1,x2])=>{
  for(let x=x1+2;x<=x2-2;x++) {
    const relX=(x-(x1+x2)/2)/((x2-x1)/2);
    p(x,y, relX*relX<0.3 ? MBK : DBK);
  }
  p(x1+1,y,BLK); p(x2-1,y,BLK);
});
fill(39,63,73,86,BLK);
fill(41,65,71,84,DBK);
fill(44,68,68,82,MBK);
// Arch stone rim
archRows.forEach(([y,x1,x2])=>{ p(x1,y,SO); p(x2,y,SO); });

// ══════════════════════════════════════════════
// STEP 5: Ground floor entrance
// ══════════════════════════════════════════════
for(let y=86;y<H;y++) {
  const dy=y-86;
  for(let x=38;x<=74;x++) {
    const inside=x>=38&&x<=74;
    if(!inside) continue;
    if(dy===0) p(x,y,GD);
    else if(dy===1) p(x,y,GD);
    else if(dy<=4) p(x,y,GM);
    else p(x,y,GL);
  }
}
// Shadow edge
hline(86,38,74,SO);

// ══════════════════════════════════════════════
// STEP 6: Extra detail — corner shadows & fills
// ══════════════════════════════════════════════
// Dark corners behind boulders to avoid floating look
fill(0,0,10,20,SO,80);
fill(102,0,111,20,SO,80);

// ══════════════════════════════════════════════
// PNG ENCODE (pure Node zlib)
// ══════════════════════════════════════════════
function crc32(b) {
  const t=new Uint32Array(256);
  for(let n=0;n<256;n++){let v=n;for(let k=0;k<8;k++)v=v&1?0xEDB88320^(v>>>1):v>>>1;t[n]=v;}
  let c=0xFFFFFFFF;
  for(let i=0;i<b.length;i++) c=t[(c^b[i])&0xFF]^(c>>>8);
  return (~c)>>>0;
}
function chunk(type,data){
  const tb=Buffer.from(type,'ascii');
  const lb=Buffer.alloc(4);lb.writeUInt32BE(data.length);
  const cb=Buffer.alloc(4);cb.writeUInt32BE(crc32(Buffer.concat([tb,data])));
  return Buffer.concat([lb,tb,data,cb]);
}
const ihdr=Buffer.alloc(13);
ihdr.writeUInt32BE(W,0);ihdr.writeUInt32BE(H,4);
ihdr[8]=8;ihdr[9]=6;
const raw=Buffer.alloc(H*(1+W*4));
for(let y=0;y<H;y++){
  raw[y*(1+W*4)]=0;
  for(let x=0;x<W;x++){
    const si=(y*W+x)*4,di=y*(1+W*4)+1+x*4;
    raw[di]=img[si];raw[di+1]=img[si+1];raw[di+2]=img[si+2];raw[di+3]=img[si+3];
  }
}
const comp=zlib.deflateSync(raw,{level:9});
const sig=Buffer.from([137,80,78,71,13,10,26,10]);
const png=Buffer.concat([sig,chunk('IHDR',ihdr),chunk('IDAT',comp),chunk('IEND',Buffer.alloc(0))]);
const out='C:\\Project_game\\godot-valley-main\\graphics\\objects\\mining\\cliff_cave_facade_v3.png';
fs.writeFileSync(out,png);
console.log('Done:', out, png.length+'bytes');
