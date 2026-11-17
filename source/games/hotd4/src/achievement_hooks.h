/* HOTD4 arcade build 72FDD458...: game events, never chapter selection or time. */
void host_achievement_unlock(int id);
void host_achievement_ending(int ending);
static unsigned achievement_run_chapters;
static HleHandler ach_init,ach_clear,ach_grenade,ach_wire,ach_item,ach_if,ach_article,ach_rank,ach_ending;
static int achievement_playing(void)
{
    uint32_t game=rd32(0x0a7117f8);
    return game && rd32(game+0x34)==3;
}
static int achievement_stage(void)
{
    uint32_t game=rd32(0x0a7117f8);
    return game?(int)rd32(game+0x38):-1;
}
static float achievement_float(uint32_t address)
{
    uint32_t bits=rd32(address);float value;memcpy(&value,&bits,4);return value;
}
static void achievement_call(CPU *c,HleHandler original)
{
    push32(c,rd32(c->esp-4));original(c);
}
static void achievement_game_init(CPU *c)
{
    achievement_run_chapters=0;achievement_call(c,ach_init);
}
static void achievement_chapter_clear(CPU *c)
{
    uint32_t game=rd32(c->esp);int stage=game?(int)rd32(game+0x38):-1;
    achievement_call(c,ach_clear);
    if(stage>=0 && stage<6){achievement_run_chapters|=1u<<stage;host_achievement_unlock(stage);}
}
static void achievement_grenade_hit(CPU *c)
{
    uint32_t boss=rd32(c->esp),hit=rd32(c->esp+4);
    int grenade=hit && rd32(hit)==0 && rd32(hit+4)<2 && rd32(hit+0x18)==0xffffffffu;
    float hp=boss?achievement_float(boss+0x650):0;
    int playing=achievement_playing() && achievement_stage()==0;
    achievement_call(c,ach_grenade);
    if(playing && grenade && hp>0 && achievement_float(boss+0x650)<hp)host_achievement_unlock(6);
}
static void achievement_wire_cut(CPU *c)
{
    uint32_t crane=rd32(c->esp);
    int cut=achievement_playing() && achievement_stage()==1 && crane && rd32(crane+0x138)>3 && rd32(crane+0x13c);
    achievement_call(c,ach_wire);
    if(cut)host_achievement_unlock(7);
}
static void achievement_item_gotten(CPU *c)
{
    uint32_t item=c->eax;
    int bus=achievement_playing() && item && rd32(item+0x118)==10;
    achievement_call(c,ach_item);
    if(bus)host_achievement_unlock(9);
}
static void achievement_secret_if(CPU *c)
{
    uint32_t manager=c->eax,args=c->ecx;
    int secret=achievement_playing() && c->edx==3 && args && rd32(args)==0x10e && rd32(args+4)==1 && rd32(args+8)==0x124;
    achievement_call(c,ach_if);
    /* 0x124 is the shoot-open secret door event. The original IF decides success. */
    uint32_t task=manager?rd32(manager+0x34):0;
    if(secret && task && rd32(task+0x18)==0)host_achievement_unlock(8);
}
static void achievement_secret_cache(CPU *c)
{
    uint32_t args=c->ecx;
    /* The remaining secret caches (chapter 5 and chapter 6) use scripted entry. */
    int secret=achievement_playing() && (args==0x084a3f7c || args==0x084aa3d8 || args==0x084ab640);
    achievement_call(c,ach_article);
    if(secret)host_achievement_unlock(8);
}
static void achievement_final_rank(CPU *c)
{
    uint32_t result=rd32(c->esp);
    achievement_call(c,ach_rank);
    if(achievement_run_chapters==63 && !getenv("HOTD4_PRACTICE_CHAPTER") && result && rd32(result) && rd32(result+0x3c)<=1)
        host_achievement_unlock(11);
}
static void achievement_ending_seen(CPU *c)
{
    int seen=rd32(0x0a71182c)!=0;
    int ending=(int)rd32(0x0a7118a8);
    achievement_call(c,ach_ending);
    if(seen && achievement_run_chapters==63 && !getenv("HOTD4_PRACTICE_CHAPTER"))host_achievement_ending(ending);
}
static int achievement_hook(const char *name,HleHandler replacement,HleHandler *original)
{
    *original=dispatch_lifted(guest_symbol(name));
    if(!*original || !guest_override(name,replacement)){fprintf(stderr,"[achievements] Missing hook: %s\n",name);return 0;}
    return 1;
}
static void install_achievements(void)
{
    int count=0;
    count+=achievement_hook("_ZN8CGameMgr12GM_INIT_funcEv",achievement_game_init,&ach_init);
    count+=achievement_hook("_ZN8CGameMgr18GM_STGCLRINIT_funcEv",achievement_chapter_clear,&ach_clear);
    count+=achievement_hook("_ZN10CST1BOSSAI11ColliHitMsgEP11HitMsgParam",achievement_grenade_hit,&ach_grenade);
    count+=achievement_hook("_ZN8CCRANE017DeatachEv",achievement_wire_cut,&ach_wire);
    count+=achievement_hook("_ZN13CItemBoxInner10ItemGottenEv",achievement_item_gotten,&ach_item);
    count+=achievement_hook("_ZN7CEvtMgr13EVENT_IF_funcEiPij",achievement_secret_if,&ach_if);
    count+=achievement_hook("_ZN7CEvtMgr24EVENT_ARTICLECREATE_funcEiPij",achievement_secret_cache,&ach_article);
    count+=achievement_hook("_Z21CalcPlayerRankingInfoP17TPLRANKPLAYERINFOi",achievement_final_rank,&ach_rank);
    count+=achievement_hook("_ZN13CEndingScreen4MainEv",achievement_ending_seen,&ach_ending);
    fprintf(stderr,"[achievements] %d/9 game event hooks installed\n",count);
    if(count!=9)exit(1);
}
