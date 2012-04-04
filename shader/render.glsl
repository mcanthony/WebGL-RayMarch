#ifdef GL_ES
precision highp float;
#endif

/* CONSTANTS */
#define EPS       0.001
#define EPS1      0.01
#define PI        3.14159265
#define HALFPI    1.57079633
#define ROOTTHREE 0.57735027
#define HUGE_VAL  10000000000.0

#define MAX_STEPS 64


/* SHADER VARS */
varying vec2 vUv;

uniform vec3 uCamCenter;
uniform vec3 uCamPos;
uniform vec3 uCamUp;
uniform float uAspect;
uniform vec3 uLightP;

/* GENERAL FUNCS */
// credit: inigo quilez
float maxcomp(in vec3 p ) { return max(p.x,max(p.y,p.z));}

/* DISTANCE FUNCS */
// http://www.iquilezles.org/www/articles/distfunctions/distfunctions.htm
float sdSphere( vec3 p, float s )
{
  return length(p)-s;
}
float sdBox( vec3 p, vec3 b ) {
  vec3  di = abs(p) - b;
  float mc = maxcomp(di);
  return min(mc,length(max(di,0.0)));
}
float udBox( vec3 p, vec3 b )
{
  return length(max(abs(p)-b,0.0));
}
float udRoundBox( vec3 p, vec3 b, float r )
{
  return length(max(abs(p)-b,0.0))-r;
}
float sdTorus( vec3 p, vec2 t )
{
  vec2 q = vec2(length(p.xz)-t.x,p.y);
  return length(q)-t.y;
}
float sdPlane( vec3 p, vec4 n )
{
  // n must be normalized
  return dot(p,n.xyz) + n.w;
}

vec4 map( in vec3 p ) {
  float d = sdBox(p,vec3(1.0));
  
  vec3 testOffset = vec3(3.0, 0.0, 0.0);
  float d1 = sdBox(p+testOffset, vec3(1.0));
  d = ( d > d1 ) ? d1 : d;
  d1 = sdBox(p-testOffset, vec3(1.0));
  d = ( d > d1 ) ? d1 : d;
  vec4 res = vec4( d, 1.0, 0.0, 0.0 );

  /*
  float s = 1.0;
  for( int m=0; m<3; m++ ) 
  {
    vec3 a = mod( p*s, 2.0 )-1.0;
    s *= 3.0;
    vec3 r = abs(1.0 - 3.0*abs(a));

    float da = max(r.x,r.y);
    float db = max(r.y,r.z);
    float dc = max(r.z,r.x);
    float c = (min(da,min(db,dc))-1.0)/s;

    if( c>d )
    {
      d = c;
      res = vec4( d, 0.2*da*db*dc, (1.0+float(m))/4.0, 0.0 );
    }
  }
  */

  return res;
}

float getDist(in vec3 p) {
  // wrapping xz plane
  //p.x = mod(p.x,4.0)-2.0;
  //p.z = mod(p.z,4.0)-2.0;
  
  float d0, d1;
  //d0 = sdSphere(p, 1.0);
  d0 = udRoundBox(p, vec3(0.75), 0.25);
  //d0 = sdBox(p,vec3(1.0));
  d1 = sdPlane(p+vec3(0.0,1.0,0.0), vec4(0.0,1.0,0.0,0.0));
  d0 = d1 < d0 ? d1 : d0;
  
  //vec3 testOffset = vec3(3.0, 0.0, 0.0);  
  //d0 = udRoundBox(p, vec3(0.75), 0.25);
  //d1 = sdBox(p+testOffset, vec3(1.0));
  //d0 = d1 < d0 ? d1 : d0;
  //d1 = sdSphere(p-testOffset, 1.0);
  //d0 = d1 < d0 ? d1 : d0;
  //d1 = sdPlane(p+vec3(0.0,1.0,0.0), vec4(0.0,1.0,0.0,0.0));
  //d0 = d1 < d0 ? d1 : d0;
  
  return d0;
}

// credit: inigo quilez
vec3 getNormal(in vec3 pos) {
  vec3  eps = vec3(EPS, 0.0, 0.0);
  vec3 nor;
  nor.x = getDist(pos+eps.xyy) - getDist(pos-eps.xyy);
  nor.y = getDist(pos+eps.yxy) - getDist(pos-eps.yxy);
  nor.z = getDist(pos+eps.yyx) - getDist(pos-eps.yyx);
  return normalize(nor);
}

/*
vec4 intersect( in vec3 ro, in vec3 rd ) {
  float t = 0.0;
  vec4 res = vec4(-1.0);
  for(int i=0;i<64;i++)
  {
    vec4 h = map(ro + rd*t);
    if( h.x<0.002 )
    {
      if( res.x<0.0 ) res = vec4(t,h.yzw);
    }
    t += h;
  }
  return res;
}
*/

