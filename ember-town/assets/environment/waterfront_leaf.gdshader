shader_type spatial;
render_mode cull_disabled;
varying vec3 world_position;
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    vec2 p=UV*2.0-1.0;
    if(p.x*p.x+pow(abs(p.y),1.35)>0.96) discard;
    float variation=fract(sin(dot(floor(world_position*21.0),vec3(17.1,73.7,11.3)))*43758.5);
    ALBEDO=mix(vec3(0.13,0.28,0.22),vec3(0.29,0.40,0.27),variation);
    ALBEDO*=0.85+0.15*abs(p.y);
    ROUGHNESS=0.86;
}
