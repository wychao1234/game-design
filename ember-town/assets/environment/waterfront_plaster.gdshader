shader_type spatial;
varying vec3 world_position;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
    vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    vec2 p=vec2(world_position.x+world_position.z*0.47,world_position.y);
    float grain=noise(p*29.0)*0.05+noise(p*3.0)*0.10;
    float streak=noise(vec2(p.x*8.0,p.y*0.4));
    float damp=(1.0-smoothstep(0.20,1.2,world_position.y))*0.30;
    float dirt=smoothstep(0.57,0.9,streak)*0.12;
    ALBEDO=vec3(0.25,0.29,0.30)*(0.95+grain-damp-dirt);
    ROUGHNESS=0.90;
}
