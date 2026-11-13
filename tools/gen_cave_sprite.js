// gen_cave_sprite.js — Generate cliff_cave_facade.png pixel art 128x112
// Pure Node.js, no external deps. Uses zlib for deflate.
'use strict';
const zlib = require('zlib');
const fs   = require('fs');
const path = require('path');

const W = 128, H = 112;

// ── Palette ──────────────────────────────────────────────────────────────────
const C = {
  TRANS:   [0,0,0,0],
  // Cave mouth / dark interior
  BLACK:   [10,8,12,255],
  DARK1:   [22,18,28,255],
  DARK2:   [38,30,45,255],
  // Stone / boulder
  ST_DARK:  [52,50,62,255],
  ST_MID:   [75,72,88,255],
  ST_LIGHT: [105,100,118,255],
  ST_HIGH:  [138,133,152,255],
  ST_EDGE:  [160,155,172,255],
  ST_SHAD:  [38,36,48,255],
  // Stone outline
  ST_OUT:   [28,26,36,255],
  // Wood beam
  WD_DARK:  [82,52,22,255],
  WD_MID:   [118,76,32,255],
  WD_LIGHT: [152,102,48,255],
  WD_HIGH:  [178,122,58,255],
  WD_GRAIN: [96,62,26,255],
  WD_OUT:   [52,32,12,255],
  // Moss accent
  MOSS:     [72,98,52,255],
  MOSS2:    [88,118,62,255],
  // Ground
  GND_DARK: [42,36,28,255],
  GND_MID:  [62,54,42,255],
};

// ── RGBA buffer ───────────────────────────────────────────────────────────────
const buf = Buffer.alloc(W * H * 4, 0);
function px(x, y, col) {
  if (x < 0 || x >= W || y < 0 || y >= H) return;
  const i = (y * W + x) * 4;
  buf[i]   = col[0];
  buf[i+1] = col[1];
  buf[i+2] = col[2];
  buf[i+3] = col[3];
}
function rect(x, y, w, h, col) {
  for (let dy=0;dy<h;dy++) for (let dx=0;dx<w;dx++) px(x+dx,y+dy,col);
}
function circle(cx, cy, r, col) {
  for (let dy=-r;dy<=r;dy++) for (let dx=-r;dx<=r;dx++)
    if (dx*dx+dy*dy<=r*r) px(cx+dx,cy+dy,col);
}

// ── 1. Cave mouth (black arch) ─────────────────────────────────────────────
// Arch center at (64, 72), width ~52, height ~46
const ARCH_CX = 64, ARCH_CY = 72, ARCH_RX = 26, ARCH_RY = 34;
for (let y=0;y<H;y++) for (let x=0;x<W;x++) {
  const ex = (x - ARCH_CX) / ARCH_RX;
  const ey = (y - ARCH_CY) / ARCH_RY;
  if (ex*ex + ey*ey < 1.0 && y <= ARCH_CY) px(x, y, C.BLACK);
}
// Rectangle bottom of arch
rect(ARCH_CX - ARCH_RX, ARCH_CY, ARCH_RX*2, 36, C.BLACK);

// ── 2. Dark gradient inside arch ─────────────────────────────────────────────
for (let y=38;y<=H-18;y++) for (let x=40;x<=88;x++) {
  const ex = (x - ARCH_CX) / (ARCH_RX-2);
  const ey = (y - ARCH_CY) / (ARCH_RY-2);
  if (ex*ex + ey*ey < 1.0 && y <= ARCH_CY) px(x, y, C.DARK1);
  if (ex*ex + ey*ey < 0.6 && y <= ARCH_CY) px(x, y, C.DARK2);
}

// ── 3. Boulder layout ─────────────────────────────────────────────────────────
// Each boulder: [cx, cy, rx, ry]
const boulders = [
  // bottom row
  [22, 90, 14, 11], [46, 94, 12, 10], [70, 95, 11,  9],
  [93, 93, 13, 10], [112,89, 10,  9],
  // mid-left stack
  [12, 74, 12, 10], [28, 76, 13, 10], [18, 60, 11,  9],
  [34, 62, 12, 10],
  // mid-right stack
  [116,74, 11,  9], [100,76, 13, 10], [108,60, 11,  9],
  [92, 62, 12, 10],
  // top arch boulders
  [38, 46, 11,  9], [52, 36, 12, 10], [64, 30, 13, 11],
  [76, 36, 12, 10], [90, 46, 11,  9],
  // extra fill
  [26, 50, 10,  8], [100,50, 10,  8],
  [44, 56,  9,  8], [84, 56,  9,  8],
];

