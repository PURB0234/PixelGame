'use strict';
const zlib = require('zlib');
const fs   = require('fs');

const W = 112, H = 98;
const buf = Buffer.alloc(W * H * 4, 0); // all transparent

function px(x, y, r, g, b, a=255) {
  if (x < 0 || x >= W || y < 0 || y >= H) return;
  const i = (y * W + x) * 4;
  buf[i]=r; buf[i+1]=g; buf[i+2]=b; buf[i+3]=a;
}
function rect(x1,y1,x2,y2,r,g,b,a=255) {
  for(let y=y1;y<=y2;y++) for(let x=x1;x<=x2;x++) px(x,y,r,g,b,a);
}

// ─── PALETTES ────────────────────────────────────────────────────────────────
// Cave interior blacks
const BK  = [8,6,10];
const BK2 = [18,14,22];
const BK3 = [32,26,38];

// Stone colors (dark → light)
const S0 = [30,28,38];   // outline/shadow
const S1 = [52,50,64];   // dark face
const S2 = [72,70,86];   // mid
const S3 = [96,92,110];  // light
const S4 = [122,118,138];// highlight
const S5 = [148,144,162];// bright edge

// Wood colors
const W0 = [44,26,10];   // outline
const W1 = [78,48,20];   // dark
const W2 = [110,70,30];  // mid
const W3 = [142,96,44];  // light
const W4 = [166,114,54]; // highlight
const WG = [88,56,22];   // grain

// Moss
const M1 = [58,84,40];
const M2 = [80,108,56];
const M3 = [100,128,72];

// Ground dirt
const G0 = [36,28,20];
const G1 = [54,42,28];
const G2 = [72,56,38];
const G3 = [90,72,50];

// ─── HELPER: draw a boulder ellipse with shading ──────────────────────────────
function boulder(cx, cy, rx, ry, mossBL=false) {
  for(let dy=-ry; dy<=ry; dy++) {
    for(let dx=-rx; dx<=rx; dx++) {
      const e = (dx/rx)**2 + (dy/ry)**2;
      if(e > 1.0) continue;
      const x=cx+dx, y=cy+dy;
      // Determine base tone by position within ellipse
      // Light comes from top-left
      const lit = (-dx/rx)*0.4 + (-dy/ry)*0.6; // -1..+1, positive = lit
      let col;
      if(lit > 0.5)       col = S5;
      else if(lit > 0.2)  col = S4;
      else if(lit > -0.1) col = S3;
      else if(lit > -0.4) col = S2;
      else if(lit > -0.7) col = S1;
      else                col = S0;
      // Deep shadow bottom-right quadrant
      if(dx > rx*0.35 && dy > ry*0.3) col = S0;
      px(x, y, ...col);
    }
  }
  // Outline (1px)
  for(let dy=-ry-1; dy<=ry+1; dy++) {
    for(let dx=-rx-1; dx<=rx+1; dx++) {
      const eo = (dx/(rx+1))**2 + (dy/(ry+1))**2;
      const ei = (dx/rx)**2 + (dy/ry)**2;
      if(eo <= 1.0 && ei > 1.0) px(cx+dx, cy+dy, ...S0);
    }
  }
  // Bright inner highlight (top-left rim)
  for(let dy=-ry; dy<=-ry/3; dy++) {
    for(let dx=-rx; dx<=-rx/3; dx++) {
      const e=(dx/rx)**2+(dy/ry)**2;
      if(e<0.6 && e>0.25) px(cx+dx, cy+dy, ...S5);
    }
  }
  // Moss patch bottom-left
  if(mossBL) {
    const mx=cx-Math.round(rx*0.4), my=cy+Math.round(ry*0.5);
    px(mx, my, ...M2); px(mx+1,my,...M1); px(mx-1,my,...M1);
    px(mx,my-1,...M2); px(mx+1,my-1,...M3); px(mx-1,my+1,...M1);
  }
}

