shader_type spatial;
varying vec3 paper_position;
varying vec3 paper_normal;
varying float lamp_seed;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);}
void vertex(){
 paper_position=VERTEX;paper_normal=NORMAL;
 lamp_seed=hash(MODEL_MATRIX[3].xz+vec2(17.1,3.7));
}
void fragment(){
 float h=clamp(paper_position.y+0.5,0.0,1.0);
 float around=atan(paper_position.z,paper_position.x)/6.2831853+0.5;
 float panel=fract(around*8.0);
 float seam=1.0-smoothstep(0.025,0.075,min(panel,1.0-panel));
 float rim=smoothstep(0.0,0.16,min(h,1.0-h));
 float core=pow(max(0.0,1.0-pow((h-0.46)/0.52,2.0)),1.35);
 float paper=0.89+noise(vec2(around*17.0+lamp_seed*4.0,h*3.6))*0.11;
 float soot=smoothstep(0.62,0.98,h)*smoothstep(0.38,0.75,noise(vec2(around*5.0+lamp_seed*13.0,h*2.0)))*0.48;
 float side=1.0-smoothstep(0.15,0.75,abs(paper_normal.y));
 ALBEDO=vec3(0.32,0.15,0.045)*paper*(1.0-soot)*(1.0-seam*0.32);
 EMISSION=mix(vec3(0.19,0.055,0.012),vec3(2.7,1.1,0.27),core)*rim*paper*(1.0-soot)*(1.0-seam*0.38)*side;
 ROUGHNESS=0.91;
 SPECULAR=0.16;
}
