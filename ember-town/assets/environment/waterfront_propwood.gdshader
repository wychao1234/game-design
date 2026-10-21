shader_type spatial;
uniform vec4 base_tint:source_color=vec4(0.5,0.39,0.28,1.0);
uniform sampler2D albedo_tex:source_color,filter_linear_mipmap,repeat_enable;
uniform bool use_albedo=false;
uniform bool force_endgrain=false;
uniform bool world_grain=false;
varying vec3 world_position;
varying vec3 physical;
varying vec3 unit_position;
varying vec3 local_normal;
varying vec3 dimensions;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);}
void vertex(){
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 dimensions=vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
 physical=VERTEX*dimensions;unit_position=VERTEX;local_normal=NORMAL;
}
void fragment(){
 vec3 p=physical;vec3 n=abs(local_normal);
 float longitudinal=p.y;float across=p.x+p.z;vec2 end=p.xz;float endness=pow(n.y,6.0);
 if(dimensions.x>dimensions.y && dimensions.x>dimensions.z){longitudinal=p.x;across=p.y+p.z;end=p.yz;endness=pow(n.x,6.0);}
 else if(dimensions.z>dimensions.y && dimensions.z>dimensions.x){longitudinal=p.z;across=p.x+p.y;end=p.xy;endness=pow(n.z,6.0);}
 if(world_grain){longitudinal=world_position.x;across=world_position.y*1.4;endness=0.0;}
 if(force_endgrain){end=physical.xz;endness=1.0;}
 vec3 timber=base_tint.rgb*0.78;
 if(use_albedo){vec3 tex=texture(albedo_tex,vec2(longitudinal*0.39,across*1.1)).rgb;timber=mix(timber,tex*0.92,0.68);}
 float rings=0.5+0.5*sin(length(end)*85.0+noise(end*7.0)*1.4);
 vec3 cut=base_tint.rgb*(0.66+rings*0.17);
 timber=mix(timber,cut,endness*0.76);
 float weather=noise(world_position.xz*0.83+world_position.y*0.2);
 float damp=(1.0-smoothstep(-0.1,0.60,world_position.y))*0.30;
 float grey=dot(timber,vec3(0.2126,0.7152,0.0722));
 timber=mix(timber,vec3(grey*0.96,grey,grey*1.04),0.42);
 float splash=smoothstep(0.48,0.72,noise(world_position.xz*1.7+world_position.y*0.28));
 timber*=0.83+weather*0.20-damp-splash*0.16;
 float edge=0.5-max(abs(unit_position.x),abs(unit_position.z));
 if(n.x>n.y && n.x>n.z)edge=0.5-max(abs(unit_position.y),abs(unit_position.z));
 else if(n.z>n.y)edge=0.5-max(abs(unit_position.x),abs(unit_position.y));
 float wear=(1.0-smoothstep(0.0,0.025,edge))*noise(world_position.xy*3.0)*0.035;
 ALBEDO=timber+vec3(wear,wear*0.80,wear*0.53);
 ROUGHNESS=0.58+weather*0.18-damp*0.35;
 SPECULAR=0.30;
 float grain=noise(vec2(across*31.0,longitudinal*1.2));
 NORMAL_MAP=vec3(0.5+(grain-0.5)*0.035,0.5,1.0);NORMAL_MAP_DEPTH=0.4;
}
