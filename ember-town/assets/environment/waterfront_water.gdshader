shader_type spatial;
render_mode cull_disabled;
uniform vec4 lamps[16];
uniform int lamp_count=0;
varying vec3 world_position;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);}
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=world_position.xz;
 // Broad quiet water separates the architecture. Fine ripples break highlights,
 // rather than drawing a repeated bright pattern over the entire canal.
 vec2 toward_view=vec2(0.3104,0.9506);
 vec2 across_view=vec2(0.9506,-0.3104);
 float along_water=dot(p,toward_view);
 float across_water=dot(p,across_view);
 float swell=noise(p*0.44+vec2(TIME*0.035,-TIME*0.055));
 float ripple=sin(along_water*9.8+sin(across_water*1.7+TIME*0.24)*1.1+TIME*1.15);
 float detail_scale=mix(1.0,1.7,smoothstep(4.0,32.0,-p.y));
 float fine=noise(vec2(across_water*5.4,along_water*15.3+TIME*0.28)*detail_scale);
 float broken_wave=sin(along_water*17.0+noise(p*0.8)*5.0+TIME*0.86);
 float glints=smoothstep(0.32,0.86,broken_wave)*smoothstep(0.30,0.74,fine);
 float breakup=smoothstep(0.29,0.64,noise(vec2(across_water*11.3,along_water*22.7+TIME*0.12)));
 float sky_fragments=smoothstep(0.55,0.77,fine)*smoothstep(0.43,0.74,noise(p*0.65+vec2(2.1,-TIME*0.025)))*breakup;
 float warm=0.0;
 for(int i=0;i<16;i++){
  if(i>=lamp_count)break;
  vec2 d=p-lamps[i].xy;
  float along=dot(d,toward_view);
  float across=dot(d,across_view);
  float spread=0.13+clamp(along,0.0,7.0)*0.048;
  float shimmer=(swell-0.5)*0.25+sin(along_water*4.3+TIME*0.7)*0.055;
  float envelope=exp(-pow((across+shimmer)/spread,2.0));
  envelope*=exp(-max(along,0.0)*0.44)*exp(-max(-along,0.0)*1.8);
  warm+=envelope*lamps[i].z*glints;
 }
 ALBEDO=mix(vec3(0.008,0.021,0.031),vec3(0.016,0.039,0.055),swell);
 EMISSION=vec3(0.84,0.31,0.068)*min(warm,1.6)*0.55+vec3(0.020,0.052,0.082)*sky_fragments;
 ROUGHNESS=0.16+swell*0.12;
 METALLIC=0.0;
 SPECULAR=0.55;
 NORMAL_MAP=vec3(0.5+sin(across_water*2.6+TIME*0.37+swell*2.1)*0.032,0.5+ripple*0.045+(fine-0.5)*0.050,1.0);
 NORMAL_MAP_DEPTH=0.65;
}