// ─── HELPER: draw a thick wood beam between two points ───────────────────────
function woodBeam(x1,y1,x2,y2,thick) {
  const dx=x2-x1, dy=y2-y1;
  const len=Math.sqrt(dx*dx+dy*dy);
  const ux=dx/len, uy=dy/len;
  const nx=-uy, ny=ux; // perpendicular

  // Fill passes from thickest to thinnest
  for(let t=0; t<=len; t+=0.4) {
    const bx=x1+ux*t, by=y1+uy*t;
    for(let s=-thick/2; s<=thick/2; s+=0.4) {
      const wx=Math.round(bx+nx*s), wy=Math.round(by+ny*s);
      const f=Math.abs(s)/(thick/2); // 0=center,1=edge
      let col;
      if(f<0.15)      col=W4;
      else if(f<0.40) col=W3;
      else if(f<0.65) col=W2;
      else if(f<0.85) col=W1;
      else            col=W0;
      px(wx,wy,...col);
    }
  }
  // Grain marks every 7px along beam
  for(let t=5; t<len-2; t+=7) {
    const bx=Math.round(x1+ux*t), by=Math.round(y1+uy*t);
    px(bx,by,...WG); px(bx+Math.round(nx),by+Math.round(ny),...WG);
  }
  // Outline
  for(let t=0; t<=len; t+=0.4) {
    const bx=x1+ux*t, by=y1+uy*t;
    for(let side of [-1,1]) {
      const s=(thick/2+1)*side;
      px(Math.round(bx+nx*s), Math.round(by+ny*s), ...W0);
    }
  }
}

// ════════════════════════════════════════════════════════════════════
// LAYER 1: Cave mouth arch — dark interior
// ════════════════════════════════════════════════════════════════════
const ACX=56, ACY=58, ARX=28, ARY=36;

// Fill arch opening black
for(let y=22; y<H-12; y++) {
  for(let x=28; x<84; x++) {
    const ex=(x-ACX)/ARX, ey=(y-ACY)/ARY;
    // Inside ellipse upper half = arch
    if(y<=ACY && ex*ex+ey*ey<=1.0) { px(x,y,...BK); continue; }
    // Rectangle lower half of arch
    if(y>ACY && x>=ACX-ARX+2 && x<=ACX+ARX-2) px(x,y,...BK);
  }
}
// Soft inner glow layers
for(let y=28; y<H-12; y++) {
  for(let x=34; x<78; x++) {
    const ex=(x-ACX)/(ARX-5), ey=(y-ACY)/(ARY-5);
    if(y<=ACY && ex*ex+ey*ey<=1.0) px(x,y,...BK2);
    if(y>ACY && x>=ACX-ARX+8 && x<=ACX+ARX-8) px(x,y,...BK2);
  }
}
for(let y=34; y<H-14; y++) {
  for(let x=40; x<72; x++) {
    const ex=(x-ACX)/(ARX-10), ey=(y-ACY)/(ARY-10);
    if(y<=ACY && ex*ex+ey*ey<=1.0) px(x,y,...BK3);
    if(y>ACY && x>=ACX-ARX+14 && x<=ACX+ARX-14) px(x,y,...BK3);
  }
}

// ════════════════════════════════════════════════════════════════════
// LAYER 2: Boulders — arranged around arch
// ════════════════════════════════════════════════════════════════════
//  [cx, cy, rx, ry, hasMoss]
const rocks = [
  // ── bottom row
  [15, 86, 12,  9, false],
  [33, 90, 13, 10, false],
  [56, 92, 11,  8, false],
  [79, 90, 13, 10, false],
  [97, 86, 12,  9, false],

  // ── left side stack
  [ 8, 70, 10,  8, true],
  [22, 72, 13, 10, false],
  [10, 56, 10,  8, true],
  [26, 58, 12,  9, false],
  [38, 64, 10,  8, false],

  // ── right side stack
  [104,70, 10,  8, true],
  [ 90,72, 13, 10, false],
  [102,56, 10,  8, true],
  [ 86,58, 12,  9, false],
  [ 74,64, 10,  8, false],

  // ── top arch row
  [32, 46, 11,  9, true],
  [44, 34, 12, 10, false],
  [56, 24, 13, 11, false],
  [68, 24, 12, 11, false],
  [80, 34, 12, 10, false],
  [90, 44, 11,  9, true],

  // ── top fill
  [56, 14, 10,  8, false],
  [42, 20,  9,  7, false],
  [70, 20,  9,  7, false],
];

// Draw back rocks first (larger y = front)
rocks.sort((a,b)=>a[1]-b[1]).forEach(([cx,cy,rx,ry,m])=>boulder(cx,cy,rx,ry,m));

// ════════════════════════════════════════════════════════════════════
// LAYER 3: Wood mine frame
// ════════════════════════════════════════════════════════════════════
// Left diagonal post: bottom(38,96) → top(44,52)
woodBeam(38,96, 44,52, 8);
// Right diagonal post: bottom(74,96) → top(68,52)
woodBeam(74,96, 68,52, 8);
// Top horizontal beam: (36,52) → (76,52)
woodBeam(34,52, 78,52, 9);
// Small left brace: (44,68)→(52,60)
woodBeam(44,68, 52,60, 4);
// Small right brace: (68,68)→(60,60)
woodBeam(68,68, 60,60, 4);

