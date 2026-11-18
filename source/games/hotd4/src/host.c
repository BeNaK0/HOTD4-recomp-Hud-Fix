/*
 * host.c - run recompiled The House of the Dead 4.
 *
 * There is very little to do here, and that is the point. The runtime maps the
 * game where it was linked and builds the stack the kernel would have; the
 * lifted code is the game. This just hands control over at the ELF's entry
 * point and gets out of the way.
 *
 * Everything the game reaches for that is not its own code - libc, OpenGL,
 * sound, the JVS I/O board - arrives as hle_call(), and the handlers live in
 * hle_*.c next to this file. A handler that is missing aborts naming itself,
 * so the way to work on this port is to run it and read what it asks for.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#include "xr_overlay.h"
#include "game_profile.h"
#include "nn_culling.h"
#include "lindbergh_rt.h"

#if defined(_WIN32) && !defined(LINDBERGH_OPENXR)
#include <SDL.h>
#endif

/* The gun, at the two functions the game's gun code reads it through. Both
 * take the board's raw words and the game's stored calibration; a mouse needs
 * neither, so they answer from the pointer directly.
 *
 * GetAdjstGunPos(&x, &y, rawx, rawy, adjust, ...) -> on screen. The position
 * is a byte each, 0..255 across the whole screen. Register arguments: eax =
 * &x, edx = &y. The pointer outside the window is off the screen. */
static uint32_t g_gun_adjust[2];   /* each player's calibration, as GetAdjstGunPos gets it */
static void h_gun_pos(CPU *c)
{
    /* the stack: raw x, raw y, adjust, player - player 2's gun (dual
     * wielding) answers from the second pointer, not the first */
    uint32_t player = rd32(c->esp + 20);
    if (player < 2) g_gun_adjust[player] = rd32(c->esp + 16);
    int mx, my, w, h;
    if (player == 1) { if (!host_gun2_state(&mx, &my)) mx = my = -100000; }
    else host_mouse_state(&mx, &my, NULL);
    lindbergh_window_size(&w, &h);
    int on = mx >= 0 && my >= 0 && mx < w && my < h;
    /* the nearest of the 256 gun steps, first and last on the window's edges */
    long x = ((long)mx * 255 + (w - 1) / 2) / (w > 1 ? w - 1 : 1),
         y = ((long)my * 255 + (h - 1) / 2) / (h > 1 ? h - 1 : 1);
    wr8(c->eax, (uint8_t)(x < 0 ? 0 : x > 255 ? 255 : x));
    wr8(c->edx, (uint8_t)(y < 0 ? 0 : y > 255 ? 255 : y));
    c->eax = on;
}

/* The reload. A House of the Dead 4 gun has an accelerometer and the game
 * reloads when it is shaken. GetAdjstGunAccel(&a, &b, rawa, rawb, adjust)
 * gives the two axes as 0..1 past the calibrated dead zone, and anything over
 * zero is a shake. A mouse cannot shake, so the cabinet's reload input (the
 * right button held, or the pointer leaving the window, which is a single
 * frame) shakes the gun hard for a quarter of a second. Register arguments:
 * eax = &a, edx = &b. */
static void h_gun_accel(CPU *c)
{
    /* whose gun: its calibration sits 12 bytes past the same player's
     * position calibration (GetAdjstGunPos's, recorded above) */
    uint32_t adj = rd32(c->esp + 16);
    int pl = g_gun_adjust[1] && adj == g_gun_adjust[1] + 12;
    static unsigned left[2];
    if (host_cabinet_buttons() & (pl ? CAB_P2_RELOAD : CAB_P1_RELOAD)) left[pl] = 15;
    float v = left[pl] ? 1.0f : 0.0f;
    if (left[pl]) left[pl]--;
    uint32_t bits; memcpy(&bits, &v, 4);
    wr32(c->eax, bits);
    wr32(c->edx, bits);
}

/* GetSpriteResolution(&w, &h) -> screen ratio. The game lays its 2D out for
 * two monitors only: the cabinet's 1280x768 (ratio 2) and 640x480 (every
 * other shape, positions in 640x480 pixels). It then converts those with the
 * sprite resolution, which for a 16:9 monitor is the monitor's own 1280x720,
 * so the HUD came out at half size in the top-left. In a 16:9 mode the sprite
 * resolution is 640x480, matching the layout; the runtime then draws that
 * 4:3 layout at its own shape in the 16:9 frame (host_hud_widen). */
