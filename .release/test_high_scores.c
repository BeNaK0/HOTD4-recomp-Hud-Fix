#include <assert.h>
#include <stdio.h>
#include "../source/lindberghrecomp/src/runtime/high_scores.h"
int main(void)
{
    uint32_t words[60]={0};HighScoreState s={0};
    for(int i=0;i<10;i++){words[i*6]=10000-100*i;words[i*6+1]=1;words[i*6+2]=0;words[i*6+3]=26;}
    assert(high_scores_decode(&s,words));assert(s.count==10 && s.rows[0].score==10000 && !strcmp(s.rows[0].initials,"A Z"));
    words[7]=27;assert(!high_scores_decode(&s,words));assert(s.rows[0].score==10000);
    words[7]=2;words[6]=10001;assert(!high_scores_decode(&s,words));
    words[6]=9900;words[0]=1000000000u;assert(!high_scores_decode(&s,words));
    words[0]=999999999u;assert(high_scores_decode(&s,words));
    uint32_t chapters[6]={1200,3400,5600,7800,9000,11000};
    assert(high_scores_run_total(chapters)==38000);
    chapters[5]=0;assert(high_scores_run_total(chapters)==27000);
    memset(chapters,0,sizeof chapters);assert(high_scores_run_total(chapters)==0);
    chapters[0]=9999999u;assert(high_scores_run_total(chapters)==9999999u);
    chapters[1]=1;assert(high_scores_run_total(chapters)==9999999u);
    for(int i=0;i<6;i++)chapters[i]=UINT32_MAX;
    assert(high_scores_run_total(chapters)==9999999u);
    puts("High scores: original record decoding, initials, ranking order, bounds and invalid data passed.");
}
