#include <SDL.h>
#include <math.h>
#include <stdio.h>

#include "gl_posix.h"

static const char *const vertex_shader =
    "#version 330 core\n"
    "out vec2 uv;\n"
    "void main(){\n"
    "  uv = vec2((gl_VertexID << 1) & 2, gl_VertexID & 2);\n"
    "  gl_Position = vec4(2.0 * uv - 1.0, 0.0, 1.0);\n"
    "}\n";

static const char *const lighting_shader =
    "#version 330 core\n"
    "in vec2 uv; out vec4 effect;\n"
    "uniform sampler2D sceneDepth, sceneColor;\n"
    "uniform vec4 projection;\n"
    "vec3 positionAt(vec2 s) {\n"
    "  float d=texture(sceneDepth,s).r;\n"
    "  float z=projection.w / (2.0*d-1.0+projection.z);\n"
    "  return vec3((2.0*s-1.0)*z/projection.xy,z);\n"
    "}\n"
    "void main(){\n"
    "  effect=vec4(0);\n"
    "  if(texture(sceneDepth,uv).r>=0.99998) return;\n"
    "  vec2 texel=1.0/vec2(textureSize(sceneDepth,0));\n"
    "  vec3 p=positionAt(uv);\n"
    "  vec3 dx=positionAt(uv+vec2(texel.x,0))-p, dl=p-positionAt(uv-vec2(texel.x,0));\n"
    "  vec3 dy=positionAt(uv+vec2(0,texel.y))-p, db=p-positionAt(uv-vec2(0,texel.y));\n"
    "  vec3 n=normalize(cross(abs(dx.z)<abs(dl.z)?dx:dl,abs(dy.z)<abs(db.z)?dy:db));\n"
    "  if(dot(n,p)>0.0) n=-n;\n"
    "  float ao=0.0; vec3 bounce=vec3(0);\n"
    "  for(int i=0;i<12;++i){\n"
    "    float angle=2.399963*float(i);\n"
    "    float radius=mix(0.35,6.4,(float(i)+0.5)/12.0);\n"
    "    vec2 s=uv+vec2(cos(angle),sin(angle))*projection.xy*radius/(2.0*p.z);\n"
    "    if(any(lessThan(s,vec2(0)))||any(greaterThan(s,vec2(1)))) continue;\n"
    "    vec3 q=positionAt(s)-p;\n"
    "    float distance=length(q);\n"
    "    float h=dot(n,q);\n"
    "    ao+=smoothstep(0.10,0.82,h)*(1.0-smoothstep(0.65,3.7,distance));\n"
    "    vec3 c=texture(sceneColor,s).rgb;\n"
    "    float peak=max(c.r,max(c.g,c.b)), low=min(c.r,min(c.g,c.b));\n"
    "    float energy=smoothstep(0.36,0.82,peak)*(0.12+0.88*smoothstep(0.10,0.45,peak-low));\n"
    "    bounce+=(c*0.24+max(c-vec3(low),0.0))*energy*(1.0-smoothstep(0.85,7.0,distance))*smoothstep(0.05,1.15,h);\n"
    "  }\n"
    "  vec3 base=texture(sceneColor,uv).rgb;\n"
    "  float luma=dot(base,vec3(0.2126,0.7152,0.0722));\n"
    "  float facing=max(dot(n,normalize(vec3(-0.40,0.65,-0.65))),0.0);\n"
    "  float key=0.70*smoothstep(0.10,0.92,facing)+0.30*smoothstep(0.20,0.82,luma);\n"
    "  float visible=smoothstep(0.018,0.20,luma);\n"
    "  vec3 darkFill=vec3(0.036,0.105,0.22)*(1.0-key);\n"
    "  vec3 warmKey=vec3(0.27,0.126,0.043)*key;\n"
    "  vec3 relight=(darkFill+warmKey)*visible*(0.65+0.35*luma);\n"
    "  float shadow=min(0.39,0.12*visible+ao*0.13);\n"
    "  effect=vec4(relight+min(bounce*0.49,vec3(0.15)),shadow);\n"
    "}\n";

static const char *const composite_shader =
    "#version 330 core\n"
    "in vec2 uv; out vec4 result; uniform sampler2D lighting;\n"
    "void main(){ result=texture(lighting,uv); }\n";

static struct {
    GLuint shader, composite, vao, depth_fb, effect_fb, depth, effect;
    GLint depth_uniform, color_uniform, projection_uniform, effect_uniform;
    int width, height, clip_planes;
    int failed;
} light;
static SDL_atomic_t lighting_enabled;