function drawBoulder(cx, cy, rx, ry) {
  // fill mid
  for (let dy=-ry;dy<=ry;dy++) for (let dx=-rx;dx<=rx;dx++) {
    const e = (dx/rx)*(dx/rx)+(dy/ry)*(dy/ry);
    if (e > 1.0) continue;
    let col;
    if (e < 0.25) col = C.ST_HIGH;
    else if (e < 0.5) col = C.ST_LIGHT;
    else if (e < 0.75) col = C.ST_MID;
    else col = C.ST_DARK;
    // Shadow bottom-right
    if (dx > rx*0.3 && dy > ry*0.3) col = C.ST_SHAD;
    px(cx+dx, cy+dy, col);
  }
  // highlight top-left
  for (let dy=-ry+1;dy<=-ry/2;dy++) for (let dx=-rx+1;dx<=-rx/2;dx++) {
    const e=(dx/rx)*(dx/rx)+(dy/ry)*(dy/ry);
    if (e<0.4) px(cx+dx,cy+dy,C.ST_EDGE);
  }
  // outline
  for (let dy=-ry-1;dy<=ry+1;dy++) for (let dx=-rx-1;dx<=rx+1;dx++) {
    const e=(dx/(rx+1))*(dx/(rx+1))+(dy/(ry+1))*(dy/(ry+1));
    const ei=(dx/rx)*(dx/rx)+(dy/ry)*(dy/ry);
    if (e<=1.0 && ei>1.0) px(cx+dx,cy+dy,C.ST_OUT);
  }
}

// Draw boulders back-to-front
boulders.forEach(([cx,cy,rx,ry]) => drawBoulder(cx,cy,rx,ry));

// ── 4. Moss accents on some boulders ─────────────────────────────────────────
const mossSpots = [
  [15,65],[29,69],[38,49],[90,49],[99,69],[113,65],
  [52,38],[76,38],[63,30],
];
mossSpots.forEach(([x,y]) => {
  px(x,y,C.MOSS2); px(x+1,y,C.MOSS); px(x,y+1,C.MOSS);
  px(x-1,y,C.MOSS); px(x+1,y-1,C.MOSS2);
});

// ── 5. Wooden mine frame ─────────────────────────────────────────────────────
// Top horizontal beam: y=46..52, x=34..94
function woodBeam(x1,y1,x2,y2,thick) {
  // Direction
  const dx=x2-x1, dy=y2-y1, len=Math.sqrt(dx*dx+dy*dy);
  const nx=-dy/len, ny=dx/len; // normal
  for (let t=0;t<=len;t+=0.5) {
    const bx=x1+dx*t/len, by=y1+dy*t/len;
    for (let s=-thick/2;s<=thick/2;s+=0.5) {
      const wx=Math.round(bx+nx*s), wy=Math.round(by+ny*s);
      const frac=Math.abs(s)/(thick/2);
      let col;
      if (frac<0.3) col=C.WD_HIGH;
      else if (frac<0.6) col=C.WD_LIGHT;
      else if (frac<0.85) col=C.WD_MID;
      else col=C.WD_DARK;
      px(wx,wy,col);
    }
  }
  // grain lines along beam
  for (let t=4;t<len;t+=6) {
    const bx=Math.round(x1+dx*t/len), by=Math.round(y1+dy*t/len);
    px(bx,by,C.WD_GRAIN);
  }
  // outline
  for (let side of [-1,1]) {
    for (let t=0;t<=len;t+=0.5) {
      const bx=x1+dx*t/len, by=y1+dy*t/len;
      const wx=Math.round(bx+nx*(thick/2+1)*side);
      const wy=Math.round(by+ny*(thick/2+1)*side);
      px(wx,wy,C.WD_OUT);
    }
  }
}