static int movie_aspect_active;

static void h_sprite_res(CPU *c)
{
    /* The camera asks too, for the 3D viewport: it gets the monitor's own
     * size, or the 3D would render at 640x480. The return address is just
     * below the stack pointer once the override is entered. */
    uint32_t ret = rd32(c->esp - 4);
    int w = 640, h = 480;
    int movie = ret == 0x0807cda4 || ret == 0x0807ca19;
    if (movie && movie_aspect_active) {
        /* Stock widescreen sprite canvas: keep the original Sofdec layout
         * arithmetic in its own units, including its type-specific crop. */
        wr32(c->eax,1280);wr32(c->edx,768);c->eax=2;
        return;
    }
    if ((ret >= 0x08210c14 && ret < 0x082127c4) || movie)
        lindbergh_window_size(&w, &h);
    wr32(c->eax, (uint32_t)w);
    wr32(c->edx, (uint32_t)h);
    c->eax = 5;                 /* 16:9 */
}

/* CSofdecMgr::Load builds four 24-byte texture vertices at +0x98.
 * The stock wide canvas is 1280x768 (GetSpriteResolution, ratio 2).
 * Constructor constants 1280, 960, 120 mix canvas and target units when
 * handed a high-resolution framebuffer. Preserve the original calculation,
 * then map the finished quad, with its original UVs/crop, to the target. */
extern HleHandler dispatch_lifted(uint32_t va);
static HleHandler lifted_movie_load;
static void h_movie_load(CPU *c)
{
    uint32_t manager=rd32(c->esp);
    int slot=(int)rd32(c->esp+4),movie=(int)rd32(c->esp+8);
    int type=(int)rd32(c->esp+16);
    push32(c,rd32(c->esp-4));
    lifted_movie_load(c);
    if(slot<0 || slot>=2 || movie<0 || movie>=79)return;
    int width,height;lindbergh_window_size(&width,&height);
    if(width<=0 || height<=0)return;
    float sx=width/1280.0f,sy=height/768.0f;
    uint32_t vertices=manager+0x98+(uint32_t)slot*0xc4;
    float raw[8],mapped[8];
    for(unsigned i=0;i<4;i++){
        uint32_t vertex=vertices+i*24;
        uint32_t bx=rd32(vertex),by=rd32(vertex+4);
        float x,y;memcpy(&x,&bx,4);memcpy(&y,&by,4);
        raw[2*i]=x;raw[2*i+1]=y;
        x*=sx;y*=sy;mapped[2*i]=x;mapped[2*i+1]=y;
        memcpy(&bx,&x,4);memcpy(&by,&y,4);wr32(vertex,bx);wr32(vertex+4,by);
    }
    fprintf(stderr,"[movie-aspect] id=%d type=%d source=(%.3f,%.3f)-(%.3f,%.3f) mapped=(%.3f,%.3f)-(%.3f,%.3f) target=%dx%d\n",
        movie,type,raw[0],raw[1],raw[6],raw[7],mapped[0],mapped[1],mapped[6],mapped[7],width,height);
}
static void install_movie_aspect(void)
{
    const char *name="_ZN10CSofdecMgr4LoadEiij8eSfdType";
    lifted_movie_load=dispatch_lifted(guest_symbol(name));
    if(lifted_movie_load && guest_override(name,h_movie_load))movie_aspect_active=1;
    else {fprintf(stderr,"[movie-aspect] original layout hook unavailable\n");exit(1);}
}

/* whether the HUD keeps to the screen's edges, or stays a centred 4:3 block */
static int hud_anchored(void) { return 1; }