static GLuint build_shader(GLenum type, const char *src)
{
    GLuint id = glCreateShader(type);
    glShaderSource(id, 1, &src, NULL);
    glCompileShader(id);
    GLint ok;
    glGetShaderiv(id, GL_COMPILE_STATUS, &ok);
    if (ok) return id;
    char log[1024];
    glGetShaderInfoLog(id, sizeof log, NULL, log);
    fprintf(stderr, "[lighting] shader compile: %s\n", log);
    glDeleteShader(id);
    return 0;
}

static GLuint build_program(GLuint vertex, const char *src)
{
    GLuint fragment = build_shader(GL_FRAGMENT_SHADER, src);
    if (!fragment) return 0;
    GLuint id = glCreateProgram();
    glAttachShader(id, vertex);
    glAttachShader(id, fragment);
    glLinkProgram(id);
    glDeleteShader(fragment);
    GLint ok;
    glGetProgramiv(id, GL_LINK_STATUS, &ok);
    if (ok) return id;
    char log[1024];
    glGetProgramInfoLog(id, sizeof log, NULL, log);
    fprintf(stderr, "[lighting] shader link: %s\n", log);
    glDeleteProgram(id);
    return 0;
}

static int setup(int w, int h)
{
    if (!light.shader) {
        GLuint v = build_shader(GL_VERTEX_SHADER, vertex_shader);
        if (!v) return 0;
        light.shader = build_program(v, lighting_shader);
        light.composite = build_program(v, composite_shader);
        glDeleteShader(v);
        if (!light.shader || !light.composite) return 0;
        light.depth_uniform = glGetUniformLocation(light.shader, "sceneDepth");
        light.color_uniform = glGetUniformLocation(light.shader, "sceneColor");
        light.projection_uniform = glGetUniformLocation(light.shader, "projection");
        light.effect_uniform = glGetUniformLocation(light.composite, "lighting");
        glGenVertexArrays(1, &light.vao);
        glGenFramebuffers(1, &light.depth_fb);
        glGenFramebuffers(1, &light.effect_fb);
        glGetIntegerv(GL_MAX_CLIP_DISTANCES, &light.clip_planes);
        glGenTextures(1, &light.depth);
        glGenTextures(1, &light.effect);
    }
    if (w == light.width && h == light.height) return 1;
    light.width = w;
    light.height = h;
    glBindTexture(GL_TEXTURE_2D, light.depth);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH24_STENCIL8, w, h, 0,
                 GL_DEPTH_STENCIL, GL_UNSIGNED_INT_24_8, NULL);
    glBindTexture(GL_TEXTURE_2D, light.effect);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    glBindFramebuffer(GL_FRAMEBUFFER, light.depth_fb);
    glDrawBuffer(GL_NONE);
    glReadBuffer(GL_NONE);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_TEXTURE_2D, light.depth, 0);
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) return 0;
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, light.effect_fb);
    glFramebufferTexture2D(GL_DRAW_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, light.effect, 0);
    return glCheckFramebufferStatus(GL_DRAW_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE;
}

static int SDLCALL lighting_key(void *unused, SDL_Event *event)
{
    (void)unused;
    if (event->type == SDL_KEYDOWN && !event->key.repeat &&
        event->key.keysym.sym == SDLK_F7) {
        int previous = SDL_AtomicGet(&lighting_enabled);
        SDL_AtomicSet(&lighting_enabled, !previous);
        fprintf(stderr, "[lighting] %s\n", previous ? "off" : "on");
    }
    return 1;
}

