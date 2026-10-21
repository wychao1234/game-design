shader_type spatial;
uniform vec3 base_tint=vec3(0.025,0.041,0.050);
varying vec3 world_position;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);}
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float weather=noise(world_position.xz*0.9);
 float clay=noise(world_position.xz*3.3);
 float lap=1.0-smoothstep(0.025,0.17,min(UV.y,1.0-UV.y));
 ALBEDO=base_tint*(0.76+weather*0.31+clay*0.12-lap*0.14);
 ALBEDO=mix(ALBEDO,vec3(0.038,0.036,0.029),smoothstep(0.63,0.87,weather)*0.18);
 ROUGHNESS=0.60+weather*0.23;SPECULAR=0.28;
}