/* What the runtime needs to know about this game (game_profile.h). */
static const LgGameProfile k_profile = {
    .title = "The House of the Dead 4",
    /* The monitor the game draws for. 16:9 is the board's 1360x768 mode - its
     * DIP switches have no 1280x720 one - and the game renders and aims for
     * 1360x768, so the frame is that size too and the window scales it.
     * LINDBERGH_WIDTH/HEIGHT pick another mode (1280x768 is the cabinet's). */
    .width = 1360, .height = 768,
    /* The gun goes straight to the game (h_gun_pos above), so the cabinet's
     * raw gun words carry the pointer as is too: no correction. */
    .aim = { 1, 0, 1, 0 },
    .vr = {
        .gun_model = XO_GUN_TP9,    /* a B&T TP9 in the player's hand */
        .title = "The House of the Dead 4 VR",
        /* In the headset the game draws its 640x480 mode, which the
         * runtime's stereo (stereo.c) scales to each eye; the screen in front
         * of you is 4:3 and the HUD sits on it as the game lays it out. */
        .width = 640, .height = 480,
        .scale = 1,
        .depth_read = LG_DEPTH_AUTO,
        /* GL on its own thread: in play the game thread is the limit (85-100%
         * of a core, the GPU 40-60% busy), a third of it the GL calls */
        .gl_thread = 1,
    },
};

#if defined(_WIN32) && !defined(LINDBERGH_OPENXR)
extern HleHandler dispatch_lifted(uint32_t va);
static HleHandler lifted_frame_rate_init;

static HleHandler lifted_practice_stage_init;
static HleHandler lifted_practice_end_frame;
static unsigned practice_chapter;
static int practice_started;
static SDL_atomic_t practice_restart;
extern unsigned g_frame;
#if defined(_WIN64) && !defined(LINDBERGH_VULKAN)
extern int host_hotd4_restart_key(int key);
extern int host_hotd4_start_binding(void);
#else
static int host_hotd4_restart_key(int key){return key==SDLK_F6;}
static int host_hotd4_start_binding(void){return SDLK_RETURN;}
#endif

enum { PRACTICE_RESTART_EXIT = 74 };

static int SDLCALL practice_key(void *unused, SDL_Event *event)
{
    (void)unused;
    if (event->type == SDL_KEYDOWN && !event->key.repeat &&
        host_hotd4_restart_key(event->key.keysym.sym))
        SDL_AtomicSet(&practice_restart, 1);
    return 1;
}

static void h_practice_end_frame(CPU *c)
{
    static int watching;
    if (!watching) {
        SDL_AddEventWatch(practice_key, NULL);
        watching = 1;
    }
    if (SDL_AtomicGet(&practice_restart)) {
        fprintf(stderr, "[practice] restart chapter %u\n", practice_chapter);
        exit(PRACTICE_RESTART_EXIT);
    }

    push32(c, rd32(c->esp - 4));
    lifted_practice_end_frame(c);

    // Use the normal Start binding until the game's first stage initializes.
    // The regular SDL input path inserts credits if needed.
    if (!practice_started && g_frame % 30 == 0) {
        SDL_Event key;
        SDL_zero(key);
        key.type = SDL_KEYDOWN;
        key.key.state = SDL_PRESSED;
        key.key.keysym.sym = host_hotd4_start_binding();
        key.key.keysym.scancode = SDL_GetScancodeFromKey(key.key.keysym.sym);
        SDL_PushEvent(&key);
        key.type = SDL_KEYUP;
        key.key.state = SDL_RELEASED;
        SDL_PushEvent(&key);
    }
}

static void h_practice_stage_init(CPU *c)
{
    uint32_t marker_offset = 0, saved_offset = 0;
    if (!practice_started) {
        uint32_t stage = practice_chapter - 1;
        uint32_t game = rd32(c->esp);
        // CEvtMgr selects scene 0 from a table of chapter pointers. Marker 2
        // normally skips the load commands because the preceding chapter
        // already ran them. For this call, start at the first real command.
        uint32_t scene = rd32(0x084c8d20 + 4 * stage);
        uint32_t markers = rd32(scene + 4);
        uint32_t count = rd32(scene + 8);
        for (uint32_t i = 0; i < count; i++) {
            if (rd32(markers + 8 * i) == 2) {
                marker_offset = markers + 8 * i + 4;
                saved_offset = rd32(marker_offset);
                wr32(marker_offset, 3);
                break;
            }
        }
        if (!marker_offset) {
            fprintf(stderr, "[practice] no chapter entry found\n");
            exit(1);
        }
        wr32(game + 0x38, stage);
        wr32(game + 0x3c, 0);
        practice_started = 1;
        fprintf(stderr, "[practice] start chapter %u\n", practice_chapter);
    }

    push32(c, rd32(c->esp - 4));
    lifted_practice_stage_init(c);

    if (marker_offset) wr32(marker_offset, saved_offset);
}