int intersectSteps(in vec3 ro, in vec3 rd) {
  float t = 0.0;
  int steps = -1;  
  
  for(int i=0; i<MAX_STEPS; ++i)
  {
    float dt = getDist(ro + rd*t);
    if(dt >= EPS)
      steps++;    // no intersect case
    else
      break;      // break must be under else
    t += dt;
  }
  return steps;
}
float intersectDist(in vec3 ro, in vec3 rd) {
  float t = 0.0;
  
  for(int i=0; i<MAX_STEPS; ++i)
  {
    float dt = getDist(ro + rd*t);
    if(dt >= EPS)
      ;       // no intersect case
    else
      break;  // break must be under else
    t += dt;
  }
  
  return t;
}

#define LIGHT_I 1.0
#define KA      0.4
#define KD      0.6
vec3 getDifuse (in vec3 pos, in vec3 nor, in vec3 col) {
  vec3 lightv = normalize(uLightP-pos);  
  return col*(KA + KD*LIGHT_I*dot(lightv,nor));
}

#define AO_K      1.5
#define AO_DELTA  0.15
#define AO_N      5
float getAO (in vec3 pos, in vec3 nor) {
  float sum = 0.0;
  float weight = 0.5;
  float delta = AO_DELTA;
  
  for (int i=1; i<=AO_N; ++i) {
    sum += weight * (delta - getDist(pos+nor*delta));
    
    delta += AO_DELTA;
    weight *= 0.5;
  }
  return 1.0 - AO_K*sum;
}

#define SS_K      0.7
#define SS_DELTA  0.15
#define SS_BLEND  0.8
#define SS_N      6
float getSoftShadows (in vec3 pos) {
  vec3 lightv = normalize(uLightP-pos);
  
  float sum = 0.0;
  float blend = SS_BLEND;
  float delta = SS_DELTA;
  
  for (int i=1; i<=SS_N; ++i) {
    sum += blend * (delta - getDist(pos+lightv*delta));
    
    delta += SS_DELTA;
    blend *= SS_BLEND;
  }
  return 1.0 - SS_K*sum;
}

void main(void) {
  
  /* CAMERA RAY */
  vec3 C = normalize(uCamCenter-uCamPos);
  vec3 A = normalize(cross(C,uCamUp));
  vec3 B = -1.0/uAspect*normalize(cross(A,C));
  
  // scale A and B by root3/3 : fov = 30 degrees
  vec3 ro = uCamPos+C + (2.0*vUv.x-1.0)*ROOTTHREE*A + (2.0*vUv.y-1.0)*ROOTTHREE*B;
  vec3 rd = normalize(ro-uCamPos);
  
  
  /* RENDERING */
  
  //int steps = intersectSteps(ro, rd);  
  //gl_FragColor = vec4(vec3(float(MAX_STEPS-steps)/float(MAX_STEPS)), 1.0);
  
  float t = intersectDist(ro, rd);
  
  if (t>0.0) {
    vec3 pos = ro + rd*t;    
    vec3 nor = getNormal(pos);
    
    vec3 col = getDifuse(pos, nor, vec3(0.9, 0.7, 0.5));
    //vec3 col = vec3(1.0);
    
    // Ambient Occlusion
    //float ao = getAO(pos, nor);
    //col *= ao;
    
    // Soft Shadows
    float ss = getSoftShadows(pos);
    col *= ss;
    
    // Add Fog
    //float fogAmount = 1.0-exp(-0.02*t);
    //col = mix(col, vec3(0.4, 0.6, 0.8), fogAmount);
    
    gl_FragColor = vec4(col, 1.0);
  }
  else {
    gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
  }
  
  /*
  // light
  vec3 light = normalize(vec3(1.0,0.8,-0.6));
  
  vec3 col = vec3(0.0);
  vec4 tmat = intersect(ro,rd);
  if( tmat.x>0.0 )
  {
    vec3 pos = ro + tmat.x*rd;
    vec3 nor = getNormal(pos);

    float dif1 = max(0.4 + 0.6*dot(nor,light),0.0);
    float dif2 = max(0.4 + 0.6*dot(nor,vec3(-light.x,light.y,-light.z)),0.0);
    
    // shadow
    float ldis = 4.0;
    vec4 shadow = intersect( pos + light*ldis, -light );
    if( shadow.x>0.0 && shadow.x<(ldis-0.01) ) dif1=0.0;
    
    float ao = tmat.y;
    col  = 1.0*ao*vec3(0.2,0.2,0.2);
    col += 2.0*(0.5+0.5*ao)*dif1*vec3(1.0,0.97,0.85);
    col += 0.2*(0.5+0.5*ao)*dif2*vec3(1.0,0.97,0.85);
    col += 1.0*(0.5+0.5*ao)*(0.5+0.5*nor.y)*vec3(0.1,0.15,0.2);
    
    // gamma lighting
    col = col*0.5+0.5*sqrt(col)*1.2;

    vec3 matcol = vec3(
      0.6+0.4*cos(5.0+6.2831*tmat.z),
      0.6+0.4*cos(5.4+6.2831*tmat.z),
      0.6+0.4*cos(5.7+6.2831*tmat.z) );
    col *= matcol;
    col *= 1.5*exp(-0.5*tmat.x);
  }
  
  gl_FragColor = vec4(col,1.0);
  */
}