// ════════════════════════════════════════════════════════════════════
// LAYER 4: Redraw cave mouth ON TOP of wood (interior stays dark)
// ════════════════════════════════════════════════════════════════════
for(let y=24; y<H-12; y++) {
  for(let x=30; x<82; x++) {
    const ex=(x-ACX)/ARX, ey=(y-ACY)/ARY;
    if(y<=ACY && ex*ex+ey*ey<=0.90) { px(x,y,...BK); continue; }
    if(y>ACY && x>=ACX-ARX+4 && x<=ACX+ARX-4) px(x,y,...BK);
  }
}
// Arch rim dark
for(let y=20; y<=ACY; y++) {
  for(let x=26; x<86; x++) {
    const ex=(x-ACX)/ARX, ey=(y-ACY)/ARY;
    const eo=(x-ACX)/(ARX+1), eyo=(y-ACY)/(ARY+1);
    const e=ex*ex+ey*ey;
    if(e>=0.88 && e<=1.02) px(x,y,...BK2);
    if(e>=0.98 && eyo*eyo+(x-ACX)**2/(ARX+1)**2<=1.02) px(x,y,...S0);
  }
}

// ════════════════════════════════════════════════════════════════════
// LAYER 5: Ground / dirt floor at entrance
// ════════════════════════════════════════════════════════════════════
for(let y=H-14; y<H; y++) {
  const dy=y-(H-14);
  for(let x=24; x<88; x++) {
    const inside = x>=ACX-ARX+2 && x<=ACX+ARX-2;
    if(!inside) continue;
    if(dy===0) px(x,y,...G0);
    else if(dy<=2) px(x,y,...G1);
    else if(dy<=5) px(x,y,...G2);
    else px(x,y,...G3);
  }
}
// Ground shadow line under arch
for(let x=ACX-ARX+3; x<=ACX+ARX-3; x++) px(x,H-14,...S0);

// ════════════════════════════════════════════════════════════════════
// LAYER 6: Extra moss patches on boulders near arch edges
// ════════════════════════════════════════════════════════════════════
[[12,53],[22,51],[32,43],[88,43],[98,51],[100,53]].forEach(([x,y])=>{
  px(x,y,...M2); px(x+1,y,...M1); px(x+2,y,...M2);
  px(x,y+1,...M1); px(x+1,y+1,...M3);
});

// ════════════════════════════════════════════════════════════════════
// PNG ENCODE
// ════════════════════════════════════════════════════════════════════
function crc32(b) {
  const t=new Uint32Array(256);
  for(let i=0;i<256;i++){let v=i;for(let j=0;j<8;j++)v=v&1?0xEDB88320^(v>>>1):v>>>1;t[i]=v;}
  let c=0xFFFFFFFF;
  for(let i=0;i<b.length;i++) c=t[(c^b[i])&0xFF]^(c>>>8);
  return (~c)>>>0;
}
function chunk(type,data) {
  const tb=Buffer.from(type,'ascii');
  const lb=Buffer.alloc(4); lb.writeUInt32BE(data.length);
  const cb=Buffer.alloc(4); cb.writeUInt32BE(crc32(Buffer.concat([tb,data])));
  return Buffer.concat([lb,tb,data,cb]);
}
const ihdr=Buffer.alloc(13);
ihdr.writeUInt32BE(W,0); ihdr.writeUInt32BE(H,4);
ihdr[8]=8; ihdr[9]=6;
const raw=Buffer.alloc(H*(1+W*4));
for(let y=0;y<H;y++){
  raw[y*(1+W*4)]=0;
  for(let x=0;x<W;x++){
    const si=(y*W+x)*4, di=y*(1+W*4)+1+x*4;
    raw.set(buf.slice(si,si+4),di);
  }
}
const comp=zlib.deflateSync(raw,{level:9});
const sig=Buffer.from([137,80,78,71,13,10,26,10]);
const png=Buffer.concat([sig,chunk('IHDR',ihdr),chunk('IDAT',comp),chunk('IEND',Buffer.alloc(0))]);
fs.writeFileSync('C:\\Project_game\\godot-valley-main\\graphics\\objects\\mining\\cliff_cave_facade_v2.png',png);
console.log('Done:', png.length, 'bytes');