// Top horizontal beam
woodBeam(32, 50, 96, 50, 8);
// Left diagonal post: from bottom-left (44,100) to top arch join (46,52)
woodBeam(44, 100, 46, 52, 7);
// Right diagonal post: from bottom-right (84,100) to top arch join (82,52)
woodBeam(84, 100, 82, 52, 7);
// Small brace left
woodBeam(46,66,56,56,4);
// Small brace right
woodBeam(82,66,72,56,4);

// ── 6. Redraw cave mouth over wood so interior stays dark ────────────────────
for (let y=0;y<H;y++) for (let x=0;x<W;x++) {
  const ex=(x-ARCH_CX)/ARCH_RX, ey=(y-ARCH_CY)/ARCH_RY;
  if (ex*ex+ey*ey < 1.0 && y <= ARCH_CY+2) {
    const ex2=(x-ARCH_CX)/(ARCH_RX-1), ey2=(y-ARCH_CY)/(ARCH_RY-1);
    if (ex2*ex2+ey2*ey2 < 0.95) px(x,y,C.BLACK);
  }
  if (x>=ARCH_CX-ARCH_RX+2 && x<=ARCH_CX+ARCH_RX-2 && y>ARCH_CY && y<H-14)
    px(x,y,C.BLACK);
}
// Arch edge DARK2
for (let y=0;y<H;y++) for (let x=0;x<W;x++) {
  const ex=(x-ARCH_CX)/ARCH_RX, ey=(y-ARCH_CY)/ARCH_RY;
  if (ex*ex+ey*ey>=0.92 && ex*ex+ey*ey<1.0 && y<=ARCH_CY+2)
    px(x,y,C.DARK2);
}

// ── 7. Ground floor of entrance ───────────────────────────────────────────────
for (let y=H-16;y<H;y++) {
  for (let x=36;x<=92;x++) {
    const col = (y < H-10) ? C.GND_DARK : C.GND_MID;
    px(x,y,col);
  }
}

// ── 8. Stone fill between boulders (grey mortar) ─────────────────────────────
// Just fill the entire arch outline area with dark stone base first (behind boulders)
// Already handled by boulders overlap

// ── PNG encode ───────────────────────────────────────────────────────────────
function crc32(buf) {
  let c=0xFFFFFFFF;
  const t=new Uint32Array(256);
  for(let i=0;i<256;i++){let v=i;for(let j=0;j<8;j++)v=v&1?0xEDB88320^(v>>>1):v>>>1;t[i]=v;}
  for(let i=0;i<buf.length;i++)c=t[(c^buf[i])&0xFF]^(c>>>8);
  return (~c)>>>0;
}
function chunk(type, data) {
  const tb=Buffer.from(type,'ascii');
  const len=Buffer.alloc(4); len.writeUInt32BE(data.length);
  const crcBuf=Buffer.concat([tb,data]);
  const crcVal=Buffer.alloc(4); crcVal.writeUInt32BE(crc32(crcBuf));
  return Buffer.concat([len,tb,data,crcVal]);
}

// IHDR
const ihdr=Buffer.alloc(13);
ihdr.writeUInt32BE(W,0); ihdr.writeUInt32BE(H,4);
ihdr[8]=8; ihdr[9]=6; ihdr[10]=0; ihdr[11]=0; ihdr[12]=0;

// Raw scanlines (filter byte 0 = None)
const raw=Buffer.alloc(H*(1+W*4));
for(let y=0;y<H;y++){
  raw[y*(1+W*4)]=0; // filter none
  for(let x=0;x<W;x++){
    const si=(y*W+x)*4, di=y*(1+W*4)+1+x*4;
    raw[di]=buf[si]; raw[di+1]=buf[si+1]; raw[di+2]=buf[si+2]; raw[di+3]=buf[si+3];
  }
}
const compressed=zlib.deflateSync(raw,{level:9});

const sig=Buffer.from([137,80,78,71,13,10,26,10]);
const png=Buffer.concat([sig, chunk('IHDR',ihdr), chunk('IDAT',compressed), chunk('IEND',Buffer.alloc(0))]);

const outPath = path.join('C:\\Project_game\\godot-valley-main\\graphics\\objects\\mining\\cliff_cave_facade_new.png');
fs.writeFileSync(outPath, png);
console.log('Written:', outPath, png.length, 'bytes');
