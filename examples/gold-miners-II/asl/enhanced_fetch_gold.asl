// enhanced_fetch_gold.asl
// go to gold, pick it up (with retries for fatigue), tell team

/* fetch_gold -- walk to gold, pick it, broadcast, then re-decide */

+!fetch_gold(gold(X,Y))
  <- .print("Handling ",gold(X,Y)," now.");
     ?pos(AgX,AgY,_);
     jia.path_length(AgX,AgY,X,Y,Dist);
     .my_name(MyN);
     .broadcast(tell, committed_to(gold(X,Y),Dist,MyN));
     !pos(X,Y);
     !ensure_pick(0);
     ?carrying_gold(NG);
     .print("Picked ",gold(X,Y),", now carrying ",NG," gold.");
     !remove(gold(X,Y));
     .broadcast(tell,picked(gold(X,Y)));
     !!choose_goal.

// couldn't get the gold, clean up and move on
@fpg[atomic]
-!fetch_gold(G)
  <- .print("Failed to catch gold ",G,".");
     .broadcast(untell, committed_to(G,_,_));
     !remove(G);
     !!choose_goal.


/* ensure_pick: keep trying to pick up gold because fatigue
   can silently drop the action. we retry up to max_pick_retries
   and check each time if the gold is still there. */

max_pick_retries(6).

// gold gone from the cell -- either we got it or someone else did
+!ensure_pick(N) : pos(X,Y,_) & not cell(X,Y,gold).

// gold still there, try again
+!ensure_pick(N)
  :  max_pick_retries(Max) & N < Max &
     pos(X,Y,_) & cell(X,Y,gold)
  <- do(pick);
     !ensure_pick(N+1).

// ran out of retries
+!ensure_pick(N)
  :  max_pick_retries(Max) & N >= Max
  <- .print("Gave up picking after ",N," tries.").


/* handling other agents' actions on gold im interested in */

// someone else picked the gold i was going for
@ppgd[atomic]
+picked(G)[source(A)]
  :  .desire(fetch_gold(G)) &
     .my_name(Me) & A \== Me
  <- .print(A," got ",G," before me, dropping.");
     .fail_goal(fetch_gold(G)).

// someone picked a gold i had recorded
+picked(G) <- !remove(G).

// another agent is closer to the gold im going for, let them have it
@ctg[atomic]
+committed_to(gold(GX,GY),Dist,A)
  :  .desire(fetch_gold(gold(GX,GY))) &
     pos(X,Y,_) & jia.path_length(X,Y,GX,GY,D) &
     D > 1 &       // not right next to it
     D > Dist      // they're closer
  <- .print(A," closer to ",gold(GX,GY)," (",Dist," vs ",D,"), letting them go.");
     .fail_goal(fetch_gold(gold(GX,GY))).