static void install_practice(void)
{
    const char *chapter = getenv("HOTD4_PRACTICE_CHAPTER");
    if (!chapter || chapter[0] < '1' || chapter[0] > '6' || chapter[1]) return;

    const char *stage_init = "_ZN8CGameMgr17GM_STAGEINIT_funcEv";
    const char *end_frame = "_ZN5MyApp8EndFrameEv";
    lifted_practice_stage_init = dispatch_lifted(guest_symbol(stage_init));
    lifted_practice_end_frame = dispatch_lifted(guest_symbol(end_frame));
    if (!lifted_practice_stage_init || !lifted_practice_end_frame) {
        fprintf(stderr, "[practice] game build does not expose the chapter entry\n");
        exit(1);
    }

    practice_chapter = (unsigned)(chapter[0] - '0');
    if (!guest_override(stage_init, h_practice_stage_init) ||
        !guest_override(end_frame, h_practice_end_frame)) {
        fprintf(stderr, "[practice] chapter entry could not be installed\n");
        exit(1);
    }
}

#if defined(_WIN64) && !defined(LINDBERGH_VULKAN)
void hotd4_lighting_apply(void);
void hotd4_install_hd_textures(void);
static HleHandler lifted_render_surface_end;

static void h_render_surface_end(CPU *c)
{
    // The main world copy has both a color and a depth surface.
    if (rd32(c->esp) && rd32(c->esp + 4) && rd32(c->esp + 8))
        hotd4_lighting_apply();
    push32(c, rd32(c->esp - 4));
    lifted_render_surface_end(c);
}

static void install_lighting(void)
{
    const char *enabled = getenv("HOTD4_EXPERIMENT_LIGHTING");
    if (!enabled || strcmp(enabled, "1") != 0) return;
    const char *name = "_Z30_hySystemEndRenderTextureFrameP16HyTextureSurfaceS0_P9HyPBuffer";
    lifted_render_surface_end = dispatch_lifted(guest_symbol(name));
    if (lifted_render_surface_end) guest_override(name, h_render_surface_end);
}

#endif

#if defined(_WIN64) && !defined(LINDBERGH_VULKAN)
static HleHandler lifted_render_env;

static void h_hud_render_env(CPU *c)
{
    int previous = hud_custom_render_env((int)c->edx);
    push32(c, rd32(c->esp - 4));
    lifted_render_env(c);
    hud_custom_render_env(previous);
}

static void install_hud(void)
{
    const char *name = "_ZN7CEnvMgr9RenderEnvEi";
    lifted_render_env = dispatch_lifted(guest_symbol(name));
    if (lifted_render_env) guest_override(name, h_hud_render_env);
}
#endif

static void sync_cutscene_swap(int cutscene)
{
    static int restore_interval;
    static int previous_interval;
    if (!SDL_GL_GetCurrentContext() || getenv("LINDBERGH_VSYNC")) return;
    if (cutscene && !restore_interval) {
        int interval = SDL_GL_GetSwapInterval();
        if (interval != 1 && SDL_GL_SetSwapInterval(1) == 0) {
            previous_interval = interval;
            restore_interval = 1;
        }
    } else if (!cutscene && restore_interval) {
        SDL_GL_SetSwapInterval(previous_interval);
        restore_interval = 0;
    }
}

static void h_frame_rate_init(CPU *c)
{
    uint32_t manager = rd32(c->esp);
    // Dispatch consumed the guest return address. Restore it for the lifted body.
    push32(c, rd32(c->esp - 4));
    lifted_frame_rate_init(c);

    // The software timer uses 3.333 ms ticks. Ten ticks is the 30 fps
    // cutscene mode. Keep its cadence, but wait at presentation so variable
    // rendering time after the guest's wait does not shift the displayed frame.
    int cutscene = rd32(manager) == 0 && rd32(manager + 0x20) == 1 &&
                   rd32(manager + 0x54) == 10;
    if (cutscene) wr32(manager + 0x54, 1);
    sync_cutscene_swap(cutscene);
    host_pace_fps(cutscene ? 30 : 0);
}

