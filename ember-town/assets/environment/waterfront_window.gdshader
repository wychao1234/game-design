shader_type spatial;
varying vec3 world_position;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);}
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float paper=noise(world_position.xy*1.7+world_position.z*0.31);
 float soot=smoothstep(0.55,0.87,noise(world_position.xy*2.4))*0.17;
 ALBEDO=vec3(0.25,0.115,0.025);
 EMISSION=vec3(1.35,0.37,0.055)*(0.67+paper*0.35-soot);
 ROUGHNESS=0.89;
}
