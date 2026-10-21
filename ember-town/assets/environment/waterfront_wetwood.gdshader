shader_type spatial;
uniform vec4 base_tint:source_color=vec4(0.20,0.15,0.12,1.0);
uniform sampler2D albedo_tex:source_color,filter_linear_mipmap,repeat_enable;
uniform bool use_albedo=false;
varying vec3 world_position;
varying vec2 board_uv;
varying float board_seed;
varying float board_top;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);}
void vertex(){
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 vec2 origin=MODEL_MATRIX[3].xz;
 board_seed=hash(origin+vec2(7.2,18.1));
 board_top=max(NORMAL.y,0.0);
 // Each board takes an interior crop of the wood image, so no tiled edge crosses a plank.
 board_uv=vec2(VERTEX.z*length(MODEL_MATRIX[2].xyz)*0.18,VERTEX.x*length(MODEL_MATRIX[0].xyz)*0.6)+vec2(0.5+hash(origin)*0.1,0.2+hash(origin.yx+vec2(19.0))*0.6);
}
void fragment(){
 vec2 p=world_position.xz;
 vec2 wooduv=board_uv;
 float grain=noise(vec2(p.x*28.0+sin(p.y*0.6)*0.8,p.y*0.7));
 // Separate broken shallow puddles, with dry grain between them. No continuous mirror strip.
 float basin=noise(p*0.82)*0.58+noise(p*2.7+vec2(9.1,3.6))*0.42;
 float wet=smoothstep(0.45,0.60,basin);
 float breakup=smoothstep(0.34,0.64,noise(p*vec2(9.5,5.6)));
 wet*=0.35+0.65*breakup;
 // Intact puddle cores keep water roughness; breakup only erodes their edges.
 wet=max(wet,smoothstep(0.53,0.65,basin));
 vec3 tex=texture(albedo_tex,wooduv).rgb;
 vec3 wood=base_tint.rgb*(0.85+grain*0.15);
 if(use_albedo) wood=mix(wood,tex*base_tint.rgb*3.4,0.65);
 float edge=min(min(UV.x,1.0-UV.x),min(UV.y,1.0-UV.y));
 float wear=(1.0-smoothstep(0.0,0.055,edge))*noise(p*vec2(17.0,3.0));
 ALBEDO=wood*mix(1.0,0.65,wet)+vec3(0.026,0.025,0.022)*wear;
 ROUGHNESS=mix(0.79,0.17,wet);
 METALLIC=0.015;
 SPECULAR=0.36;
 // Only twelve percent of boards have a long split from one end; this is coherent wear, not all-over grit.
 float along=mix(UV.y,1.0-UV.y,step(0.5,fract(board_seed*13.7)));
 float split_center=0.22+fract(board_seed*41.13)*0.55+sin(along*17.0+board_seed*65.0)*0.016;
 float split_width=0.008+0.035*pow(along,4.0);
 float split_aa=max(fwidth(UV.x)*0.6,0.006);
 float fissure=(1.0-smoothstep(split_width,split_width+split_aa,abs(UV.x-split_center)))*smoothstep(0.50,0.73,along)*step(0.88,board_seed)*board_top;
 ALBEDO=mix(ALBEDO,vec3(0.006,0.008,0.009),fissure*0.82);
 ROUGHNESS=mix(ROUGHNESS,0.94,fissure);
 // Filter texture derivatives at the actual screen footprint: old wood relief breaks highlights without moire.
 vec2 delta=max(fwidth(wooduv)*1.2,vec2(0.0016));
 float h=dot(tex,vec3(0.333));
 float hx=dot(texture(albedo_tex,wooduv+vec2(delta.x,0)).rgb,vec3(0.333))-h;
 float hy=dot(texture(albedo_tex,wooduv+vec2(0,delta.y)).rgb,vec3(0.333))-h;
 float ripple=noise(p*vec2(8.0,3.4));
 float ripple2=noise(p*vec2(5.7,8.9)+vec2(43.1,17.3));
 NORMAL_MAP=vec3(0.5+hy*0.7+(ripple-0.5)*0.19,0.5+hx*0.7+(ripple2-0.5)*0.19,1.0);
 NORMAL_MAP_DEPTH=0.65;
}
