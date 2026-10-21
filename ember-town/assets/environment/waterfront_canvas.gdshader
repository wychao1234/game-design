shader_type spatial;
render_mode cull_disabled;
varying vec3 world_position;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);}
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float stain=smoothstep(0.34,0.67,noise(world_position.xz*1.8));
 float seam=1.0-smoothstep(0.006,0.02,abs(fract(UV.x*4.0)-0.5));
 float runoff=smoothstep(0.54,0.72,noise(vec2(UV.x*14.0,UV.y*1.4)))*smoothstep(0.05,0.8,UV.y);
 ALBEDO=mix(vec3(0.040,0.069,0.071),vec3(0.019,0.031,0.030),stain*0.7+runoff*0.25)+vec3(seam*0.012);
 ROUGHNESS=0.95;
 NORMAL_MAP=vec3(0.5+sin(UV.x*75.4)*0.03,0.5,1.0);
 NORMAL_MAP_DEPTH=0.4;
}