static void install_cutscene_pacing(void)
{
    const char *enabled = getenv("LINDBERGH_HOTD4_PACE_CUTSCENES");
    const char *unpaced = getenv("LINDBERGH_UNPACED");
    if (!enabled || strcmp(enabled, "1") != 0 || (unpaced && atoi(unpaced) != 0))
        return;

    const char *name = "_ZN13CFrameRateMgr5Init0EP19tagFRAMERATE_CONFIG";
    lifted_frame_rate_init = dispatch_lifted(guest_symbol(name));
    if (lifted_frame_rate_init) guest_override(name, h_frame_rate_init);
}
#endif

#if defined(_WIN64) && !defined(LINDBERGH_OPENXR) && !defined(LINDBERGH_VULKAN)
#include "achievement_hooks.h"

enum {
    PLAYER_INDEX = 0x34,
    PLAYER_MODE = 0x38,
    PLAYER_RELOAD_PROMPT = 0x1d4,
    PLAYER_RELOAD_VOICE_TIMER = 0x1dc,
    PLAYER_AMMO = 0x274,
    PLAYER_RELOAD_TIME = 0x284,
    SPRITE_FRAME = 0x28
};
extern void hud_route_mark(void);
static HleHandler lifted_player_sound, lifted_sprite_next, lifted_sprite_draw, lifted_resolution;

static void h_player_sound(CPU *c)
{
    static struct { uint32_t player; int played; } state[2];
    const uint32_t player = c->eax;
    const unsigned index = rd8(player + PLAYER_INDEX);
    uint32_t original_prompt = rd32(player + PLAYER_RELOAD_PROMPT);
    int request = 0;
    if (index < 2) {
        int empty = (int32_t)rd32(player + PLAYER_AMMO) <= 0;
        if (state[index].player != player || !empty) {
            state[index].player = player;
            state[index].played = 0;
        }
        uint32_t reload_bits = rd32(player + PLAYER_RELOAD_TIME);
        float reload_time;
        memcpy(&reload_time, &reload_bits, sizeof reload_time);
        request = empty && rd32(player + PLAYER_MODE) == 3 &&
                  reload_time <= 0.0f && !state[index].played;
        // Reuse the voice branch and its original checks for grabs and scripted
        // scenes. Keep the stock prompt state outside this sound update.
        wr32(player + PLAYER_RELOAD_PROMPT, request);
        if (request) wr32(player + PLAYER_RELOAD_VOICE_TIMER, 0);
    }
    push32(c, rd32(c->esp - 4));
    lifted_player_sound(c);
    if (index < 2) {
        wr32(player + PLAYER_RELOAD_PROMPT, original_prompt);
        // The original sound branch reloads the countdown to 120.0.
        if (request && rd32(player + PLAYER_RELOAD_VOICE_TIMER) == 0x42f00000u)
            state[index].played = 1;
    }
}

static void h_reload_sprite_next(CPU *c)
{
    // CPlayer::SprMain advances the original red prompt through a blink loop.
    // Keep an opaque frame; its original CalcScene and Draw still run.
    if (rd32(c->esp - 4) == 0x08164e9au) {
        wr32(c->eax + SPRITE_FRAME, 0x41400000u); // 12.0
        return;
    }
    push32(c, rd32(c->esp - 4));
    lifted_sprite_next(c);
}

static void h_route_sprite_draw(CPU *c)
{
    // The five route sprites use the same 640x480 canvas as their hit boxes.
    const int route = rd32(c->esp - 4) == 0x081800b1u;
    if (route) hud_route_mark();
    push32(c, rd32(c->esp - 4));
    lifted_sprite_draw(c);
}

static void h_route_resolution(CPU *c)
{
    // CBRANCH00::GetSelectSide converts normalized gun aim into sprite units.
    if (rd32(c->esp - 4) == 0x0817ff72u) {
        wr32(c->eax, 640);
        wr32(c->edx, 480);
        c->eax = 480;
        return;
    }
    push32(c, rd32(c->esp - 4));
    lifted_resolution(c);
}