void hotd4_lighting_apply(void)
{
    if (!SDL_GL_GetCurrentContext() || !GLEW_VERSION_3_3 || light.failed) return;
    static int watched;
    if (!watched) {
        SDL_AtomicSet(&lighting_enabled, 1);
        SDL_AddEventWatch(lighting_key, NULL);
        watched = 1;
        fprintf(stderr, "[lighting] on (F7 toggles)\n");
    }
    if (!SDL_AtomicGet(&lighting_enabled)) return;

    GLint draw_fb, read_fb, viewport[4], color_type, color;
    GLfloat projection[16];
    glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING, &draw_fb);
    if (!draw_fb) return;
    glGetIntegerv(GL_VIEWPORT, viewport);
    int w, h;
    lindbergh_window_size(&w, &h);
    if (viewport[0] || viewport[1] || viewport[2] != w || viewport[3] != h) return;
    glGetFloatv(GL_PROJECTION_MATRIX, projection);
    if (fabsf(projection[11] + 1.0f) > 0.001f || projection[0] <= 0 ||
        projection[5] <= 0 || projection[14] >= 0) return;
    glGetFramebufferAttachmentParameteriv(GL_DRAW_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                                          GL_FRAMEBUFFER_ATTACHMENT_OBJECT_TYPE, &color_type);
    if (color_type != GL_TEXTURE) return;
    glGetFramebufferAttachmentParameteriv(GL_DRAW_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                                          GL_FRAMEBUFFER_ATTACHMENT_OBJECT_NAME, &color);

    GLint old_program, old_vao, old_unit, unpack, tex[2], sampler[2];
    glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING, &read_fb);
    glGetIntegerv(GL_CURRENT_PROGRAM, &old_program);
    glGetIntegerv(GL_VERTEX_ARRAY_BINDING, &old_vao);
    glGetIntegerv(GL_ACTIVE_TEXTURE, &old_unit);
    glGetIntegerv(GL_PIXEL_UNPACK_BUFFER_BINDING, &unpack);
    glPushAttrib(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_ENABLE_BIT |
                 GL_POLYGON_BIT | GL_SCISSOR_BIT | GL_VIEWPORT_BIT);
    for (int i = 0; i < 2; i++) {
        glActiveTexture(GL_TEXTURE0 + i);
        glGetIntegerv(GL_TEXTURE_BINDING_2D, &tex[i]);
        glGetIntegerv(GL_SAMPLER_BINDING, &sampler[i]);
        glBindSampler(i, 0);
    }
    glActiveTexture(GL_TEXTURE0);
    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);
    int half_w = (w + 1) / 2, half_h = (h + 1) / 2;
    if (setup(half_w, half_h)) {
        glDisable(GL_BLEND);
        glDisable(GL_SCISSOR_TEST);
        glDisable(GL_DEPTH_TEST);
        glDisable(GL_STENCIL_TEST);
        glDisable(GL_ALPHA_TEST);
        glDisable(GL_CULL_FACE);
        glDisable(GL_COLOR_LOGIC_OP);
        glDisable(GL_FRAMEBUFFER_SRGB);
        glDisable(GL_RASTERIZER_DISCARD);
        for (int i = 0; i < light.clip_planes; i++) glDisable(GL_CLIP_DISTANCE0 + i);
        glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
        glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);

        glBindFramebuffer(GL_READ_FRAMEBUFFER, draw_fb);
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, light.depth_fb);
        glBlitFramebuffer(0, 0, w, h, 0, 0, half_w, half_h, GL_DEPTH_BUFFER_BIT, GL_NEAREST);
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, light.effect_fb);
        glViewport(0, 0, half_w, half_h);
        glUseProgram(light.shader);
        glUniform1i(light.depth_uniform, 0);
        glUniform1i(light.color_uniform, 1);
        glUniform4f(light.projection_uniform, projection[0], projection[5], projection[10], projection[14]);
        glBindTexture(GL_TEXTURE_2D, light.depth);
        glActiveTexture(GL_TEXTURE1);
        glBindTexture(GL_TEXTURE_2D, color);
        glBindVertexArray(light.vao);
        glDrawArrays(GL_TRIANGLES, 0, 3);

        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, draw_fb);
        glViewport(0, 0, w, h);
        glEnable(GL_BLEND);
        glBlendEquation(GL_FUNC_ADD);
        glBlendFuncSeparate(GL_ONE, GL_ONE_MINUS_SRC_ALPHA, GL_ZERO, GL_ONE);
        glUseProgram(light.composite);
        glUniform1i(light.effect_uniform, 0);
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, light.effect);
        // The scene texture remains attached to draw_fb, so unbind it here.
        glActiveTexture(GL_TEXTURE1);
        glBindTexture(GL_TEXTURE_2D, 0);
        glDrawArrays(GL_TRIANGLES, 0, 3);
    } else {
        light.failed = 1;
        fprintf(stderr, "[lighting] scratch framebuffer initialization failed\n");
    }
    glBindFramebuffer(GL_READ_FRAMEBUFFER, read_fb);
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, draw_fb);
    for (int i = 0; i < 2; i++) {
        glActiveTexture(GL_TEXTURE0 + i);
        glBindTexture(GL_TEXTURE_2D, tex[i]);
        glBindSampler(i, sampler[i]);
    }
    glActiveTexture(old_unit);
    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, unpack);
    glBindVertexArray(old_vao);
    glUseProgram(old_program);
    glPopAttrib();
}
