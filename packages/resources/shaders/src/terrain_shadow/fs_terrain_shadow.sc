// terrain shader sample
$input v_position, v_normal, v_texcoord0, v_texcoord1,  v_texcoord4, v_texcoord5,v_texcoord6,v_texcoord7

#include "../common/common.sh"
#include "common/uniforms.sh"
#include "common/lighting.sh"

#define u_shadowMapOffset u_params1.y

// for shadow 
#define SM_PCF 1    
#define SM_CSM 1
#include "mesh_shadow/fs_ext_shadowmaps_color_lighting.sh"
 
// only Int1,Vec4,Mat3,Mat4 supported 
uniform vec4 s_lightDirection;
uniform vec4 s_lightIntensity;
uniform vec4 s_lightColor;

// define move to uniforms.sh 
uniform int s_showMode;             // debug output normal,fog  

SAMPLER2D(s_baseTexture,0);
SAMPLER2D(s_maskTexture,1);


void main()
{
    vec3  lightDirection = normalize(s_lightDirection);
	float ntol = max(0,dot(v_normal, lightDirection));
	float lightIntensity = ntol*s_lightIntensity[0];
    vec4  lightColor = s_lightColor* lightIntensity;
		  lightColor.a =  1.0;  //1.2

	vec4  textureColor = texture2D(s_baseTexture,v_texcoord0);
	vec4  maskColor    = vec4(1,1,1, texture2D(s_maskTexture,v_texcoord1).r);
						 //vec4(0.8,0.8,0.8,texture2D(s_maskTexture,v_texcoord1).r);
	textureColor.a     =  1.4;    //1.2
	
	/* 
	vec3 viewDir = -v_position;
	vec3 lightDir = lightDirection;
	float shininess = 0.08;
	float hdotn = saturate(dot(v_normal,normalize(viewDir + lightDir)));
	float specularFactor = pow(hdotn, shininess * 128);
	vec4  specularColor = s_lightColor*specularFactor;
	*/ 

	vec4 mask = vec4(v_position.y/20.0, v_position.y/20.0, v_position.y/20.0 , 1.0);
	//if(maskColor.r<=0.2)
	//	discard;
	if( s_showMode == 1) {
		vec4 color = vec4(v_normal,1.0); //*mask;
		gl_FragColor = color;
		return ;
	} 
 
	float ambientMode = ambient_mode.x;
	vec4  ambientColor = calc_ambient_color(ambientMode,v_normal.y);
		  ambientColor.a = 0.0;      				 		// notice
		  ambientColor = ambientColor*textureColor;  		// *0.25;   // divide four pass 
	vec4  diffuseColor = lightColor*textureColor*maskColor;
	#include "mesh_shadow/fs_ext_shadowmaps_color_lighting_main.sh" 
	visibility -= 0.20;
	diffuseColor.xyz *= visibility;
	gl_FragColor = saturate( (ambientColor + diffuseColor  ) );

	//gl_FragColor.xyz  = vec3( visibility,visibility,visibility );
	//gl_FragColor.xyz *= visibility;  
}      
                