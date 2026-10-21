shader_type spatial;
varying float along;
void vertex(){along=UV.y*length(MODEL_MATRIX[1].xyz);}
void fragment(){
 float phase=UV.x*18.84956+along*62.0;
 float fibre=sin(phase)/(1.0+fwidth(phase)*2.0);
 ALBEDO=vec3(0.32,0.24,0.13)*(0.94+fibre*0.08);
 ROUGHNESS=0.94;SPECULAR=0.16;
}
