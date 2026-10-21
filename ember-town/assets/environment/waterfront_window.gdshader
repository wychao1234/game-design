shader_type spatial;
uniform float light_strength=1.0;
varying vec3 world_position;
varying vec2 pane_position;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);}
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;pane_position=VERTEX.xy+vec2(0.5);}
void fragment(){
 vec2 p=pane_position;
 float edge=min(min(p.x,1.0-p.x),min(p.y,1.0-p.y));
 float rim=smoothstep(0.0,0.14,edge);
 float core=exp(-dot((p-vec2(0.46,0.40))*vec2(1.7,1.45),(p-vec2(0.46,0.40))*vec2(1.7,1.45)));
 float paper=0.88+noise(world_position.xy*1.7+world_position.z*0.31)*0.12;
 float soot=smoothstep(0.58,0.95,p.y)*smoothstep(0.38,0.76,noise(world_position.xy*2.4))*0.48;
 float join=1.0-smoothstep(0.008,0.026,abs(p.y-0.34));
 ALBEDO=vec3(0.17,0.085,0.032)*(0.72+rim*0.28);
 EMISSION=mix(vec3(0.21,0.056,0.011),vec3(1.85,0.69,0.17),core)*rim*paper*(1.0-soot)*(1.0-join*0.22)*light_strength;
 ROUGHNESS=0.89;
}