static void install_reload_feedback(void)
{
    const char *sound = "_ZN7CPlayer7SndMainEv";
    const char *next = "_ZN9CCsPlayer13NextFrameSkipEf";
    lifted_player_sound = dispatch_lifted(guest_symbol(sound));
    lifted_sprite_next = dispatch_lifted(guest_symbol(next));
    if (lifted_player_sound) guest_override(sound, h_player_sound);
    if (lifted_sprite_next) guest_override(next, h_reload_sprite_next);
}

static void install_route_layout(void)
{
    const char *draw = "_ZN9CCsPlayer12_DrawProcessEjP12KfMatrixNNGL";
    const char *resolution = "_Z13GetResolutionPjS_";
    lifted_sprite_draw = dispatch_lifted(guest_symbol(draw));
    lifted_resolution = dispatch_lifted(guest_symbol(resolution));
    if (lifted_sprite_draw && lifted_resolution) {
        guest_override(draw, h_route_sprite_draw);
        guest_override(resolution, h_route_resolution);
    }
}
#endif

int main(int argc, char **argv)
{
    if (argc < 2) {
        fprintf(stderr,
            "usage: %s <hod4M.elf> [game args...]\n"
            "\n"
            "  hod4M.elf is The House of the Dead 4's executable, from a game tree you\n"
            "  can already read. None of it ships here - see the README.\n",
            argv[0]);
        return 2;
    }

    /* Before anything guest-shaped runs, so a fault in lifted code reports
     * the simulated machine rather than a C function name in a generated file. */
    guest_install_crash_handler();

    if (guest_load(argv[1], argc - 1, argv + 1) != 0)
        return 1;

    game_profile_apply(&k_profile);

    /* Give the imports bodies. Everything the toolkit ships is bound here;
     * anything this game needs beyond that gets bound on top, and whatever is
     * still missing aborts naming itself on first call. */
    hle_register_all();
#if defined(_WIN32) && !defined(LINDBERGH_OPENXR)
    install_cutscene_pacing();
    install_practice();
#if defined(_WIN64) && !defined(LINDBERGH_VULKAN)
    install_achievements();
    install_reload_feedback();
#endif
#if defined(_WIN64) && !defined(LINDBERGH_VULKAN)
    install_lighting();
    hotd4_install_hd_textures();
#endif
#endif
    {
        int w, h;
        lindbergh_window_size(&w, &h);
        float aspect = (h > 0) ? ((float)w / (float)h) : 0.0f;
        if (fabsf(aspect - (16.0f / 9.0f)) < 0.05f && guest_override("_Z19GetSpriteResolutionPjS_", h_sprite_res)) {
            install_movie_aspect();
            fprintf(stderr, "[hotd4] 16:9 widescreen layout active (%dx%d)\n", w, h);
#if defined(_WIN64) && !defined(LINDBERGH_OPENXR) && !defined(LINDBERGH_VULKAN)
            install_hud();
            install_route_layout();
#endif
            hud_widen_enable(0.75f, hud_anchored);
            /* the 2D is laid out in 640x480 pixels from the top left, and
             * drawn into the camera's w x h frame */
            hud_widen_layout(w / 640.0f, w / 640.0f - 1.0f, h / 480.0f, 1.0f - h / 480.0f, w - 8);
        }
    }
    if (guest_override("_Z14GetAdjstGunPosPhS_ttP18GunAdjustValueTypei", h_gun_pos))
        fprintf(stderr, "[hotd4] aim: the gun is where the pointer is\n");
    if (guest_override("_Z16GetAdjstGunAccelPfS_ttP23GunAccelAdjustValueType", h_gun_accel))
        fprintf(stderr, "[hotd4] reload: the reload input shakes the gun\n");
    nn_culling_install("nnSetClipPlane",guest_symbol("nnSetClipPlane"),0x0a767c80u,0x0a767c94u,nn_culling_default_widen());

    CPU cpu;
    guest_init_cpu(&cpu);

    /* The guest never returns here: its exit path is the exit_group syscall,
     * which the runtime turns into the host's exit(). Reaching the line below
     * means the entry point returned, which a Linux _start does not do. */
    dispatch(&cpu, guest_entry());

    fprintf(stderr, "[host] the entry point returned - _start should not.\n");
    return 1;
}
